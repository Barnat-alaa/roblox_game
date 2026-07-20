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
local worldVariants: { [string]: { Model } } = {} -- split packs (e.g. trees)
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

-- Props: anchored, scaled, floor-friendly templates. Scale so the longest
-- horizontal axis matches `fit` (small tabletop items).
local function normalisePropModel(model: Model, fit: number): Model?
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

local function buildPropTemplate(assetId: number, fit: number): Model?
	local container = loadAndSanitise(assetId)
	if not container then
		return nil
	end
	return normalisePropModel(unwrap(container), fit)
end

-- The retro food Store item is a model pack rather than UI artwork. Load it
-- once, after sanitisation, and clone only the explicitly approved food meshes.
local function buildRetroPropTemplates(entry: any): { [string]: Model }
	local result: { [string]: Model } = {}
	local container = loadAndSanitise(entry.assetId)
	if not container then
		return result
	end
	local pack = unwrap(container)
	for recipeId, selection in entry.recipes do
		local source = pack:FindFirstChild(selection.sourceName, true)
		local model: Model? = nil
		if source and source:IsA("Model") then
			model = source:Clone()
		elseif source and source:IsA("BasePart") then
			model = Instance.new("Model")
			local clone = source:Clone()
			clone.Parent = model
		end
		if model then
			local ready = normalisePropModel(model, selection.fit)
			if ready then
				ready:SetAttribute("sourceAssetId", entry.assetId)
				ready:SetAttribute("sourceMeshName", selection.sourceName)
				result[recipeId] = ready
			end
		else
			Log.warn("AssetLibrary: retro food mesh missing", recipeId, selection.sourceName)
		end
	end
	pack:Destroy()
	return result
end

-- Furniture: scale by TARGET HEIGHT to keep real-world proportions (fit-to-
-- footprint squashed tall/long pieces), then clamp the horizontal span so it
-- still fits the grid cells, and rotate so the long axis lands on +X.
local function buildFurnitureTemplate(
	assetId: number,
	height: number,
	maxSpan: number,
	yaw: number?,
	flat: boolean?
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
	local hasPart = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			hasPart = true
			break
		end
	end
	if not hasPart then
		model:Destroy()
		return nil
	end
	-- Normalize the pivot to an axis-aligned centre so the model's LOADED
	-- (authored, upright) pose survives placement — instead of inheriting a
	-- random part's rotation (which left the floor lamp lying down and the rug
	-- standing on edge). With PrimaryPart cleared, GetPivot()==WorldPivot and
	-- GetBoundingBox() reports true world extents.
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(model:GetBoundingBox().Position)

	if flat then
		-- Lay the thinnest WORLD axis vertical, then scale by span (height would
		-- blow up a paper-thin mesh); some rugs import edge-on.
		local _, s = model:GetBoundingBox()
		if s.X <= s.Y and s.X <= s.Z then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(90)))
		elseif s.Z <= s.Y and s.Z <= s.X then
			model:PivotTo(model:GetPivot() * CFrame.Angles(math.rad(90), 0, 0))
		end
		model.WorldPivot = CFrame.new(model:GetBoundingBox().Position)
		local _, s2 = model:GetBoundingBox()
		local widest = math.max(s2.X, s2.Z)
		if widest > 0.01 then
			pcall(function()
				model:ScaleTo(model:GetScale() * (maxSpan / widest))
			end)
		end
	else
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
	end
	-- Re-centre the pivot after scaling (ScaleTo can shift the box).
	model.WorldPivot = CFrame.new(model:GetBoundingBox().Position)
	-- Facing correction applied at placement time (SpawnFurniture) so the grid
	-- rotation and this offset compose.
	if yaw and yaw ~= 0 then
		model:SetAttribute("assetYaw", yaw)
	end
	return model
end

local function cache(key: string, template: Model?)
	if template then
		local previous = templates[key]
		if previous then
			previous:Destroy()
		end
		template.Name = key
		template.Parent = cacheFolder
		templates[key] = template
	end
end

-- Height-scale a loose model in place (world decor variants).
local function scaleToHeight(model: Model, height: number)
	local _, size = model:GetBoundingBox()
	if size.Y > 0.01 then
		local scale = height / size.Y
		if scale > 0 and scale == scale then
			pcall(function()
				model:ScaleTo(model:GetScale() * scale)
			end)
		end
	end
end

