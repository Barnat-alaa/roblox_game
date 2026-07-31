--!strict
-- Floor tiles + wall panels (B3, owner request 2026-07-31). Players buy and place
-- 1×1 floor tiles and full-height wall panels to decorate their café, choosing a
-- colour and a motif (plain / vertical lines / horizontal lines / grid / checker)
-- from Config/Surfaces.
--
-- Surfaces are a SEPARATE LAYER from furniture: they do not occupy grid cells and
-- never collide with a placed item, so you can tile a floor that already has
-- tables on it. Everything is drawn from plain parts — a base slab plus thin
-- stripe parts — so no textures are imported (docs/ART_DIRECTION.md).
--
-- Server-authoritative: the client sends a cell/panel and a style id, and the
-- price, the bounds and the spend all happen here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Surfaces = require(Shared.Config.Surfaces)
local World = require(Shared.Config.World)
local Grid = require(Shared.Utilities.Grid)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)
local Types = require(Shared.Types)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local SurfaceService = {}
SurfaceService.Name = "SurfaceService"

local DataService: any
local CafeService: any
local EconomyService: any
local AnalyticsService: any

local paintLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

local WALL_IDS: { [string]: boolean } = { left = true, right = true, back = true }

-- reconcile fills the top-level key; the sub-tables still need healing (the same
-- pattern as SocialService.socialOf).
local function surfacesOf(data: Types.PlayerData): Types.SurfaceState
	local mutable: any = data
	if typeof(mutable.surfaces) ~= "table" then
		mutable.surfaces = { floor = {}, wall = {} }
	end
	if typeof(mutable.surfaces.floor) ~= "table" then
		mutable.surfaces.floor = {}
	end
	if typeof(mutable.surfaces.wall) ~= "table" then
		mutable.surfaces.wall = {}
	end
	return mutable.surfaces
end

