--!strict
-- Player data: load, reconcile, migrate, autosave, save-on-leave, BindToClose.
--
-- SCOPE NOTE: this MVP layer uses a single DataStore key per user with retries.
-- It is NOT full cross-server session locking. Before public launch, swap the
-- load/save internals for ProfileStore (see docs/ARCHITECTURE.md → Data). The
-- public API (GetProfile/IsLoaded/Push) is designed so that swap is internal.
--
-- If DataStore API access is unavailable (common in Studio until you enable
-- "Studio Access to API Services" on a published place), we fall back to an
-- in-memory store so the game is still fully testable locally.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Economy = require(Shared.Config.Economy)
local Recipes = require(Shared.Config.Recipes)
local Kitchen = require(Shared.Config.Kitchen)
local Operations = require(Shared.Config.Operations)
local InventoryMath = require(Shared.Utilities.InventoryMath)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Network.Remotes)

local SCHEMA_VERSION = 3

-- Environment prefix keeps DEV / STAGING / PROD data strictly separate.
-- Resolved at boot instead of hardcoded, for two reasons that both bite the
-- moment this place is published:
--   • a hardcoded "DEV" would file real, live players into the DEV store;
--   • worse, once the place IS published, a Studio playtest would otherwise
--     read and OVERWRITE production saves. Studio is therefore pinned to DEV.
local function environmentPrefix(): string
	-- Explicit override wins: set a string "Environment" attribute on the place
	-- (e.g. "STAGING") to point one build at its own store.
	local override = game:GetAttribute("Environment")
	if typeof(override) == "string" and override ~= "" then
		return string.upper(override)
	end
	if RunService:IsStudio() then
		return "DEV"
	end
	-- An unpublished server has no DataStore access at all; treat it as DEV.
	if game.PlaceId == 0 then
		return "DEV"
	end
	return "PROD"
end

local ENV_PREFIX = environmentPrefix()
local STORE_NAME = ENV_PREFIX .. "_PlayerProfiles_v1"

local DataService = {}
DataService.Name = "DataService"

local store: DataStore? = nil
local profiles: { [number]: Types.PlayerData } = {}
local loaded: { [number]: boolean } = {}
local loading: { [number]: boolean } = {}
-- Users whose save could NOT be read back from the DataStore. Their in-memory
-- profile is a blank default rather than their real progress, so every write
-- path must skip them — otherwise one failed GetAsync permanently erases an
-- account at the next autosave.
local saveBlocked: { [number]: boolean } = {}

local function starterStaff(): { Types.StaffMember }
	return {
		{ id = "staff_barista_mia", typeId = "barista_mia", level = 1, experience = 0 },
		{ id = "staff_cook_sam", typeId = "cook_sam", level = 1, experience = 0 },
		{ id = "staff_waiter_noah", typeId = "waiter_noah", level = 1, experience = 0 },
		{ id = "staff_cleaner_pia", typeId = "cleaner_pia", level = 1, experience = 0 },
	}
end

local function defaultKitchen(): Types.KitchenState
	local now = os.time()
	local kitchen: Types.KitchenState = {
		cooks = {},
		stock = { espresso = 3, tea = 3 },
		lots = {},
		reservations = {},
		jobs = {},
		menu = { espresso = true, tea = true },
		targetStock = { espresso = 6, tea = 6 },
		priorities = { espresso = 1, tea = 1 },
		stats = { produced = 0, served = 0, spoiled = 0 },
		lastActiveAt = now,
		nextLotId = 0,
		nextReservationId = 0,
		nextJobId = 0,
	}
	InventoryMath.addLot(kitchen, "espresso", 3, now, now + Recipes.espresso.spoilTime)
	InventoryMath.addLot(kitchen, "tea", 3, now, now + Recipes.tea.spoilTime)
	return kitchen
end

local function defaultOperations(): Types.OperationsState
	local now = os.time()
	return {
		satisfaction = Operations.startingSatisfaction,
		cleanliness = Operations.startingCleanliness,
		staffCapacity = {
			Barista = Operations.startingStaffCapacity,
			Cook = Operations.startingStaffCapacity,
			Waiter = Operations.startingStaffCapacity,
			Cleaner = Operations.startingStaffCapacity,
		},
		lastSeenAt = now,
		lastDirtAt = now,
		lastOffline = nil,
	}
