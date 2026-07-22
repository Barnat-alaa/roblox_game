--!strict
-- Server-authoritative furniture placement. The client sends a desired
-- {catalogId, gridX, gridY, rotation}; the server validates ownership, bounds,
-- overlap, rotation, and object count before committing and rendering.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Grid = require(Shared.Utilities.Grid)
local World = require(Shared.Config.World)
local AssetManifest = require(Shared.Config.AssetManifest)
local Furniture = require(Shared.Config.Furniture)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local BuildService = {}
BuildService.Name = "BuildService"

local DataService: any
local CafeService: any
local KitchenService: any
local AssetLibraryService: any

local placeLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)
local nextInstance = 0

local function newInstanceId(): string
	nextInstance += 1
	return "f_" .. nextInstance
end

local function validatePlacement(
	data: Types.PlayerData,
	def: Types.FurnitureDefinition,
	gridX: number,
	gridY: number,
	rotation: number
): (boolean, string?)
	-- Reject NaN / non-integers / bad rotation up front.
	if gridX ~= gridX or gridY ~= gridY then
		return false, "nan_coords"
	end
	if gridX ~= math.floor(gridX) or gridY ~= math.floor(gridY) then
		return false, "non_integer_coords"
	end
	if rotation ~= math.floor(rotation) or rotation < 0 or rotation > 3 then
		return false, "bad_rotation"
	end
	if not def.rotatable and rotation ~= 0 then
		return false, "not_rotatable"
	end
	-- Placement is clamped to the owner's CURRENT interior depth: the garden
	-- behind the back wall is not buildable until the expansion is bought (S4).
	local tier = math.max(0, math.floor(tonumber(data.expansionTier) or 0))
	local depthCells = World.interiorDepthTiers[math.clamp(tier + 1, 1, #World.interiorDepthTiers)]
	if not Grid.inBounds(gridX, gridY, def.width, def.depth, rotation, nil, depthCells) then
		return false, "out_of_bounds"
	end
	if #data.placedFurniture >= EconomyConfig.maxPlacedFurniture then
		return false, "too_many_objects"
	end

	local nw, nd = Grid.footprintSize(def.width, def.depth, rotation)
	for _, placed in data.placedFurniture do
		local pdef = Furniture[placed.catalogId]
		if pdef then
			local pw, pd = Grid.footprintSize(pdef.width, pdef.depth, placed.rotation)
			if Grid.rectsOverlap(gridX, gridY, nw, nd, placed.gridX, placed.gridY, pw, pd) then
				return false, "overlap"
			end
		end
	end
	return true, nil
end

-- ————— Composite furniture builders (art direction pass) —————
-- Original procedural pieces that give the greybox its café-sim read:
-- red-cloth tables, kettle-topped machine, counter with plates. Offsets are
-- in the item's LOCAL space (cf carries the grid rotation). All greybox —
-- Blender replacements slot in per-catalogId later.

local WHITE = Color3.fromRGB(255, 245, 218)
local WOOD = Color3.fromRGB(150, 110, 80)
local DARKWOOD = Color3.fromRGB(96, 70, 52)
local CLOTH_RED = Color3.fromRGB(238, 76, 62)
local STEEL = Color3.fromRGB(192, 197, 204)

local function decor(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

type Builder = (model: Model, cf: CFrame, def: Types.FurnitureDefinition) -> ()

local Builders: { [string]: Builder } = {
	table_round = function(model, cf, _def)
		-- Red tablecloth over a white skirt — the classic checkered-table read.
		local top = decor(
			model,
			"Top",
			Vector3.new(6.8, 0.5, 6.8),
			cf * CFrame.new(0, 0.75, 0),
			CLOTH_RED,
			Enum.Material.Fabric
		)
		top.CanCollide = true
		decor(
			model,
			"Skirt",
			Vector3.new(6.2, 0.9, 6.2),
			cf * CFrame.new(0, 0.2, 0),
			WHITE,
			Enum.Material.Fabric
		)
		decor(
			model,
			"Pedestal",
			Vector3.new(1.3, 1.5, 1.3),
			cf * CFrame.new(0, -0.25, 0),
			DARKWOOD,
			Enum.Material.Wood
		)
	end,
	chair_wood = function(model, cf, _def)
		local seat = decor(
			model,
			"Seat",
			Vector3.new(2.6, 0.4, 2.6),
			cf * CFrame.new(0, -0.1, 0),
			WOOD,
			Enum.Material.Wood
		)
		seat.CanCollide = true
		decor(
			model,
			"Back",
			Vector3.new(2.6, 1.9, 0.4),
			cf * CFrame.new(0, 0.85, 1.1),
			WOOD,
			Enum.Material.Wood
		)
		decor(
			model,
			"Legs",
			Vector3.new(2.2, 0.9, 2.2),
			cf * CFrame.new(0, -0.65, 0),
			DARKWOOD,
			Enum.Material.Wood
		)
	end,
	coffee_machine = function(model, cf, _def)
		local body =
			decor(model, "Body", Vector3.new(3.2, 2.4, 3.2), cf * CFrame.new(0, -0.3, 0), WHITE)
		body.CanCollide = true
		decor(
			model,
			"Cooktop",
			Vector3.new(3.4, 0.3, 3.4),
			cf * CFrame.new(0, 1.05, 0),
			Color3.fromRGB(70, 62, 58)
		)
		local kettle = decor(
			model,
			"Kettle",
			Vector3.new(1.2, 1.7, 1.7),
			cf * CFrame.new(0, 1.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
			STEEL,
			Enum.Material.Metal
		)
		kettle.Shape = Enum.PartType.Cylinder
		decor(
			model,
			"Lid",
			Vector3.new(0.7, 0.7, 0.7),
			cf * CFrame.new(0, 2.45, 0),
			Color3.fromRGB(70, 62, 58)
		)
		decor(model, "Accent", Vector3.new(3.24, 0.4, 3.24), cf * CFrame.new(0, 0.35, 0), CLOTH_RED)
	end,
	counter = function(model, cf, _def)
		local body =
			decor(model, "Body", Vector3.new(11.6, 2.6, 3.4), cf * CFrame.new(0, -0.2, 0), WHITE)
		body.CanCollide = true
		decor(
			model,
			"Top",
			Vector3.new(11.8, 0.4, 3.8),
			cf * CFrame.new(0, 1.15, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		for _, x in { -3.4, 0, 3.4 } do
			local plate = decor(
				model,
				"Plate",
				Vector3.new(0.25, 1.7, 1.7),
				cf * CFrame.new(x, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
				WHITE,
				Enum.Material.Glass
			)
			plate.Shape = Enum.PartType.Cylinder
		end
	end,
	oven = function(model, cf, _def)
		-- Stone bakery oven with a warm glowing mouth.
		local body = decor(
			model,
			"Body",
			Vector3.new(7.2, 2.8, 3.2),
			cf * CFrame.new(0, -0.3, 0),
			Color3.fromRGB(150, 120, 100),
			Enum.Material.Brick
		)
		body.CanCollide = true
		decor(
			model,
			"Arch",
			Vector3.new(3.4, 1.7, 0.4),
			cf * CFrame.new(0, 0.35, -1.5),
			Color3.fromRGB(60, 45, 40)
		)
		local glow = decor(
			model,
			"Glow",
			Vector3.new(2.6, 1, 0.25),
			cf * CFrame.new(0, 0.05, -1.58),
			Color3.fromRGB(255, 150, 70),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 80)
		light.Range = 9
		light.Brightness = 0.8
		light.Parent = glow
		decor(
			model,
			"Top",
			Vector3.new(7.4, 0.4, 3.4),
			cf * CFrame.new(0, 1.3, 0),
			Color3.fromRGB(96, 70, 52),
			Enum.Material.Wood
		)
		decor(
			model,
			"Chimney",
			Vector3.new(1, 1.8, 1),
			cf * CFrame.new(2.4, 2.1, 0.7),
			Color3.fromRGB(122, 98, 84),
			Enum.Material.Brick
		)
	end,
	prep_station = function(model, cf, _def)
		local body =
			decor(model, "Body", Vector3.new(7.2, 2.4, 3), cf * CFrame.new(0, -0.3, 0), WHITE)
		body.CanCollide = true
		decor(
			model,
			"Top",
			Vector3.new(7.4, 0.3, 3.2),
			cf * CFrame.new(0, 1, 0),
			STEEL,
			Enum.Material.Metal
		)
		decor(
			model,
			"Board",
			Vector3.new(2.2, 0.18, 1.6),
			cf * CFrame.new(-1.7, 1.25, 0),
			WOOD,
			Enum.Material.Wood
		)
		local bowl = decor(
			model,
			"Bowl",
			Vector3.new(0.55, 1.5, 1.5),
			cf * CFrame.new(1.6, 1.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
			STEEL,
			Enum.Material.Metal
		)
		bowl.Shape = Enum.PartType.Cylinder
		decor(model, "Accent", Vector3.new(7.24, 0.4, 3.04), cf * CFrame.new(0, 0.3, 0), CLOTH_RED)
	end,
	plant_small = function(model, cf, _def)
		local pot = decor(
			model,
			"Pot",
			Vector3.new(1.4, 1.7, 1.7),
			cf * CFrame.new(0, -0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(185, 115, 90),
			Enum.Material.Concrete
		)
		pot.Shape = Enum.PartType.Cylinder
		pot.CanCollide = true
		local bush = decor(
			model,
			"Bush",
			Vector3.new(2.5, 2.5, 2.5),
			cf * CFrame.new(0, 0.5, 0),
			Color3.fromRGB(105, 150, 88),
			Enum.Material.Grass
		)
		bush.Shape = Enum.PartType.Ball
	end,
	lamp_floor = function(model, cf, _def)
		local base =
			decor(model, "Base", Vector3.new(1.4, 0.3, 1.4), cf * CFrame.new(0, -1.85, 0), DARKWOOD)
		base.CanCollide = true
		decor(
			model,
			"Pole",
			Vector3.new(0.35, 3.4, 0.35),
			cf * CFrame.new(0, 0, 0),
			DARKWOOD,
			Enum.Material.Metal
		)
		local shade = decor(
			model,
			"Shade",
			Vector3.new(1.8, 1.4, 1.8),
			cf * CFrame.new(0, 1.8, 0),
			Color3.fromRGB(255, 218, 150),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 208, 140)
		light.Range = 14
		light.Brightness = 0.9
		light.Parent = shade
	end,
}

function BuildService.SpawnFurniture(_self: any, player: Player, placed: Types.PlacedFurniture)
	local def = Furniture[placed.catalogId]
	local origin = CafeService:GetPlotOrigin(player)
	local folder = CafeService:GetFurnitureFolder(player)
	if not def or not origin or not folder then
		return
	end

	local cf = Grid.cellToWorld(
		origin,
		placed.gridX,
		placed.gridY,
		def.width,
		def.depth,
		placed.rotation,
		def.height
	)

	-- Prefer a vetted Creator Store model (Step S1). cf is the footprint centre
	-- at height/2, so the cell floor sits at cf.Y - def.height/2; drop for the
	-- procedural builder, then the greybox box, whenever the template is absent.
	local template: Model? = if AssetLibraryService
		then AssetLibraryService:GetFurniture(placed.catalogId)
		else nil
	if template then
		template.Name = placed.catalogId
		template:SetAttribute("instanceId", placed.instanceId)
		-- Solid, walk-blocking pieces become navmesh obstacles so customers
		-- path AROUND them; seats/decor stay passable so diners can reach chairs.
		if def.blocksWalk then
			for _, d in template:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = true
				end
			end
		end
		local _, size = template:GetBoundingBox()
		local floorY = cf.Y - def.height / 2
		-- Wall art / clocks / hanging lamps mount above the floor (template
		-- liftY); a per-instance liftY (e.g. the seed espresso machine sitting
		-- ON the counter) stacks on top of that.
		local lift = (tonumber(template:GetAttribute("liftY")) or 0) + (tonumber(placed.liftY) or 0)
		local assetYaw = tonumber(template:GetAttribute("assetYaw")) or 0
		local pos = Vector3.new(cf.Position.X, floorY + lift + size.Y / 2, cf.Position.Z)
		template:PivotTo(
			CFrame.new(pos) * CFrame.Angles(0, math.rad(90 * placed.rotation + assetYaw), 0)
		)
		template.Parent = folder
		return
	end

	local model = Instance.new("Model")
	model.Name = placed.catalogId
	model:SetAttribute("instanceId", placed.instanceId)

	local builder = Builders[placed.catalogId]
	if builder then
		builder(model, cf, def)
	else
		-- Fallback: the original greybox box.
		local part = decor(
			model,
			placed.catalogId,
			Vector3.new(
				def.width * Grid.CELL_SIZE - 0.2,
				def.height,
				def.depth * Grid.CELL_SIZE - 0.2
			),
			cf,
			def.color
		)
		part.CanCollide = true
	end

	-- Match the imported pieces' size, growing from the floor so the model does
	-- not sink or hover after scaling.
	local displayScale = AssetManifest.displayScale
	if displayScale ~= 1 then
		model.PrimaryPart = nil
		model.WorldPivot = CFrame.new(cf.Position.X, cf.Y - def.height / 2, cf.Position.Z)
		pcall(function()
			model:ScaleTo(displayScale)
		end)
	end

	model.Parent = folder
end

local function isTable(catalogId: string, def: Types.FurnitureDefinition): boolean
	return def.category == "Seating"
		and def.seatCount == 0
		and string.find(string.lower(catalogId), "table", 1, true) ~= nil
end

-- Recalculate every nearby seat, rather than only the chair being placed.
-- This makes facing independent of placement order: table-first, chair-first,
-- and old saved layouts all converge on the same correct rotations.
local function autoFaceSeats(data: Types.PlayerData): { [string]: boolean }
	local changed: { [string]: boolean } = {}
	for _, seat in data.placedFurniture do
		local seatDef = Furniture[seat.catalogId]
		if seatDef and seatDef.seatCount > 0 and seatDef.width == 1 and seatDef.depth == 1 then
			local seatX = seat.gridX + 0.5
			local seatZ = seat.gridY + 0.5
			local bestDist = math.huge
			local facing: number? = nil
			for _, other in data.placedFurniture do
				local otherDef = Furniture[other.catalogId]
				if otherDef and isTable(other.catalogId, otherDef) then
					local w, d = Grid.footprintSize(otherDef.width, otherDef.depth, other.rotation)
					local dx = other.gridX + w / 2 - seatX
					local dz = other.gridY + d / 2 - seatZ
					local dist = math.max(math.abs(dx), math.abs(dz))
					if dist <= 2.5 and dist < bestDist then
						bestDist = dist
						facing = Grid.rotationFacingDelta(dx, dz)
					end
				end
			end
			if facing ~= nil and seatDef.rotatable and seat.rotation ~= facing then
				seat.rotation = facing
				changed[seat.instanceId] = true
			end
		end
	end
	return changed
end

local function respawnFurniture(
	player: Player,
	data: Types.PlayerData,
	instanceIds: { [string]: boolean }
)
	local folder = CafeService:GetFurnitureFolder(player)
	if not folder then
		return
	end
	for instanceId in instanceIds do
		for _, child in folder:GetChildren() do
			if child:GetAttribute("instanceId") == instanceId then
				child:Destroy()
			end
		end
		for _, placed in data.placedFurniture do
			if placed.instanceId == instanceId then
				BuildService:SpawnFurniture(player, placed)
				break
			end
		end
	end
end

function BuildService.RenderProfile(_self: any, player: Player)
	local data = DataService:GetProfile(player)
	local folder = CafeService:GetFurnitureFolder(player)
	if not data then
		return
	end
	autoFaceSeats(data)
	if folder then
		folder:ClearAllChildren()
	end
	for _, placed in data.placedFurniture do
		BuildService:SpawnFurniture(player, placed)
	end
end

local function handlePlace(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: any
	local catalogId, gridX, gridY, rotation = p.catalogId, p.gridX, p.gridY, p.rotation
	if typeof(catalogId) ~= "string" then
		return
	end
	if typeof(gridX) ~= "number" or typeof(gridY) ~= "number" or typeof(rotation) ~= "number" then
		return
	end
	if not placeLimiter:check(player.UserId, os.clock()) then
		return
	end

	local def = Furniture[catalogId]
	if not def then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end

	if (data.inventory[catalogId] or 0) <= 0 then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "not_owned" })
		return
	end

	local ok, reason = validatePlacement(data, def, gridX, gridY, rotation)
	if not ok then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = reason })
		return
	end

	data.inventory[catalogId] -= 1
	local placed: Types.PlacedFurniture = {
		instanceId = newInstanceId(),
		catalogId = catalogId,
		gridX = gridX,
		gridY = gridY,
		floor = 0,
		rotation = rotation,
	}
	table.insert(data.placedFurniture, placed)
	local changed = autoFaceSeats(data)
	changed[placed.instanceId] = true
	respawnFurniture(player, data, changed)
	DataService:Push(player)
end

local function handleRemove(player: Player, instanceId: unknown)
	if typeof(instanceId) ~= "string" then
		return
	end
	if not placeLimiter:check(player.UserId, os.clock()) then
		return
	end
	-- Can't pocket a stove mid-batch.
	if KitchenService and KitchenService:IsCooking(player, instanceId :: string) then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "busy_cooking" })
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	for i, placed in data.placedFurniture do
		if placed.instanceId == instanceId then
			table.remove(data.placedFurniture, i)
			data.inventory[placed.catalogId] = (data.inventory[placed.catalogId] or 0) + 1
			local folder = CafeService:GetFurnitureFolder(player)
			if folder then
				for _, child in folder:GetChildren() do
					if child:GetAttribute("instanceId") == instanceId then
						child:Destroy()
					end
				end
			end
			respawnFurniture(player, data, autoFaceSeats(data))
			DataService:Push(player)
			return
		end
	end
end

function BuildService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	CafeService = ServiceRegistry.get("CafeService")
	KitchenService = ServiceRegistry.get("KitchenService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
end

function BuildService.Start(_self: any)
	Remotes.event("PlaceFurniture").OnServerEvent:Connect(handlePlace)
	Remotes.event("RemoveFurniture").OnServerEvent:Connect(handleRemove)
	Players.PlayerRemoving:Connect(function(player)
		placeLimiter:clear(player.UserId)
	end)

	-- Furniture placed on join renders before the async asset load finishes;
	-- redraw everyone's café with the real models once the library is ready.
	if AssetLibraryService then
		AssetLibraryService:OnReady(function()
			for _, player in Players:GetPlayers() do
				BuildService:RenderProfile(player)
			end
		end)
	end
end

return BuildService
