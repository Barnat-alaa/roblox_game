--!strict
-- Server-authoritative continuous production scheduler. Each placed appliance
-- runs one eligible menu recipe at a time until its target stock is covered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Kitchen = require(Shared.Config.Kitchen)
local Operations = require(Shared.Config.Operations)
local EconomyConfig = require(Shared.Config.Economy)
local Mastery = require(Shared.Utilities.Mastery)
local IngredientMath = require(Shared.Utilities.IngredientMath)
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
local CafeOperationsService: any

local resumed: { [number]: boolean } = {}
local settingsLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

-- Runtime, per-user, per-role hour tracker for the plan model (CORE_LOOP_SPEC §4).
-- Not persisted: an hour's work-minute budget resets each real hour and on rejoin.
type PlanHour = { hourStart: number, minutesUsed: number, produced: { [string]: number } }
local planHours: { [number]: { [string]: PlanHour } } = {}

local function roleHour(userId: number, role: string, now: number): PlanHour
	local byUser = planHours[userId]
	if not byUser then
		byUser = {}
		planHours[userId] = byUser
	end
	local h = byUser[role]
	if not h or now - h.hourStart >= 3600 then
		h = { hourStart = now, minutesUsed = 0, produced = {} }
		byUser[role] = h
	end
	return h
end

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
			and (not Kitchen.enforceIngredients or IngredientMath.has(recipe, data.pantry))
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
	local capacityCost = duration / 60 * Operations.productionCapacityPerWorkMinute
	if not CafeOperationsService:CanUseCapacity(player, recipe.staffRole, capacityCost) then
		KitchenService:UpdateApplianceVisual(
			player,
			instanceId,
			"resting",
			recipe.staffRole .. " shift empty - owner needed"
		)
		return false
	end
	-- Pantry gate for automatic jobs: on a shortfall the appliance idles to
	-- "resting" rather than firing a Notify — this scheduler ticks every second,
	-- so a toast would spam. Dormant until Kitchen.enforceIngredients.
	if Kitchen.enforceIngredients and not IngredientMath.has(recipe, data.pantry) then
		KitchenService:UpdateApplianceVisual(
			player,
			instanceId,
			"resting",
			"Out of ingredients - restock at the market"
		)
		return false
	end
	local cost = Mastery.batchCost(
		recipe.ingredientCost * Kitchen.batchCostMultiplier,
		masteryLevel,
		Kitchen.masteryCostReductionPerStar
	)
	if not EconomyService:TrySpendCoins(player, cost) then
		return false
	end
	if not CafeOperationsService:TryUseCapacity(player, recipe.staffRole, capacityCost) then
		-- Capacity is server-owned and this path is single-threaded per appliance;
		-- this is a defensive guard for future parallel schedulers.
		return false
	end
	-- All spends have succeeded; now (and only now) draw the ingredients down, so
	-- a failed coin/capacity spend above can never leak pantry stock.
	if Kitchen.enforceIngredients then
		IngredientMath.consume(recipe, data.pantry)
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

-- Plan model (CORE_LOOP_SPEC §4): pick the next serving this machine should make
-- from the player's productionPlan — the recipe with the most remaining hourly
-- quota that still fits the role's work-minute budget, has ingredients in the
-- pantry, and has counter room. Returns the recipe + the role that makes it.
local function chooseFromPlan(
	player: Player,
	data: Types.PlayerData,
	kitchen: Types.KitchenState,
	machineId: string,
	now: number
): (Types.RecipeDefinition?, string?)
	local plan = data.productionPlan or {}
	local best: Types.RecipeDefinition? = nil
	local bestRole: string? = nil
	local bestRemaining = 0
	for recipeId, recipe in Recipes do
		local minutes = tonumber(recipe.productionMinutes)
		if
			recipe.applianceId == machineId
			and minutes ~= nil
			and data.unlockedRecipes[recipeId] == true
			and kitchen.menu[recipeId] == true
			and StaffService:HasRole(data, recipe.staffRole)
		then
			local role = recipe.staffRole
			local rolePlan = plan[role]
			local target = if typeof(rolePlan) == "table"
				then math.floor(tonumber(rolePlan[recipeId]) or 0)
				else 0
			if target > 0 then
				local h = roleHour(player.UserId, role, now)
				local made = h.produced[recipeId] or 0
				local workLeft = StaffService:GetWorkMinutesPerHour(data, role) - h.minutesUsed
				local _, available = KitchenService:GetStockCounts(data, recipeId, now)
				local room = Kitchen.maxStockPerRecipe - available - incomingFor(kitchen, recipeId)
				local remaining = target - made
				if
					remaining > bestRemaining
					and (minutes :: number) <= workLeft + 0.001
					and room >= 1
					and IngredientMath.has(recipe, data.pantry)
				then
					best = recipe
					bestRole = role
					bestRemaining = remaining
				end
			end
		end
	end
	return best, bestRole
end

