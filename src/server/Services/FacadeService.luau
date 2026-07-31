--!strict
-- Exterior personalisation (B4). Restyles a café's FRONT — architecture, colour,
-- motif, door style, door wood, window shape and glass tint — from the axes in
-- Config/Facade.
--
-- This RESTYLES the facade CafeService already built rather than replacing that
-- builder: it recolours the existing WallFront / DoorLeaf / Window parts and adds
-- its own decoration into a `FacadeStyle` folder it owns outright. That keeps all
-- the load-bearing geometry (the door hinge, the collision walls, the sign) in
-- one place, and means a restyle is a cheap repaint rather than a plot rebuild.
--
-- Door decoration is WELDED to the leaf, because the leaf swings — panels and
-- grain lines have to travel with it.
--
-- Server-authoritative: the client sends axis ids, never colours or sizes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Facade = require(Shared.Config.Facade)
local World = require(Shared.Config.World)
local Grid = require(Shared.Utilities.Grid)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local FacadeService = {}
FacadeService.Name = "FacadeService"

local DataService: any
local CafeService: any
local EconomyService: any
local AnalyticsService: any

local limiter = RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false -- decoration only; the real walls already collide
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function bandOffsets(span: number, bands: number): { number }
	local offsets = {}
	for i = 1, bands do
		offsets[i] = -span / 2 + span * (i / (bands + 1))
	end
	return offsets
end

-- ————— the front wall: colour + motif —————

local function styleFrontWall(model: Instance, origin: CFrame, folder: Folder, style: any)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local wallH = World.wallHeight
	local color = style.color
	local motif = style.motif

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "WallFront" then
			child.Color = color.base
		end
	end

	-- THE DOORWAY IS KEPT CLEAR (owner bug 2026-07-31: boards were running across
	-- the door). Battens and boards are cladding on the WALL, so they must stop at
	-- the opening the way real cladding does — a plank does not cross a doorway.
	-- `reveal` is the clean margin left around the frame.
	local doorCx = width * World.doorCenterFrac
	local reveal = 0.9
	local gapL = doorCx - World.doorWidth / 2 - reveal
	local gapR = doorCx + World.doorWidth / 2 + reveal
	local clearTop = World.doorHeight + reveal

	-- Motif battens/boards sit just proud of the front face (local z = -0.5).
	local z = -0.5 - Facade.trimDepth / 2
	local w = 0.7

	-- A horizontal band below the door head is emitted as the two wall segments
	-- either side of the opening; above the head it can run the full width.
	local function board(name: string, centreY: number, thickness: number)
		if centreY - thickness / 2 >= clearTop then
			part(
				name,
				Vector3.new(width, thickness, Facade.trimDepth),
				origin * CFrame.new(width / 2, centreY, z),
				color.trim,
				folder
			)
			return
		end
		if gapL > 0 then
			part(
				name,
				Vector3.new(gapL, thickness, Facade.trimDepth),
				origin * CFrame.new(gapL / 2, centreY, z),
				color.trim,
				folder
			)
		end
		if gapR < width then
			part(
				name,
				Vector3.new(width - gapR, thickness, Facade.trimDepth),
				origin * CFrame.new(gapR + (width - gapR) / 2, centreY, z),
				color.trim,
				folder
			)
		end
	end

	if motif.kind == "vertical" or motif.kind == "both" then
		for _, offset in bandOffsets(width, motif.bands) do
			local x = width / 2 + offset
			if x > gapL and x < gapR then
				-- This batten would land on the doorway: run it only from the door
				-- head up, so the rhythm continues overhead without dressing the door.
				local height = wallH - clearTop
				if height > 0.4 then
					part(
						"Batten",
						Vector3.new(w, height, Facade.trimDepth),
						origin * CFrame.new(x, clearTop + height / 2, z),
						color.trim,
						folder
					)
				end
			else
				part(
					"Batten",
					Vector3.new(w, wallH, Facade.trimDepth),
					origin * CFrame.new(x, wallH / 2, z),
					color.trim,
					folder
				)
			end
		end
	end
	if motif.kind == "horizontal" or motif.kind == "both" then
		for _, offset in bandOffsets(wallH, motif.bands) do
			board("Board", wallH / 2 + offset, w)
		end
	end
	if motif.kind == "wainscot" then
		-- A single waist-high panelled band, the classic shopfront dado. Waist
		-- height is below the door head, so this always splits around the opening.
		board("Wainscot", 1.8, 3.2)
	end
	if motif.kind == "pilaster" then
		-- Two tall columns framing the shopfront.
		for _, fx in { 0.06, 0.94 } do
			part(
				"Pilaster",
				Vector3.new(2.4, wallH, Facade.trimDepth * 2),
				origin * CFrame.new(width * fx, wallH / 2, z),
				color.trim,
				folder
			)
		end
	end