local function interiorDepthCells(data: Types.PlayerData): number
	local tier = math.max(0, math.floor(tonumber(data.expansionTier) or 0))
	return World.interiorDepthTiers[math.clamp(tier + 1, 1, #World.interiorDepthTiers)]
end

-- ————— rendering —————

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false -- a surface is decoration; it must never block walking
	part.CanQuery = false -- and never intercept the build-mode raycast
	part.CanTouch = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- Lay `bands` evenly spaced stripes across a run of `span` studs, returning each
-- stripe's offset from the centre. Evenly spaced means the gaps read as part of
-- the pattern rather than the stripes crowding one edge.
local function bandOffsets(span: number, bands: number): { number }
	local offsets = {}
	for index = 1, bands do
		offsets[index] = -span / 2 + span * (index / (bands + 1))
	end
	return offsets
end

-- One floor tile: a thin slab over the cell, plus its motif stripes sitting
-- fractionally proud of it so the two never z-fight.
local function renderFloorTile(
	parent: Instance,
	origin: CFrame,
	gx: number,
	gy: number,
	styleId: string
)
	local color, motif = Surfaces.parse(styleId)
	if not color or not motif then
		return
	end
	local cell = Grid.CELL_SIZE
	local model = Instance.new("Model")
	model.Name = string.format("Floor_%d_%d", gx, gy)

	local centreX = (gx + 0.5) * cell
	local centreZ = (gy + 0.5) * cell
	local baseCf = origin * CFrame.new(centreX, Surfaces.tileThickness / 2, centreZ)
	makePart("Tile", Vector3.new(cell, Surfaces.tileThickness, cell), baseCf, color.base, model)

	local inkY = Surfaces.tileThickness + Surfaces.motifLift / 2
	local w = Surfaces.motifWidth
	-- On a floor, "vertical" lines run along the room's depth (local Z) and
	-- "horizontal" ones across its width (local X) — the way they read from the
	-- fixed café-sim camera looking down the room.
	if motif.kind == "vertical" or motif.kind == "both" then
		for _, offset in bandOffsets(cell, motif.bands) do
			makePart(
				"Ink",
				Vector3.new(w, Surfaces.motifLift, cell),
				origin * CFrame.new(centreX + offset, inkY, centreZ),
				color.ink,
				model
			)
		end
	end
	if motif.kind == "horizontal" or motif.kind == "both" then
		for _, offset in bandOffsets(cell, motif.bands) do
			makePart(
				"Ink",
				Vector3.new(cell, Surfaces.motifLift, w),
				origin * CFrame.new(centreX, inkY, centreZ + offset),
				color.ink,
				model
			)
		end
	end
	if motif.kind == "checker" then
		-- Two opposing quarters, which reads as a checkerboard once tiles repeat.
		local q = cell / 4
		for _, corner in { { -q, -q }, { q, q } } do
			makePart(
				"Ink",
				Vector3.new(cell / 2, Surfaces.motifLift, cell / 2),
				origin * CFrame.new(centreX + corner[1], inkY, centreZ + corner[2]),
				color.ink,
				model
			)
		end
	end
	model.Parent = parent
end

-- One wall panel: full wall height, one cell wide, mounted on the wall's INNER
-- face so it faces into the room.
local function renderWallPanel(
	parent: Instance,
	origin: CFrame,
	wallId: string,
	index: number,
	styleId: string,
	depthCells: number
)
	local color, motif = Surfaces.parse(styleId)
	if not color or not motif then
		return
	end
	local cell = Grid.CELL_SIZE
	local width = Grid.PLOT_WIDTH * cell
	local depth = depthCells * cell
	local height = World.wallHeight
	local t = Surfaces.panelThickness
	local model = Instance.new("Model")
	model.Name = string.format("Wall_%s_%d", wallId, index)

	-- Walls are 1 stud thick and centred on the boundary, so their inner faces sit
	-- half a stud inside the room.
	local along = (index + 0.5) * cell
	local size: Vector3
	local centre: CFrame
	-- `runAxis` is the panel's horizontal direction, used to lay the stripes.
	local runIsZ = wallId == "left" or wallId == "right"
	if wallId == "left" then
		size = Vector3.new(t, height, cell)
		centre = origin * CFrame.new(0.5 + t / 2, height / 2, along)
	elseif wallId == "right" then
		size = Vector3.new(t, height, cell)
		centre = origin * CFrame.new(width - 0.5 - t / 2, height / 2, along)
	else
		size = Vector3.new(cell, height, t)
		centre = origin * CFrame.new(along, height / 2, depth - 0.5 - t / 2)
	end
	makePart("Panel", size, centre, color.base, model)

	-- Stripes sit a hair further into the room than the panel face.
	local outward = if wallId == "left"
		then Vector3.new(Surfaces.motifLift, 0, 0)
		elseif wallId == "right" then Vector3.new(-Surfaces.motifLift, 0, 0)
		else Vector3.new(0, 0, -Surfaces.motifLift)
	local w = Surfaces.motifWidth
	local function ink(offsetAlong: number, offsetY: number, sizeAlong: number, sizeY: number)
		local local3 = if runIsZ
			then Vector3.new(0, offsetY, offsetAlong)
			else Vector3.new(offsetAlong, offsetY, 0)
		local inkSize = if runIsZ
			then Vector3.new(Surfaces.motifLift, sizeY, sizeAlong)
			else Vector3.new(sizeAlong, sizeY, Surfaces.motifLift)
		makePart(
			"Ink",
			inkSize,
			centre * CFrame.new(local3.X, local3.Y, local3.Z) + outward,
			color.ink,
			model
		)
	end

	-- On a wall, "vertical" lines run up it and "horizontal" lines run along it.
	if motif.kind == "vertical" or motif.kind == "both" then
		for _, offset in bandOffsets(cell, motif.bands) do
			ink(offset, 0, w, height)
		end
	end
	if motif.kind == "horizontal" or motif.kind == "both" then
		for _, offset in bandOffsets(height, motif.bands) do
			ink(0, offset, cell, w)
		end
	end
	if motif.kind == "checker" then
		local q = height / 4
		ink(-cell / 4, -q, cell / 2, height / 2)
		ink(cell / 4, q, cell / 2, height / 2)
	end
	model.Parent = parent
end

-- Rebuild every painted surface for one player from scratch. Cheap enough to run
-- whole rather than diffing: a fully-tiled café is a few hundred thin parts, and
-- painting is a deliberate, low-frequency action.
function SurfaceService.RenderFor(_self: any, player: Player)
	local origin = CafeService:GetPlotOrigin(player)
	local furniture = CafeService:GetFurnitureFolder(player)
	local data = DataService:GetProfile(player)
	if not origin or not furniture or not data then
		return
	end
	local plot = furniture.Parent
	if not plot then
		return
	end
	local existing = plot:FindFirstChild("Surfaces")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Surfaces"

	local state = surfacesOf(data)
	local depthCells = interiorDepthCells(data)
	for key, styleId in state.floor do
		local gx, gy = string.match(key, "^(-?%d+),(-?%d+)$")
		if gx and gy then
			renderFloorTile(folder, origin, tonumber(gx) :: number, tonumber(gy) :: number, styleId)
		end
	end
	for key, styleId in state.wall do
		local wallId, index = string.match(key, "^(%a+):(%d+)$")
		if wallId and index and WALL_IDS[wallId] then
			renderWallPanel(folder, origin, wallId, tonumber(index) :: number, styleId, depthCells)
		end
	end
	folder.Parent = plot
end

-- ————— the paint remote —————

local function handlePaint(player: Player, payload: unknown)
	if not Surfaces.enabled then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	if not paintLimiter:check(player.UserId, os.clock()) then
		return
	end
	local p = payload :: any
	if
		typeof(p.surface) ~= "string"
		or typeof(p.colorId) ~= "string"
		or typeof(p.motifId) ~= "string"
	then
		return
	end
	-- The style must resolve to a real palette entry AND a real motif: the client
	-- never sends a colour, only an id we look up here.
	if not (Surfaces.color(p.colorId) and Surfaces.motif(p.motifId)) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local state = surfacesOf(data)
	local styleId = Surfaces.styleId(p.colorId, p.motifId)
	local depthCells = interiorDepthCells(data)

	local key: string
	local price: number
	if p.surface == "floor" then
		if typeof(p.gridX) ~= "number" or typeof(p.gridY) ~= "number" then
			return
		end
		local gx, gy = math.floor(p.gridX), math.floor(p.gridY)
		if gx ~= p.gridX or gy ~= p.gridY then
			return
		end
		-- Only the player's own CURRENT interior — the garden behind the back wall
		-- is not paintable until that expansion is bought.
		if gx < 0 or gx >= Grid.PLOT_WIDTH or gy < 0 or gy >= depthCells then
			Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "out_of_bounds" })
			return
		end
		key = string.format("%d,%d", gx, gy)
		price = Surfaces.floorTilePrice
		if state.floor[key] == styleId then
			return -- already this exact style: no charge, no rebuild
		end
	elseif p.surface == "wall" then
		if typeof(p.wallId) ~= "string" or not WALL_IDS[p.wallId] then
			return
		end
		if typeof(p.index) ~= "number" or p.index ~= math.floor(p.index) then
			return
		end
		local segments = if p.wallId == "back" then Grid.PLOT_WIDTH else depthCells
		if p.index < 0 or p.index >= segments then
			Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "out_of_bounds" })
			return
		end
		key = string.format("%s:%d", p.wallId, p.index)
		price = Surfaces.wallPanelPrice
		if state.wall[key] == styleId then
			return
		end
	else
		return
	end

	if not EconomyService:TrySpendCoins(player, price) then
		Remotes.event("Notify")
			:FireClient(player, { kind = "error", reason = "insufficient_coins" })
		return
	end
	if p.surface == "floor" then
		state.floor[key] = styleId
	else
		state.wall[key] = styleId
	end
	DataService:Push(player)
	SurfaceService:RenderFor(player)
	Remotes.event("Notify"):FireClient(player, { kind = "surface_painted", key = key })
	if AnalyticsService then
		AnalyticsService:Track(player, "surface_painted", {
			surface = p.surface,
			color = p.colorId,
			motif = p.motifId,
		})
	end
end

function SurfaceService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	CafeService = ServiceRegistry.get("CafeService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function SurfaceService.Start(_self: any)
	if not Surfaces.enabled then
		Log.info("SurfaceService disabled (Config/Surfaces.enabled = false)")
		return
	end
	Remotes.event("PaintSurface").OnServerEvent:Connect(handlePaint)

	-- Repaint on join, once the profile and the café both exist.
	local function renderWhenReady(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				if
					DataService:IsLoaded(player)
					and CafeService:GetPlotOrigin(player)
					and CafeService:GetFurnitureFolder(player)
				then
					SurfaceService:RenderFor(player)
					return
				end
				task.wait(1)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		renderWhenReady(player)
	end
	Players.PlayerAdded:Connect(renderWhenReady)
	Log.info("SurfaceService ready (floor tiles + wall panels)")
end

return SurfaceService
