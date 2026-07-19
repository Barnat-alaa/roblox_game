--!strict
-- Shared automatic-economy calculator used by both the server settlement and
-- the production menu. It exposes the real bottleneck: producer output versus
-- the waiter's shared serving capacity.

local OperationsMath = {}

local function staffInfo(
	data: any,
	staffDefinitions: any,
	role: string,
	speedPerLevel: number
): (number, number)
	local count = 0
	local bestSpeed = 0
	for _, member in data.staff or {} do
		local definition = staffDefinitions[member.typeId]
		if definition and definition.role == role then
			count += 1
			local level = math.max(1, math.floor(tonumber(member.level) or 1))
			bestSpeed =
				math.max(bestSpeed, definition.baseSpeed * (1 + (level - 1) * speedPerLevel))
		end
	end
	return count, bestSpeed
end

local function applianceCounts(data: any): { [string]: number }
	local counts: { [string]: number } = {}
	for _, placed in data.placedFurniture or {} do
		counts[placed.catalogId] = (counts[placed.catalogId] or 0) + 1
	end
	return counts
end

function OperationsMath.calculate(
	data: any,
	recipes: any,
	staffDefinitions: any,
	staffLevelSpeedPerLevel: number,
	batchCostMultiplier: number,
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

	local kitchen = if typeof(data.kitchen) == "table" then data.kitchen else {}
	local menu = if typeof(kitchen.menu) == "table" then kitchen.menu else {}
	local priorities = if typeof(kitchen.priorities) == "table" then kitchen.priorities else {}
	local applianceCount = applianceCounts(data)
	local priorityByAppliance: { [string]: number } = {}
	for recipeId, recipe in recipes do
		if menu[recipeId] == true and (data.unlockedRecipes or {})[recipeId] == true then
			priorityByAppliance[recipe.applianceId] = (priorityByAppliance[recipe.applianceId] or 0)
				+ math.clamp(math.floor(tonumber(priorities[recipeId]) or 1), 1, 3)
		end
	end

	local waiterCount, waiterSpeed =
		staffInfo(data, staffDefinitions, "Waiter", staffLevelSpeedPerLevel)
	local serviceWork = 0
	for recipeId, recipe in recipes do
		if menu[recipeId] == true and (data.unlockedRecipes or {})[recipeId] == true then
			local producerCount, producerSpeed =
				staffInfo(data, staffDefinitions, recipe.staffRole, staffLevelSpeedPerLevel)
			local machines = applianceCount[recipe.applianceId] or 0
			local priority = math.clamp(math.floor(tonumber(priorities[recipeId]) or 1), 1, 3)
			local share = priority
				/ math.max(1, priorityByAppliance[recipe.applianceId] or priority)
			local productionRate = if producerCount > 0 and producerSpeed > 0
				then machines
					* recipe.productionYield
					* 60
					/ (recipe.productionTime / producerSpeed)
					* share
				else 0
			local individualServiceRate = if waiterCount > 0 and waiterSpeed > 0
				then waiterCount * waiterSpeed * 60 / recipe.serveTime
				else 0
			local requiredWork = if waiterSpeed > 0
				then productionRate * recipe.serveTime / (60 * waiterSpeed)
				else 0
			serviceWork += requiredWork
			local payout = math.max(1, math.floor(recipe.basePrice * servingPayoutFraction))
			local ingredientPerServing = recipe.ingredientCost
				* batchCostMultiplier
				/ math.max(1, recipe.productionYield)
			result.products[recipeId] = {
				productionPerMinute = productionRate,
				serviceCapacityPerMinute = individualServiceRate,
				requiredServiceWork = requiredWork,
				payoutPerServing = payout,
				ingredientPerServing = ingredientPerServing,
			}
			result.productionPerMinute += productionRate
		end
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
