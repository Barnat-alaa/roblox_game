--!strict
-- Server-authoritative furniture placement. The client sends a desired
-- {catalogId, gridX, gridY, rotation}; the server validates ownership, bounds,
-- overlap, rotation, and object count before committing and rendering.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Grid = require(Shared.Utilities.Grid)
local Furniture = require(Shared.Config.Furniture)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local BuildService = {}
BuildService.Name = "BuildService"

local DataService: any
local CafeService: any

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
	if not Grid.inBounds(gridX, gridY, def.width, def.depth, rotation) then
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

function BuildService.SpawnFurniture(_self: any, player: Player, placed: Types.PlacedFurniture)
	local def = Furniture[placed.catalogId]
	local origin = CafeService:GetPlotOrigin(player)
	local folder = CafeService:GetFurnitureFolder(player)
	if not def or not origin or not folder then
		return
	end

	local part = Instance.new("Part")
	part.Anchored = true
	part.Name = placed.catalogId
	part.Size =
		Vector3.new(def.width * Grid.CELL_SIZE - 0.2, def.height, def.depth * Grid.CELL_SIZE - 0.2)
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = Grid.cellToWorld(
		origin,
		placed.gridX,
		placed.gridY,
		def.width,
		def.depth,
		placed.rotation,
		def.height
	)
	part:SetAttribute("instanceId", placed.instanceId)
	part.Parent = folder
end

function BuildService.RenderProfile(_self: any, player: Player)
	local data = DataService:GetProfile(player)
	local folder = CafeService:GetFurnitureFolder(player)
	if not data then
		return
	end
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
	BuildService:SpawnFurniture(player, placed)
	DataService:Push(player)
end

local function handleRemove(player: Player, instanceId: unknown)
	if typeof(instanceId) ~= "string" then
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
			DataService:Push(player)
			return
		end
	end
end

function BuildService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	CafeService = ServiceRegistry.get("CafeService")
end

function BuildService.Start(_self: any)
	Remotes.event("PlaceFurniture").OnServerEvent:Connect(handlePlace)
	Remotes.event("RemoveFurniture").OnServerEvent:Connect(handleRemove)
	Players.PlayerRemoving:Connect(function(player)
		placeLimiter:clear(player.UserId)
	end)
end

return BuildService