-- World dressing (garden/street/plaza): one template, or a SPLIT pack whose
-- child models become variants (tree packs ship as a whole forest scene).
local function buildWorldTemplates(key: string, entry: any)
	local container = loadAndSanitise(entry.assetId)
	if not container then
		return false
	end
	local model = unwrap(container)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if entry.split then
		-- Packs ship as child Models, loose (Mesh)Parts, or Models inside a
		-- Folder (the tree pack) — flatten one folder level, wrap loose parts.
		local pool: { Instance } = {}
		for _, child in model:GetChildren() do
			if child:IsA("Folder") then
				for _, sub in child:GetChildren() do
					table.insert(pool, sub)
				end
			else
				table.insert(pool, child)
			end
		end
		local variants: { Model } = {}
		for _, child in pool do
			local variant: Model? = nil
			if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart", true) then
				child.Parent = nil
				variant = child
			elseif child:IsA("BasePart") then
				local wrapper = Instance.new("Model")
				child.Parent = wrapper
				variant = wrapper
			end
			if variant then
				if ensurePrimary(variant) then
					scaleToHeight(variant, entry.height)
					variant.Name = key .. "_variant"
					variant.Parent = cacheFolder
					table.insert(variants, variant)
				else
					variant:Destroy()
				end
			end
		end
		model:Destroy()
		if #variants == 0 then
			return false
		end
		worldVariants[key] = variants
		return true
	end
	if not ensurePrimary(model) then
		model:Destroy()
		return false
	end
	scaleToHeight(model, entry.height)
	cache("world:" .. key, model)
	return true
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
	-- Walk-capability gate: an INCOMPLETE Motor6D skeleton walks wrong (the
	-- 5/6-joint barista kit limped and hopped — live-verified 2026-07-17).
	-- R6 needs its full 6; R15 needs 13 — the hips/knees/shoulders/elbows that
	-- drive the walk cycle. Missing only the two ANKLES (13/15) still walks
	-- fine (feet stay flat), so the maid rig at 13 is accepted (2026-07-19).
	local motors = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			motors += 1
		end
	end
	local required = if humanoid.RigType == Enum.HumanoidRigType.R15 then 13 else 6
	if motors < required then
		Log.warn(
			string.format(
				"AssetLibrary: rig %d has %d/%d walk joints — rejected",
				assetId,
				motors,
				required
			)
		)
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

-- ————— public API: always returns a fresh clone or nil —————

local function cloneOf(key: string): Model?
	local t = templates[key]
	return if t then t:Clone() else nil
end

function AssetLibraryService.GetFurniture(_self: any, catalogId: string): Model?
	return cloneOf("furniture:" .. catalogId)
end

function AssetLibraryService.GetProp(_self: any, category: string, recipeId: string?): Model?
	if recipeId then
		local recipeSpecific = cloneOf("recipeProp:" .. recipeId)
		if recipeSpecific then
			return recipeSpecific
		end
	end
	return cloneOf("prop:" .. category)
end

function AssetLibraryService.GetStaff(_self: any, role: string): Model?
	return cloneOf("staff:" .. role)
end

-- Single-instance feature decor (e.g. the dirt spill mesh).
function AssetLibraryService.GetDecor(_self: any, key: string): Model?
	return cloneOf("decor:" .. key)
end

function AssetLibraryService.GetCustomerRig(_self: any): Model?
	if #customerRigKeys == 0 then
		return nil
	end
	return cloneOf(customerRigKeys[rng:NextInteger(1, #customerRigKeys)])
end

-- World decor clone: a split pack returns a random variant.
function AssetLibraryService.GetWorld(_self: any, key: string): Model?
	local variants = worldVariants[key]
	if variants and #variants > 0 then
		return variants[rng:NextInteger(1, #variants)]:Clone()
	end
	return cloneOf("world:" .. key)
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
			local t = buildFurnitureTemplate(
				entry.assetId,
				entry.height,
				entry.maxSpan,
				entry.yaw,
				entry.flat
			)
			if t and entry.liftY then
				t:SetAttribute("liftY", entry.liftY)
			end
			cache("furniture:" .. catalogId, t)
			tally(t ~= nil)
		end
		for key, entry in AssetManifest.world do
			tally(buildWorldTemplates(key, entry))
		end
		for category, entry in AssetManifest.props do
			local t = buildPropTemplate(entry.assetId, entry.fit)
			cache("prop:" .. category, t)
			tally(t ~= nil)
		end
		for key, entry in AssetManifest.decor do
			local t = buildPropTemplate(entry.assetId, entry.fit)
			cache("decor:" .. key, t)
			tally(t ~= nil)
		end
		local retroEntry = AssetManifest.retroPropPack
		local retroTemplates = buildRetroPropTemplates(retroEntry)
		for recipeId in retroEntry.recipes do
			local t = retroTemplates[recipeId]
			cache("recipeProp:" .. recipeId, t)
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
