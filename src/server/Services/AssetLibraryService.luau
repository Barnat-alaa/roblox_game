--!strict
-- Asset library (Step S1): turns owner-picked Creator Store models into safe,
-- grid-sized, cached templates the rest of the game clones. The contract:
--   1. Load each manifest asset with InsertService in a pcall (a failure just
--      means that key stays nil → callers fall back to procedural greybox).
--   2. SANITISE: destroy every Script/LocalScript/ModuleScript, Remote/Bindable
--      object, and Tool — no third-party code ever runs in our game.
--   3. Normalise: unwrap the LoadAsset container to the real Model, scale
--      furniture/props to their grid footprint, prep rigs for our walk system.
--   4. Cache the template in ServerStorage; Get* returns a fresh clone or nil.
-- Loading runs in the background so boot is never blocked; until a template is
-- ready, Get* returns nil and the caller renders the procedural fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local Shared = ReplicatedStorage.Shared
local AssetManifest = require(Shared.Config.AssetManifest)
local Log = require(Shared.Utilities.Log)

local AssetLibraryService = {}
AssetLibraryService.Name = "AssetLibraryService"

local templates: { [string]: Model } = {}
local customerRigKeys: { string } = {}
local rng = Random.new()
local cacheFolder: Folder

-- ————— sanitise: strip everything that could run or clutter —————

local function sanitise(root: Instance)
	for _, d in root:GetDescendants() do
		if
			d:IsA("BaseScript")
			or d:IsA("ModuleScript")
			or d:IsA("RemoteEvent")
			or d:IsA("RemoteFunction")
			or d:IsA("BindableEvent")
			or d:IsA("BindableFunction")
			or d:IsA("Tool")
			or d:IsA("Sound")
		then
			d:Destroy()
		end
	end
end

-- LoadAsset returns a container Model holding the asset's top-level instances.
-- Prefer a single Model child (the real thing); otherwise use the container.
local function unwrap(container: Model): Model
	local onlyModel: Model? = nil
	local modelCount = 0
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			modelCount += 1
			onlyModel = child
		end
	end
	if modelCount == 1 and onlyModel then
		onlyModel.Parent = nil
		container:Destroy()
		return onlyModel
	end
	return container
end

local function ensurePrimary(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local biggest: BasePart? = nil
	local bestVol = -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVol then
				bestVol = v
				biggest = d
			end
		end
	end
	model.PrimaryPart = biggest
	return biggest
end

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
end

-- ————— load helpers per kind —————

local function loadRaw(assetId: number): Model?
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not result then
		Log.warn("AssetLibrary: load failed", assetId, result)
		return nil
	end
	sanitise(result)
	return unwrap(result)
end

-- Furniture/props: one anchored, scaled, floor-friendly template.
local function buildStaticTemplate(assetId: number, fitX: number, fitZ: number): Model?
	local model = loadRaw(assetId)
	if not model then
		return nil
	end
	anchorAll(model)
	if not ensurePrimary(model) then
		model:Destroy()
		return nil
	end
	local _, size = model:GetBoundingBox()
	if size.X > 0.01 and size.Z > 0.01 then
		local scale = math.min(fitX / size.X, fitZ / size.Z)
		if scale > 0 and scale ~= 1 and scale == scale then
			pcall(function()
				model:ScaleTo(scale)
			end)
		end
	end
	return model
end

-- Rigs: keep Humanoid + HumanoidRootPart + Head, ready for MoveTo. Limbs go
-- non-collide (queues never jostle); the root carries floor contact.
local function buildRigTemplate(assetId: number): Model?
	local model = loadRaw(assetId)
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = model:FindFirstChild("Head") :: BasePart?
	if not humanoid or not root or not head then
		Log.warn("AssetLibrary: rig missing Humanoid/root/head", assetId)
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = d ~= root
			if d ~= root then
				d.CanCollide = false
			end
			d.CanQuery = false
		end
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.PrimaryPart = root
	return model
end

local function cache(key: string, template: Model?)
	if template then
		template.Name = key
		template.Parent = cacheFolder
		templates[key] = template
	end
end

-- ————— public API: always returns a fresh clone or nil —————

local function cloneOf(key: string): Model?
	local t = templates[key]
	return if t then t:Clone() else nil
end

function AssetLibraryService.GetFurniture(_self: any, catalogId: string): Model?
	return cloneOf("furniture:" .. catalogId)
end

function AssetLibraryService.GetProp(_self: any, category: string): Model?
	return cloneOf("prop:" .. category)
end

function AssetLibraryService.GetStaff(_self: any, role: string): Model?
	return cloneOf("staff:" .. role)
end

function AssetLibraryService.GetCustomerRig(_self: any): Model?
	if #customerRigKeys == 0 then
		return nil
	end
	return cloneOf(customerRigKeys[rng:NextInteger(1, #customerRigKeys)])
end

function AssetLibraryService.Init(_self: any)
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "AssetTemplates"
	cacheFolder.Parent = ServerStorage
end

function AssetLibraryService.Start(_self: any)
	-- Load everything in the background; templates populate as they arrive.
	task.spawn(function()
		local loaded, failed = 0, 0
		local function tally(ok: boolean)
			if ok then
				loaded += 1
			else
				failed += 1
			end
		end

		for catalogId, entry in AssetManifest.furniture do
			local key = "furniture:" .. catalogId
			local t = buildStaticTemplate(entry.assetId, entry.fitX, entry.fitZ)
			cache(key, t)
			tally(t ~= nil)
		end
		for category, entry in AssetManifest.props do
			local t = buildStaticTemplate(entry.assetId, entry.fit, entry.fit)
			cache("prop:" .. category, t)
			tally(t ~= nil)
		end
		for role, entry in AssetManifest.staff do
			local t = buildRigTemplate(entry.assetId)
			cache("staff:" .. role, t)
			tally(t ~= nil)
		end
		for i, entry in AssetManifest.customerRigs do
			local key = "customerRig:" .. i
			local t = buildRigTemplate(entry.assetId)
			if t then
				cache(key, t)
				table.insert(customerRigKeys, key)
			end
			tally(t ~= nil)
		end
		Log.info(
			string.format("AssetLibrary ready: %d templates loaded, %d fell back", loaded, failed)
		)
	end)
end

return AssetLibraryService