end

-- ————— the crown: what makes the three architectures read differently —————

local function styleCrown(model: Instance, origin: CFrame, folder: Folder, style: any)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local doorH = World.doorHeight
	local color = style.color
	local crown = style.architecture.crown

	-- The stock awning slats belong to the "awning" architecture only; the other
	-- two hide them and build their own crown.
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "AwningSlat" then
			child.Transparency = if crown == "awning" then 0 else 1
		end
	end

	if crown == "gable" then
		-- A pitched roof: stacked bars of shrinking width read as a triangle
		-- without needing wedges, and stay one flat colour from the street.
		local steps = 7
		for i = 0, steps - 1 do
			local t = i / steps
			part(
				"Gable",
				Vector3.new(width * (1 - t) * 0.9, 0.9, 3.6),
				origin * CFrame.new(width / 2, doorH + 1.4 + i * 0.85, -1.1),
				if i % 2 == 0 then color.trim else color.base,
				folder
			)
		end
	elseif crown == "cornice" then
		-- A flat slab plus a deep sill band: minimal and sharp.
		part(
			"Cornice",
			Vector3.new(width + 1.5, 1.1, 4.6),
			origin * CFrame.new(width / 2, doorH + 2.2, -1.6),
			color.trim,
			folder
		)
		part(
			"CorniceLip",
			Vector3.new(width + 2.2, 0.5, 5.2),
			origin * CFrame.new(width / 2, doorH + 1.5, -1.9),
			color.base,
			folder
		)
	end
end

-- ————— windows: shape + glass tint —————

local function styleWindows(model: Instance, folder: Folder, style: any)
	local shape = style.windowShape.shape
	local tint = style.glass

	for _, child in model:GetChildren() do
		if
			child:IsA("BasePart") and (child.Name == "WindowFrame" or child.Name == "WindowGlass")
		then
			local isGlass = child.Name == "WindowGlass"
			if isGlass then
				child.Color = tint.color
				child.Transparency = tint.transparency
			else
				child.Color = style.color.trim
			end
			-- The stock window is a square slab. Round and lozenge hide it and
			-- draw their own shape at the same spot, so the frame keeps its
			-- position, size reference and parent.
			if shape == "square" then
				child.Transparency = if isGlass then tint.transparency else 0
			else
				child.Transparency = 1
				if isGlass then
					local cf = child.CFrame
					if shape == "round" then
						local disc = part(
							"RoundGlass",
							Vector3.new(0.3, 3.4, 3.4),
							cf * CFrame.Angles(0, 0, math.rad(90)),
							tint.color,
							folder
						)
						disc.Shape = Enum.PartType.Cylinder
						disc.Transparency = tint.transparency
						disc.Material = Enum.Material.Glass
						local ring = part(
							"RoundFrame",
							Vector3.new(0.22, 4.1, 4.1),
							cf * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, 0, math.rad(90)),
							style.color.trim,
							folder
						)
						ring.Shape = Enum.PartType.Cylinder
					else
						-- Lozenge: the same square pane turned 45°, with a frame
						-- behind it, which reads as a diamond from the street.
						local pane = part(
							"LozengeGlass",
							Vector3.new(2.9, 2.9, 0.3),
							cf * CFrame.Angles(0, 0, math.rad(45)),
							tint.color,
							folder
						)
						pane.Transparency = tint.transparency
						pane.Material = Enum.Material.Glass
						part(
							"LozengeFrame",
							Vector3.new(3.5, 3.5, 0.22),
							cf * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, 0, math.rad(45)),
							style.color.trim,
							folder
						)
					end
				end
			end
		end
	end
