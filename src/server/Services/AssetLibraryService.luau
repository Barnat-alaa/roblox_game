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
-- Loading runs in the background so boot is never blocked. Renders that happen
-- before a template is ready use the procedural fallback, then OnReady fires so
-- BuildService/StaffService can re-render with the real models once loaded.

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
local isReady = false
local readyCallbacks: { () -> () } = {}

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

local function loadAndSanitise(assetId: number): Model?
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not result then
		Log.warn("AssetLibrary: load failed", assetId, result)
		return nil
	end
	sanitise(result)
	return result
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

-- ————— build templates per kind —————

-- Props: one anchored, scaled, floor-friendly template. Scaled so the longest
-- horizontal axis matches `fit` (small tabletop items).
local function buildPropTemplate(assetId: number, fit: number): Model?
	local container = loadAndSanitise(assetId)
	if not container then
		return nil
	end
	local model = unwrap(container)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if not ensurePrimary(model) then
		model:Destroy()
		return nil
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Z, 0.01)
	local scale = fit / longest
	if scale > 0 and scale ~= 1 and scale == scale then
		pcall(function()
			-- Multiply the model's CURRENT scale: imported (e.g. Sketchfab)
			-- models can carry a non-1 baked scale, and ScaleTo is absolute.
			model:ScaleTo(model:GetScale() * scale)
		end)
	end
	return model
end

-- Furniture: scale by TARGET HEIGHT to keep real-world proportions (fit-to-
-- footprint squashed tall/long pieces), then clamp the horizontal span so it
-- still fits the grid cells, and rotate so the long axis lands on +X.
local function buildFurnitureTemplate(
	assetId: number,
	height: number,
	maxSpan: number,
	yaw: number?
): Model?
	local container = loadAndSanitise(assetId)
	if not container then
		return nil
	end
	local model = unwrap(container)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if not ensurePrimary(model) then
		model:Destroy()
		return nil
	end
	local _, size = model:GetBoundingBox()
	if size.Y > 0.01 then
		local scale = height / size.Y
		local span = math.max(size.X, size.Z) * scale
		if span > maxSpan then
			scale = maxSpan / math.max(size.X, size.Z)
		end
		if scale > 0 and scale == scale then
			pcall(function()
				-- Multiply the current scale (imported models can carry a
				-- non-1 baked scale; ScaleTo is absolute, not relative).
				model:ScaleTo(model:GetScale() * scale)
			end)
		end
	end
	if yaw and yaw ~= 0 then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(yaw), 0))
	end
	return model
end

-- Rigs: keep Humanoid + HumanoidRootPart + Head, ready for MoveTo. The rig can
-- sit one level below the LoadAsset container (a Model wrapping the character),
-- so locate the Humanoid recursively and adopt its parent as the template.
local function buildRigTemplate(assetId: number): Model?
	local container = loadAndSanitise(assetId)
	if not container then
		return nil
	end
	local humanoid = container:FindFirstChildWhichIsA("Humanoid", true)
	local rig = if humanoid then humanoid.Parent :: Instance else nil
	if not humanoid or not rig or not rig:IsA("Model") then
		Log.warn("AssetLibrary: rig has no Humanoid", assetId)
		container:Destroy()
		return nil
	end
	local head = rig:FindFirstChild("Head") :: BasePart?
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not head then
		-- No native HumanoidRootPart = an old kit that cannot actually walk
		-- (synthesising one produced the sliding/teleporting waiter — owner
		-- rejected). Only real, complete rigs pass.
		Log.warn("AssetLibrary: rig missing root/head — rejected", assetId)
		container:Destroy()
		return nil
	end
	-- Walk-capability gate: a rig with fewer Motor6D joints than a minimal R6
	-- skeleton was weld-assembled (a statue) and would slide instead of walk.
	local motors = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			motors += 1
		end
	end
	if motors < 4 then
		Log.warn("AssetLibrary: rig has no walk joints — rejected", assetId)
		container:Destroy()
		return nil
	end
	if rig ~= container then
		rig.Parent = nil
		container:Destroy()
	end
	for _, d in rig:GetDescendants() do
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
	rig.PrimaryPart = root
	return rig
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

function AssetLibraryService.IsReady(_self: any): boolean
	return isReady
end

-- Run fn once templates are loaded (immediately if that already happened).
-- Lets join-time renderers redraw with the real models after the async load.
function AssetLibraryService.OnReady(_self: any, fn: () -> ())
	if isReady then
		task.spawn(fn)
	else
		table.insert(readyCallbacks, fn)
	end
end

function AssetLibraryService.Init(_self: any)
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "AssetTemplates"
	cacheFolder.Parent = ServerStorage
end

function AssetLibraryService.Start(_self: any)
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
			local t = buildFurnitureTemplate(entry.assetId, entry.height, entry.maxSpan, entry.yaw)
			cache("furniture:" .. catalogId, t)
			tally(t ~= nil)
		end
		for category, entry in AssetManifest.props do
			local t = buildPropTemplate(entry.assetId, entry.fit)
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

		isReady = true
		Log.info(
			string.format("AssetLibrary ready: %d templates loaded, %d fell back", loaded, failed)
		)
		for _, cb in readyCallbacks do
			task.spawn(cb)
		end
		table.clear(readyCallbacks)
	end)
end

return AssetLibraryService
