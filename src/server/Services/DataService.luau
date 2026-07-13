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
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Network.Remotes)

local SCHEMA_VERSION = 1

-- Environment prefix keeps DEV / STAGING / PROD data strictly separate.
-- TODO: drive this from a per-place attribute during the publish step.
local ENV_PREFIX = "DEV"
local STORE_NAME = ENV_PREFIX .. "_PlayerProfiles_v1"

local DataService = {}
DataService.Name = "DataService"

local store: DataStore? = nil
local profiles: { [number]: Types.PlayerData } = {}
local loaded: { [number]: boolean } = {}
local loading: { [number]: boolean } = {}

local function defaultProfile(): Types.PlayerData
	return {
		schemaVersion = SCHEMA_VERSION,
		coins = Economy.startingCoins,
		level = 1,
		experience = 0,
		reputation = Economy.startingReputation,
		cafeStars = 0,
		inventory = { table_round = 2, chair_wood = 4, plant_small = 1 },
		placedFurniture = {
			{
				instanceId = "seed_coffee",
				catalogId = "coffee_machine",
				gridX = 1,
				gridY = 0,
				floor = 0,
				rotation = 0,
			},
			{
				instanceId = "seed_counter",
				catalogId = "counter",
				gridX = 4,
				gridY = 0,
				floor = 0,
				rotation = 0,
			},
		},
		unlockedRecipes = { espresso = true, tea = true },
		recipeMastery = {},
		staff = {},
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
	-- if data.schemaVersion < 2 then ...transform... end
	data.schemaVersion = SCHEMA_VERSION
	return data
end

local function keyFor(userId: number): string
	return "user_" .. userId
end

local function loadAsync(userId: number): Types.PlayerData
	local activeStore = store
	if not activeStore then
		return defaultProfile()
	end
	local attempts = 0
	while attempts < 3 do
		attempts += 1
		local ok, result = pcall(function()
			return activeStore:GetAsync(keyFor(userId))
		end)
		if ok then
			if result == nil then
				return defaultProfile()
			end
			return migrate(reconcile(result))
		end
		Log.warn("Load attempt", attempts, "failed for", userId, result)
		task.wait(2)
	end
	Log.warn("All load attempts failed for", userId, "- fresh profile (NOT persisted this session)")
	return defaultProfile()
end

local function saveAsync(userId: number)
	local activeStore = store
	local data = profiles[userId]
	if not activeStore or not data then
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
	local data = loadAsync(player.UserId)
	profiles[player.UserId] = data
	loaded[player.UserId] = true
	Log.info("Profile ready for", player.Name)
	Remotes.event("ProfileUpdated"):FireClient(player, data)
end

local function onPlayerRemoving(player: Player)
	saveAsync(player.UserId)
	profiles[player.UserId] = nil
	loaded[player.UserId] = nil
	loading[player.UserId] = nil
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