end

-- ————— the door: style panels + wood finish, welded to the swinging leaf —————

local function styleDoor(model: Instance, style: any)
	local leaf: BasePart? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "DoorLeaf" then
			leaf = child
			break
		end
	end
	if not leaf then
		return
	end
	local door = leaf :: BasePart
	local wood = style.doorWood
	door.Color = wood.base
	door.Material = (Enum.Material :: any)[wood.material] or Enum.Material.Wood

	-- Clear any previous decoration before re-decorating.
	for _, child in door:GetChildren() do
		if child:IsA("BasePart") or child:IsA("WeldConstraint") then
			if child.Name == "DoorTrim" or child.Name == "DoorTrimWeld" then
				child:Destroy()
			end
		end
	end

	local size = door.Size
	local function trim(
		w: number,
		h: number,
		offsetX: number,
		offsetY: number,
		color: Color3,
		angle: number?
	)
		local p = Instance.new("Part")
		p.Name = "DoorTrim"
		p.Anchored = false -- welded: it must swing with the leaf
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Size = Vector3.new(w, h, Facade.grainDepth * 2)
		p.Color = color
		p.Material = door.Material
		local rotate = if angle then CFrame.Angles(0, 0, math.rad(angle)) else CFrame.new()
		p.CFrame = door.CFrame
			* CFrame.new(offsetX, offsetY, -size.Z / 2 - Facade.grainDepth)
			* rotate
		p.Parent = door
		local weld = Instance.new("WeldConstraint")
		weld.Name = "DoorTrimWeld"
		weld.Part0 = door
		weld.Part1 = p
		weld.Parent = p
	end

	-- Wood grain: fine vertical lines in the grain tone. Species differ by how
	-- many lines and how dark they are (Config/Facade.doorWoods).
	for _, offset in bandOffsets(size.X, wood.lines) do
		trim(0.16, size.Y * 0.86, offset, 0, wood.grain)
	end

	-- Then the style's panel arrangement, in the trim tone so it reads on top.
	local panels = style.doorStyle.panels
	local inset = style.color.trim
	if panels == "two" then
		for _, oy in { size.Y * 0.22, -size.Y * 0.22 } do
			trim(size.X * 0.6, size.Y * 0.3, 0, oy, inset)
		end
	elseif panels == "four" then
		for _, ox in { -size.X * 0.22, size.X * 0.22 } do
			for _, oy in { size.Y * 0.22, -size.Y * 0.22 } do
				trim(size.X * 0.34, size.Y * 0.3, ox, oy, inset)
			end
		end
	elseif panels == "arch" then
		trim(size.X * 0.62, size.Y * 0.34, 0, -size.Y * 0.2, inset)
		local top = Instance.new("Part")
		top.Name = "DoorTrim"
		top.Anchored = false
		top.CanCollide = false
		top.CanQuery = false
		top.CanTouch = false
		top.Massless = true
		top.Shape = Enum.PartType.Cylinder
		top.Size = Vector3.new(Facade.grainDepth * 2, size.X * 0.62, size.X * 0.62)
		top.Color = inset
		top.Material = door.Material
		top.CFrame = door.CFrame
			* CFrame.new(0, size.Y * 0.16, -size.Z / 2 - Facade.grainDepth)
			* CFrame.Angles(0, math.rad(90), 0)
		top.Parent = door
		local weld = Instance.new("WeldConstraint")
		weld.Name = "DoorTrimWeld"
		weld.Part0 = door
		weld.Part1 = top
		weld.Parent = top
	elseif panels == "window" then
		-- A glazed pane high in the leaf.
		local pane = Instance.new("Part")
		pane.Name = "DoorTrim"
		pane.Anchored = false
		pane.CanCollide = false
		pane.CanQuery = false
		pane.CanTouch = false
		pane.Massless = true
		pane.Size = Vector3.new(size.X * 0.5, size.Y * 0.26, Facade.grainDepth * 2)
		pane.Color = style.glass.color
		pane.Transparency = style.glass.transparency
		pane.Material = Enum.Material.Glass
		pane.CFrame = door.CFrame * CFrame.new(0, size.Y * 0.26, -size.Z / 2 - Facade.grainDepth)
		pane.Parent = door
		local weld = Instance.new("WeldConstraint")
		weld.Name = "DoorTrimWeld"
		weld.Part0 = door
		weld.Part1 = pane
		weld.Parent = pane
	elseif panels == "cross" then
		trim(size.X * 0.9, 0.4, 0, 0, inset)
		trim(0.4, size.Y * 0.86, 0, 0, inset)
		trim(size.X * 1.05, 0.35, 0, 0, inset, 32)
		trim(size.X * 1.05, 0.35, 0, 0, inset, -32)
	end
