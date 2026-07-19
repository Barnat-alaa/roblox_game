--!strict
-- Server-authoritative continuous production scheduler. Each placed appliance
-- runs one eligible menu recipe at a time until its target stock is covered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Kitchen = require(Shared.Config.Kitchen)
local EconomyConfig = require(Shared.Config.Economy)
local Mastery = require(Shared.Utilities.Mastery)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Remotes = require(Shared.Network.Remotes)
local Log = require(Shared.Utilities.Log)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local ProductionService = {}
ProductionService.Name = "ProductionService"

local DataService: any
local EconomyService: any
local KitchenService: any
local StaffService: any
local AnalyticsService: any

local resumed: { [number]: boolean } = {}
local settingsLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

local function incomingFor(kitchen: Types.KitchenState, recipeId: string): number
	local incoming = 0
	for _, job in kitchen.jobs do
		if job.recipeId == recipeId then
			incoming += math.max(0, tonumber(job.yield) or 0)
		end
	end
	return incoming
end

local function menuCount(kitchen: Types.KitchenState): number
	local count = 0
	for _, enabled in kitchen.menu do
		if enabled == true then
			count += 1
		end
	end
	return count
end

local function chooseRecipe(
	data: Types.PlayerData,
	kitchen: Types.KitchenState,
	applianceId: string,
	now: number
): Types.RecipeDefinition?
	local best: Types.RecipeDefinition? = nil
	local bestScore = -math.huge
	for recipeId, recipe in Recipes do
		if
			recipe.applianceId == applianceId
			and data.unlockedRecipes[recipeId] == true
			and kitchen.menu[recipeId] == true
			and StaffService:HasRole(data, recipe.staffRole)
		then
			local _, available = KitchenService:GetStockCounts(data, recipeId, now)
			local target = math.clamp(
				math.floor(tonumber(kitchen.targetStock[recipeId]) or 0),
				Kitchen.minTargetStock,
				Kitchen.maxTargetStock
			)
			local deficit = target - available - incomingFor(kitchen, recipeId)
			if deficit > 0 then
				local priority =
					math.clamp(math.floor(tonumber(kitchen.priorities[recipeId]) or 1), 1, 3)
				local score = priority * 100 + deficit / math.max(1, target)
				if score > bestScore then
					best = recipe
					bestScore = score
				end
			end
		end
	end
	return best
end

local function startJob(
	player: Player,
	data: Types.PlayerData,
	kitchen: Types.KitchenState,
	instanceId: string,
	recipe: Types.RecipeDefinition,
	now: number
): boolean
	local masteryLevel = KitchenService:MasteryLevel(data, recipe.id)
	local duration =
		Mastery.cookTime(recipe.productionTime, masteryLevel, Kitchen.masteryTimeReductionPerStar)
	duration /= math.max(0.1, StaffService:GetRoleSpeed(data, recipe.staffRole))
	local cost = Mastery.batchCost(
		recipe.ingredientCost * Kitchen.batchCostMultiplier,
		masteryLevel,
		Kitchen.masteryCostReductionPerStar
	)
	if not EconomyService:TrySpendCoins(player, cost) then
		return false
	end
	local quantity =
		Mastery.servings(recipe.productionYield, masteryLevel, Kitchen.masteryBonusServingAt)
	kitchen.nextJobId += 1
	kitchen.jobs[instanceId] = {
		jobId = "job_" .. tostring(kitchen.nextJobId),
		recipeId = recipe.id,
		applianceInstanceId = instanceId,
		startedAt = now,
		completesAt = now + duration,
		duration = duration,
		yield = quantity,
		staffRole = recipe.staffRole,
	}
	KitchenService:UpdateApplianceVisual(
		player,
		instanceId,
		"cooking",
		recipe.displayName .. " AUTO"
	)
	DataService:Push(player)
	if AnalyticsService then
		AnalyticsService:Track(player, "production_started", {
			recipe = recipe.id,
			quantity = quantity,
			cost = cost,
		})
	end
	return true
end