end

local function defaultProfile(): Types.PlayerData
	return {
		schemaVersion = SCHEMA_VERSION,
		coins = Economy.startingCoins,
		level = 1,
		experience = 0,
		reputation = Economy.startingReputation,
		cafeStars = 0,
		buzz = 10,
		expansionTier = 0,
		regulars = {},
		kitchen = defaultKitchen(),
		daily = { dateKey = "", goals = {}, streak = 0 },
		trophies = {},
		inventory = { table_round = 2, chair_wood = 4, plant_small = 1 },
		-- Seed kitchen sits a few cells into the room, clear of the front door
		-- lane (the facade door is centred on the plot's front wall).
		placedFurniture = {
			{
				-- Wide service counter (5 cells) across the kitchen front.
				instanceId = "seed_counter",
				catalogId = "counter",
				gridX = 4,
				gridY = 3,
				floor = 0,
				rotation = 0,
			},
			{
				-- Espresso machine sits ON the counter toward the owner-facing
				-- RIGHT end (low local X), rotated to face the room. Verified in
				-- Studio: facing into the café the player's right IS low local X,
				-- so gridX = 4 (local X 18) is correct — do not "flip" it.
				-- liftY is the machine's BOTTOM height above the floor; the
				-- counter's worktop measures 2.43 studs, so 2.43 rests it flush.
				-- (At the old 3.5 it floated 1.07 studs above the surface.)
				instanceId = "seed_coffee",
				catalogId = "coffee_machine",
				gridX = 4,
				gridY = 3,
				floor = 0,
				rotation = 1,
				liftY = 2.43,
			},
		},
		unlockedRecipes = { espresso = true, tea = true },
		recipeMastery = {},
		staff = starterStaff(),
		operations = defaultOperations(),
		settings = { musicVolume = 0.6, sfxVolume = 0.8, reducedEffects = false },
		stats = {
			customersServed = 0,
			totalCoinsEarned = 0,
			recipesCooked = 0,
			tutorialCompleted = false,
			tutorialStep = 0,
		},
	}
end

-- Fill any keys added since the profile was saved (forward-compatible).
local function reconcile(data: any): Types.PlayerData
	local base = defaultProfile()
	if typeof(data) ~= "table" then
		return base
	end
	for key, value in base :: any do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

-- Bump older schemas to the current one. Add branches as the schema evolves.
local function migrate(data: Types.PlayerData): Types.PlayerData
	local oldVersion = math.max(1, tonumber(data.schemaVersion) or 1)
	local now = os.time()
	local kitchen = (data :: any).kitchen
	if typeof(kitchen) ~= "table" then
		kitchen = defaultKitchen()
		local mutableData: any = data
		mutableData.kitchen = kitchen
	end
	kitchen.cooks = if typeof(kitchen.cooks) == "table" then kitchen.cooks else {}
	kitchen.stock = if typeof(kitchen.stock) == "table" then kitchen.stock else {}
	kitchen.lots = if typeof(kitchen.lots) == "table" then kitchen.lots else {}
	kitchen.reservations = {}
	kitchen.jobs = if typeof(kitchen.jobs) == "table" then kitchen.jobs else {}
	kitchen.menu = if typeof(kitchen.menu) == "table" then kitchen.menu else {}
	kitchen.targetStock = if typeof(kitchen.targetStock) == "table" then kitchen.targetStock else {}
	kitchen.priorities = if typeof(kitchen.priorities) == "table" then kitchen.priorities else {}
	kitchen.stats = if typeof(kitchen.stats) == "table"
		then kitchen.stats
		else { produced = 0, served = 0, spoiled = 0 }
	kitchen.stats.produced = math.max(0, tonumber(kitchen.stats.produced) or 0)
	kitchen.stats.served = math.max(0, tonumber(kitchen.stats.served) or 0)
	kitchen.stats.spoiled = math.max(0, tonumber(kitchen.stats.spoiled) or 0)
	kitchen.lastActiveAt = tonumber(kitchen.lastActiveAt) or now
	kitchen.nextLotId = math.max(0, tonumber(kitchen.nextLotId) or 0)
	kitchen.nextReservationId = math.max(0, tonumber(kitchen.nextReservationId) or 0)
	kitchen.nextJobId = math.max(0, tonumber(kitchen.nextJobId) or 0)

	local operations = (data :: any).operations
	if typeof(operations) ~= "table" then
		operations = defaultOperations()
		local mutableData: any = data
		mutableData.operations = operations
	end
	operations.satisfaction = math.clamp(
		tonumber(operations.satisfaction) or Operations.startingSatisfaction,
		0,
		Operations.maxSatisfaction
	)
	operations.cleanliness =
		math.clamp(tonumber(operations.cleanliness) or Operations.startingCleanliness, 0, 100)
	operations.staffCapacity = if typeof(operations.staffCapacity) == "table"
		then operations.staffCapacity
		else {}
	for _, role in { "Barista", "Cook", "Waiter", "Cleaner" } do
		operations.staffCapacity[role] = math.clamp(
			tonumber(operations.staffCapacity[role]) or Operations.startingStaffCapacity,
			0,
			Operations.staffCapacityMax
		)
	end
	operations.lastSeenAt = tonumber(operations.lastSeenAt) or now
	operations.lastDirtAt = tonumber(operations.lastDirtAt) or now
	if typeof(operations.lastOffline) ~= "table" then
		operations.lastOffline = nil
	end

	-- Schema 1 stored only a number. Convert it into a fresh timestamped lot so
	-- existing players keep every serving when the perishable system arrives.
	if oldVersion < 2 then
		for recipeId, count in kitchen.stock do
			local recipe = Recipes[recipeId]
			local existing = InventoryMath.count(kitchen, recipeId, now)
			if recipe and typeof(count) == "number" and count > 0 and existing <= 0 then
				InventoryMath.addLot(kitchen, recipeId, count, now, now + recipe.spoilTime)
			end
		end
		local mutableData: any = data
		mutableData.staff = starterStaff()
	end

	local menuCount = 0
	for recipeId, enabled in kitchen.menu do
		if enabled == true and data.unlockedRecipes[recipeId] == true and Recipes[recipeId] then
			menuCount += 1
		else
			kitchen.menu[recipeId] = nil
		end
	end
	local orderedUnlocked = {}
	for recipeId, unlocked in data.unlockedRecipes do
		if unlocked == true and Recipes[recipeId] then
			table.insert(orderedUnlocked, recipeId)
		end
	end
	table.sort(orderedUnlocked, function(a, b)
		local left = Recipes[a]
		local right = Recipes[b]
		if left.requiredLevel == right.requiredLevel then
			return left.displayName < right.displayName
		end
		return left.requiredLevel < right.requiredLevel
	end)
	for _, recipeId in orderedUnlocked do
		if menuCount >= Kitchen.maxMenuSlots then
			break
		end
		if kitchen.menu[recipeId] ~= true then
			kitchen.menu[recipeId] = true
			menuCount += 1
		end
	end
	for recipeId, recipe in Recipes do
		if kitchen.targetStock[recipeId] == nil then
			kitchen.targetStock[recipeId] = math.clamp(
				recipe.productionYield * Kitchen.defaultTargetBatches,
				Kitchen.minTargetStock,
				Kitchen.maxTargetStock
			)
		end
		if kitchen.priorities[recipeId] == nil then
			kitchen.priorities[recipeId] = 1
		end
	end
	data.schemaVersion = SCHEMA_VERSION
	return data
end

local function keyFor(userId: number): string
	return "user_" .. userId
end

-- Returns the profile plus whether it is SAFE TO SAVE.
--
-- The second return is the important one. When a GetAsync never succeeds we
-- hand back a default profile so the player can still play, but that default is
-- NOT their save — it is a blank. Writing it back would destroy a real account
-- on nothing worse than a transient DataStore blip, so the caller marks the
-- user save-blocked for the rest of the session instead.
local function loadAsync(userId: number): (Types.PlayerData, boolean)
	local activeStore = store
	if not activeStore then
		-- No DataStore at all (unpublished place, or API access off). There is
		-- nothing on disk to clobber, so in-memory play is safe.
		return defaultProfile(), true
	end
	local attempts = 0
	while attempts < 3 do
		attempts += 1
		local ok, result = pcall(function()
			return activeStore:GetAsync(keyFor(userId))
		end)
		if ok then
			if result == nil then
				return defaultProfile(), true -- genuinely a first-time player
			end
			return migrate(reconcile(result)), true
		end
		Log.warn("Load attempt", attempts, "failed for", userId, result)
		task.wait(2)
	end
	Log.warn(
		"All load attempts failed for",
		userId,
		"- SAVING DISABLED for this session so the existing save is not overwritten"
	)
	return defaultProfile(), false
end

local function saveAsync(userId: number)
	local activeStore = store
	local data = profiles[userId]
	if not activeStore or not data then
		return
	end
	if saveBlocked[userId] then
		-- We never managed to read this user's real save, so `data` is a blank
		-- default. Writing it would wipe their account.
		return
	end
	local ok, err = pcall(function()
		activeStore:UpdateAsync(keyFor(userId), function()
			return data
		end)
	end)
	if not ok then
		Log.warn("Save failed for", userId, err)
	end
end

function DataService.GetProfile(_self: any, player: Player): Types.PlayerData?
	return profiles[player.UserId]
end

function DataService.IsLoaded(_self: any, player: Player): boolean
	return loaded[player.UserId] == true
end

-- Push the current snapshot to the owning client (call after any mutation).
function DataService.Push(_self: any, player: Player)
	local data = profiles[player.UserId]
	if data then
		Remotes.event("ProfileUpdated"):FireClient(player, data)
	end
end

local function onPlayerAdded(player: Player)
	-- Idempotent: PlayerAdded + the GetPlayers() catch-up loop must not both load.
	if loading[player.UserId] or loaded[player.UserId] then
		return
	end
	loading[player.UserId] = true
	local data, safeToSave = loadAsync(player.UserId)
	-- loadAsync YIELDS — a GetAsync, and up to 3 attempts with 2s waits between
	-- them on failure, so this coroutine can be parked here for seconds. If the
	-- player left while we were away, onPlayerRemoving has ALREADY run and
	-- cleared its tables. Storing the profile now would leave a ghost entry that
	-- no future leave event ever cleans up, and the 60s autosave loop would keep
	-- writing that stale snapshot over their real save for the life of the
	-- server. Drop it instead.
	if player.Parent == nil then
		loading[player.UserId] = nil
		Log.info("Profile load finished after", player.Name, "already left - discarded")
		return
	end
	profiles[player.UserId] = data
	saveBlocked[player.UserId] = not safeToSave
	loaded[player.UserId] = true
	if safeToSave then
		Log.info("Profile ready for", player.Name)
	else
		Log.warn(
			"Profile UNREADABLE for",
			player.Name,
			"- playing on a blank profile, saving is OFF"
		)
	end
	Remotes.event("ProfileUpdated"):FireClient(player, data)
end

local function onPlayerRemoving(player: Player)
	local data = profiles[player.UserId]
	if data and typeof(data.kitchen) == "table" then
		data.kitchen.lastActiveAt = os.time()
	end
	if data and typeof((data :: any).operations) == "table" then
		(data :: any).operations.lastSeenAt = os.time()
	end
	saveAsync(player.UserId)
	profiles[player.UserId] = nil
	loaded[player.UserId] = nil
	loading[player.UserId] = nil
	saveBlocked[player.UserId] = nil
end

function DataService.Init(_self: any)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		Log.info("DataService bound to DataStore:", STORE_NAME)
	else
		store = nil
		Log.warn("DataStore unavailable - running IN-MEMORY (no persistence).", result)
	end

	Remotes.func("RequestProfile").OnServerInvoke = function(player: Player)
		return profiles[player.UserId]
	end
end

function DataService.Start(_self: any)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(Economy.autosaveIntervalSeconds)
			for userId in profiles do
				saveAsync(userId)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for userId in profiles do
			task.spawn(saveAsync, userId)
		end
		task.wait(3)
	end)
end

return DataService