end

-- ————— apply —————

function FacadeService.ApplyFor(_self: any, player: Player)
	local origin = CafeService:GetPlotOrigin(player)
	local furniture = CafeService:GetFurnitureFolder(player)
	local data = DataService:GetProfile(player)
	if not origin or not furniture or not data then
		return
	end
	local model = furniture.Parent
	if not model then
		return
	end
	local style = Facade.resolve((data :: any).facade)

	local existing = model:FindFirstChild("FacadeStyle")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FacadeStyle"
	folder.Parent = model

	styleFrontWall(model, origin, folder, style)
	styleCrown(model, origin, folder, style)
	styleWindows(model, folder, style)
	styleDoor(model, style)
end

local AXES = { "architecture", "color", "motif", "doorStyle", "doorWood", "windowShape", "glass" }

local function handleSetFacade(player: Player, payload: unknown)
	if not Facade.enabled then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	if not limiter:check(player.UserId, os.clock()) then
		return
	end
	local p = payload :: any
	local data = DataService:GetProfile(player)
	if not data then
		return
	end

	-- Only accept ids that exist in the config; anything else is dropped rather
	-- than stored, so a bad payload can never persist an unrenderable style.
	local wanted: { [string]: string } = {}
	local changed = false
	local current = if typeof((data :: any).facade) == "table" then (data :: any).facade else {}
	for _, axis in AXES do
		local id = p[axis]
		if typeof(id) == "string" and Facade.byId[axis][id] then
			wanted[axis] = id
			if current[axis] ~= id then
				changed = true
			end
		end
	end
	if not changed then
		return -- nothing new: no charge, no rebuild
	end
	if not EconomyService:TrySpendCoins(player, Facade.changePrice) then
		Remotes.event("Notify")
			:FireClient(player, { kind = "error", reason = "insufficient_coins" })
		return
	end

	local stored: any = current
	for axis, id in wanted do
		stored[axis] = id
	end
	(data :: any).facade = stored
	DataService:Push(player)
	FacadeService:ApplyFor(player)
	Remotes.event("Notify"):FireClient(player, {
		kind = "facade_changed",
		text = "Your café front has a new look!",
	})
	if AnalyticsService then
		AnalyticsService:Track(player, "facade_changed", wanted)
	end
end

function FacadeService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	CafeService = ServiceRegistry.get("CafeService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function FacadeService.Start(_self: any)
	if not Facade.enabled then
		Log.info("FacadeService disabled (Config/Facade.enabled = false)")
		return
	end
	Remotes.event("SetFacade").OnServerEvent:Connect(handleSetFacade)

	local function applyWhenReady(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				if
					DataService:IsLoaded(player)
					and CafeService:GetPlotOrigin(player)
					and CafeService:GetFurnitureFolder(player)
				then
					FacadeService:ApplyFor(player)
					return
				end
				task.wait(1)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		applyWhenReady(player)
	end
	Players.PlayerAdded:Connect(applyWhenReady)
	Log.info("FacadeService ready (architecture/colour/motif/door/window personalisation)")
end

return FacadeService