local function completeJobs(player: Player, kitchen: Types.KitchenState, now: number)
	for instanceId, job in kitchen.jobs do
		local recipe = Recipes[job.recipeId]
		if not recipe then
			kitchen.jobs[instanceId] = nil
			KitchenService:UpdateApplianceVisual(player, instanceId, "idle", nil)
		elseif now >= (tonumber(job.completesAt) or now) then
			kitchen.jobs[instanceId] = nil
			KitchenService:CompleteProduction(player, job.recipeId, job.yield, now)
			KitchenService:UpdateApplianceVisual(player, instanceId, "idle", nil)
		else
			local remaining = math.max(0, math.ceil(job.completesAt - now))
			local minutes = math.floor(remaining / 60)
			local seconds = remaining % 60
			local text = if minutes > 0
				then string.format("%s %d:%02d", recipe.displayName, minutes, seconds)
				else string.format("%s %ds", recipe.displayName, seconds)
			KitchenService:UpdateApplianceVisual(player, instanceId, "cooking", text)
		end
	end
end

local function scheduleIdleAppliances(
	player: Player,
	data: Types.PlayerData,
	kitchen: Types.KitchenState,
	now: number
)
	for _, placed in data.placedFurniture do
		local definition = Furniture[placed.catalogId]
		if
			definition
			and definition.cookable == true
			and kitchen.cooks[placed.instanceId] == nil
			and kitchen.jobs[placed.instanceId] == nil
		then
			local recipe = chooseRecipe(data, kitchen, definition.id, now)
			if recipe then
				startJob(player, data, kitchen, placed.instanceId, recipe, now)
			end
		end
	end
end

local function tickPlayer(player: Player)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local now = os.time()
	if not resumed[player.UserId] then
		KitchenService:ResumeAfterOffline(data, now)
		resumed[player.UserId] = true
	end
	local kitchen = KitchenService:GetKitchen(data)
	KitchenService:ExpireStock(player, now)
	completeJobs(player, kitchen, now)
	scheduleIdleAppliances(player, data, kitchen, now)
	KitchenService:TouchActive(data, now)
end

local function handleMenu(player: Player, recipeId: unknown, enabled: unknown)
	if typeof(recipeId) ~= "string" or typeof(enabled) ~= "boolean" then
		return
	end
	if not settingsLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	local recipe = Recipes[recipeId]
	if not data or not recipe or data.unlockedRecipes[recipeId] ~= true then
		return
	end
	local kitchen = KitchenService:GetKitchen(data)
	if
		enabled
		and kitchen.menu[recipeId] ~= true
		and menuCount(kitchen) >= Kitchen.maxMenuSlots
	then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "menu_full" })
		return
	end
	kitchen.menu[recipeId] = enabled
	DataService:Push(player)
end

local function handleTarget(player: Player, recipeId: unknown, target: unknown)
	if typeof(recipeId) ~= "string" or typeof(target) ~= "number" then
		return
	end
	if target ~= target or math.abs(target) > 100000 then
		return
	end
	if not settingsLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data or not Recipes[recipeId] or data.unlockedRecipes[recipeId] ~= true then
		return
	end
	local kitchen = KitchenService:GetKitchen(data)
	kitchen.targetStock[recipeId] =
		math.clamp(math.floor(target), Kitchen.minTargetStock, Kitchen.maxTargetStock)
	DataService:Push(player)
end

local function handlePriority(player: Player, recipeId: unknown, priority: unknown)
	if typeof(recipeId) ~= "string" or typeof(priority) ~= "number" then
		return
	end
	if priority ~= priority or math.abs(priority) > 100000 then
		return
	end
	if not settingsLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data or not Recipes[recipeId] or data.unlockedRecipes[recipeId] ~= true then
		return
	end
	local kitchen = KitchenService:GetKitchen(data)
	kitchen.priorities[recipeId] = math.clamp(math.floor(priority), 1, 3)
	DataService:Push(player)
end

function ProductionService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	KitchenService = ServiceRegistry.get("KitchenService")
	StaffService = ServiceRegistry.get("StaffService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function ProductionService.Start(_self: any)
	Remotes.event("SetMenuRecipe").OnServerEvent:Connect(handleMenu)
	Remotes.event("SetTargetStock").OnServerEvent:Connect(handleTarget)
	Remotes.event("SetProductionPriority").OnServerEvent:Connect(handlePriority)
	task.spawn(function()
		while true do
			task.wait(Kitchen.productionTickSeconds)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) then
					local ok, err = pcall(tickPlayer, player)
					if not ok then
						Log.warn("Production tick failed for", player.Name, err)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		resumed[player.UserId] = nil
		settingsLimiter:clear(player.UserId)
	end)
	Log.info("ProductionService ready (continuous FIFO stock loop)")
end

return ProductionService