-- Start one plan serving: consumes the ingredients + the role's work-minutes, and
-- cooks for productionMinutes (no coin charge — ingredients were bought at market).
local function startPlanJob(
	player: Player,
	data: Types.PlayerData,
	kitchen: Types.KitchenState,
	instanceId: string,
	recipe: Types.RecipeDefinition,
	role: string,
	now: number
)
	local minutes = tonumber(recipe.productionMinutes) or 1
	IngredientMath.consume(recipe, data.pantry)
	local h = roleHour(player.UserId, role, now)
	h.minutesUsed += minutes
	h.produced[recipe.id] = (h.produced[recipe.id] or 0) + 1
	kitchen.nextJobId += 1
	kitchen.jobs[instanceId] = {
		jobId = "job_" .. tostring(kitchen.nextJobId),
		recipeId = recipe.id,
		applianceInstanceId = instanceId,
		startedAt = now,
		completesAt = now + minutes * 60,
		duration = minutes * 60,
		yield = 1,
		staffRole = role,
	}
	KitchenService:UpdateApplianceVisual(
		player,
		instanceId,
		"cooking",
		recipe.displayName .. " AUTO"
	)
	DataService:Push(player)
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
			if Kitchen.useProductionPlan then
				local recipe, role = chooseFromPlan(player, data, kitchen, definition.id, now)
				if recipe and role then
					startPlanJob(player, data, kitchen, placed.instanceId, recipe, role, now)
				else
					KitchenService:UpdateApplianceVisual(player, placed.instanceId, "resting", nil)
				end
			else
				local recipe = chooseRecipe(data, kitchen, definition.id, now)
				if recipe then
					startJob(player, data, kitchen, placed.instanceId, recipe, now)
				end
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
		CafeOperationsService:ResumeAfterOffline(player, now)
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
	-- Lets the tutorial see that the player actually worked the menu. There is
	-- no other reliable signal: the appliances are driven by the automatic
	-- production loop, so "did they cook something" cannot be attributed to the
	-- player at all.
	Remotes.event("Notify"):FireClient(player, { kind = "menu_changed", recipe = recipeId })
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

-- Set how many of one recipe a staff role makes per hour (the plan editor). The
-- server rejects a plan that would exceed the role's work-minute budget.
local function handleSetPlan(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: any
	if
		typeof(p.role) ~= "string"
		or typeof(p.recipeId) ~= "string"
		or typeof(p.delta) ~= "number"
	then
		return
	end
	if p.delta ~= p.delta or math.abs(p.delta) > 100000 then
		return
	end
	if not settingsLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	local recipe = Recipes[p.recipeId]
	if
		not data
		or not recipe
		or recipe.productionMinutes == nil
		or recipe.staffRole ~= p.role
		or data.unlockedRecipes[p.recipeId] ~= true
	then
		return
	end
	local minutes = recipe.productionMinutes :: number
	if typeof(data.productionPlan) ~= "table" then
		(data :: any).productionPlan = {}
	end
	if typeof(data.productionPlan[p.role]) ~= "table" then
		data.productionPlan[p.role] = {}
	end
	-- Delta (not absolute) so rapid +/- taps accumulate instead of collapsing to a
	-- single step (each FireServer reads the already-updated plan on the server).
	local current = math.floor(tonumber(data.productionPlan[p.role][p.recipeId]) or 0)
	local count = math.clamp(current + math.floor(p.delta), 0, 500)
	local budget = StaffService:GetWorkMinutesPerHour(data, p.role)
	local usedByOthers = 0
	for rid, c in data.productionPlan[p.role] do
		if rid ~= p.recipeId then
			local r = Recipes[rid]
			if r and r.productionMinutes then
				usedByOthers += (tonumber(c) or 0) * (r.productionMinutes :: number)
			end
		end
	end
	if usedByOthers + count * minutes > budget + 0.001 then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "plan_full" })
		return
	end
	data.productionPlan[p.role][p.recipeId] = count
	-- Keep the customer-facing menu in sync: a recipe is orderable iff the plan
	-- makes it — otherwise the plan produces stock no customer can buy.
	local kitchen = KitchenService:GetKitchen(data)
	kitchen.menu[p.recipeId] = count > 0
	DataService:Push(player)
	Remotes.event("Notify"):FireClient(player, {
		kind = "plan_changed",
		recipe = p.recipeId,
		count = count,
	})
end

function ProductionService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	KitchenService = ServiceRegistry.get("KitchenService")
	StaffService = ServiceRegistry.get("StaffService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	CafeOperationsService = ServiceRegistry.get("CafeOperationsService")
end

function ProductionService.Start(_self: any)
	Remotes.event("SetMenuRecipe").OnServerEvent:Connect(handleMenu)
	Remotes.event("SetTargetStock").OnServerEvent:Connect(handleTarget)
	Remotes.event("SetProductionPriority").OnServerEvent:Connect(handlePriority)
	Remotes.event("SetProductionPlan").OnServerEvent:Connect(handleSetPlan)
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
		planHours[player.UserId] = nil
		settingsLimiter:clear(player.UserId)
	end)
	Log.info("ProductionService ready (continuous FIFO stock loop)")
end

return ProductionService
