--!strict
-- Shared automatic-economy forecast, used by the production menu and the server
-- settlement. It exposes the real bottleneck: producer output versus the
-- waiter's shared serving capacity.
--
-- REWRITTEN 2026-08-03 (economy fix #1, docs/ECONOMY_ANALYSIS.md §2.1/§2.2).
-- This file used to model `machines x productionYield x 60 / productionTime`,
-- which is the LEGACY scheduler — disabled since `Kitchen.useProductionPlan`
-- went true. The live path (`ProductionService.startPlanJob`) makes ONE serving
-- per job, costs `recipe.productionMinutes` out of the role's hourly
-- work-minute budget, and charges no coins. Forecasting the dead path
-- overstated output by 12x (Espresso) to 32x (Quiche), and the ingredient line
-- multiplied a PER-SERVING cost by `batchCostMultiplier` and then divided by
-- yield, understating it by up to 62%. The menu was telling players a number
-- roughly an order of magnitude wrong, always optimistically.
--
-- The real model, in full:
--     work-minutes per hour = workMinutesBase + (roleLevel - 1) * workMinutesPerLevel
--     one serving           = recipe.productionMinutes of that budget
--     the production PLAN   = how the player allocates it across recipes
-- so a role's recipes compete for one shared hourly budget. That sharing is the
-- single biggest thing the old forecast missed: it reported every recipe as if
-- it had the whole kitchen to itself.

local Kitchen = require(script.Parent.Parent.Config.Kitchen)

local OperationsMath = {}

local function staffInfo(
	data: any,
	staffDefinitions: any,
	role: string,
	speedPerLevel: number
): (number, number, number)
	local count = 0
	local bestSpeed = 0
	local bestLevel = 0
	for _, member in data.staff or {} do
		local definition = staffDefinitions[member.typeId]
		if definition and definition.role == role then
			count += 1
			local level = math.max(1, math.floor(tonumber(member.level) or 1))
			bestLevel = math.max(bestLevel, level)
			bestSpeed =
				math.max(bestSpeed, definition.baseSpeed * (1 + (level - 1) * speedPerLevel))
		end
	end
	return count, bestSpeed, bestLevel
end

local function placedCatalogIds(data: any): { [string]: boolean }
	local placed: { [string]: boolean } = {}
	for _, item in data.placedFurniture or {} do
		placed[item.catalogId] = true
	end
	return placed
end

-- Servings per hour of each recipe the plan will really deliver. Walks the
-- recipes in a stable order and spends the role's budget down, so a plan that
-- asks for more than the shift can cover is trimmed the same way the server
-- trims it rather than reported in full.
local function plannedPerHour(
	data: any,
	recipes: any,
	staffDefinitions: any,
	speedPerLevel: number
): { [string]: number }
	local out: { [string]: number } = {}
	local plan = if typeof(data.productionPlan) == "table" then data.productionPlan else {}
	local kitchen = if typeof(data.kitchen) == "table" then data.kitchen else {}
	local menu = if typeof(kitchen.menu) == "table" then kitchen.menu else {}
	local unlocked = if typeof(data.unlockedRecipes) == "table" then data.unlockedRecipes else {}
	local placed = placedCatalogIds(data)

	for role, byRecipe in plan do
		if typeof(byRecipe) == "table" then
			local count, _, level = staffInfo(data, staffDefinitions, role, speedPerLevel)
			if count > 0 then
				local budget = Kitchen.workMinutesBase
					+ (math.max(1, level) - 1) * Kitchen.workMinutesPerLevel
				local used = 0
				local ids = {}
				for recipeId in byRecipe do
					table.insert(ids, recipeId)
				end
				table.sort(ids)
				for _, recipeId in ids do
					local recipe = recipes[recipeId]
					local minutes = recipe and tonumber(recipe.productionMinutes)
					if
						minutes
						and minutes > 0
						and unlocked[recipeId] == true
						and menu[recipeId] == true
						and placed[recipe.applianceId] == true
					then
						local wanted = math.max(0, math.floor(tonumber(byRecipe[recipeId]) or 0))
						local room = math.max(0, math.floor((budget - used) / minutes))
						local made = math.min(wanted, room)
						if made > 0 then
							used += made * minutes
							out[recipeId] = (out[recipeId] or 0) + made
						end
					end
				end
			end
		end
	end
	return out
end

function OperationsMath.calculate(
	data: any,
	recipes: any,
	staffDefinitions: any,
	staffLevelSpeedPerLevel: number,
	_batchCostMultiplier: number, -- kept for call-site compatibility; the plan
	-- model charges no coins per batch, so batch cost no longer enters the
	-- forecast. Ingredients are bought at the market and drawn one table per
	-- serving, which `recipe.ingredientCost` already expresses per serving.
	servingPayoutFraction: number,
	offlineDivisor: number
): any
	local result = {
		products = {},
		productionPerMinute = 0,
		throughputPerMinute = 0,
		grossPerMinute = 0,
		netPerMinute = 0,
		offlineNetPerMinute = 0,
		waiterUtilization = 0,
	}
	if typeof(data) ~= "table" then
		return result
	end

	local perHour = plannedPerHour(data, recipes, staffDefinitions, staffLevelSpeedPerLevel)
	local waiterCount, waiterSpeed =
		staffInfo(data, staffDefinitions, "Waiter", staffLevelSpeedPerLevel)

	local serviceWork = 0
	for recipeId, servingsPerHour in perHour do
		local recipe = recipes[recipeId]
		local productionRate = servingsPerHour / 60
		local individualServiceRate = if waiterCount > 0 and waiterSpeed > 0
			then waiterCount * waiterSpeed * 60 / recipe.serveTime
			else 0
		local requiredWork = if waiterSpeed > 0
			then productionRate * recipe.serveTime / (60 * waiterSpeed)
			else 0
		serviceWork += requiredWork
		result.products[recipeId] = {
			productionPerMinute = productionRate,
			serviceCapacityPerMinute = individualServiceRate,
			requiredServiceWork = requiredWork,
			payoutPerServing = math.max(1, math.floor(recipe.basePrice * servingPayoutFraction)),
			-- Per SERVING, straight from the recipe — one ingredient table is
			-- drawn per serving the plan makes.
			ingredientPerServing = recipe.ingredientCost,
		}
		result.productionPerMinute += productionRate
	end

	local serviceScale = if serviceWork > 0 then math.min(1, waiterCount / serviceWork) else 0
	result.waiterUtilization = if waiterCount > 0 then math.min(1, serviceWork / waiterCount) else 0
	for _, product in result.products do
		local throughput = product.productionPerMinute * serviceScale
		local gross = throughput * product.payoutPerServing
		local net = throughput
			* math.max(0, product.payoutPerServing - product.ingredientPerServing)
		product.throughputPerMinute = throughput
		product.grossPerMinute = gross
		product.netPerMinute = net
		product.offlineNetPerMinute = net / math.max(1, offlineDivisor)
		product.bottleneck = if product.productionPerMinute <= 0
			then "STOPPED"
			elseif product.serviceCapacityPerMinute <= 0 or serviceScale < 0.999 then "SERVER"
			else "PRODUCTION"
		result.throughputPerMinute += throughput
		result.grossPerMinute += gross
		result.netPerMinute += net
	end
	result.offlineNetPerMinute = result.netPerMinute / math.max(1, offlineDivisor)
	return result
end

return OperationsMath
