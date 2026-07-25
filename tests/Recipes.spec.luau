--!strict
-- Config invariants for the café menu, with a guard on the LIVE per-serving
-- economics so a future edit can never quietly ship a break-even recipe again.
-- (The production-balance pass fixed exactly that: ingredient tables authored
-- per-batch but consumed per-serving by the auto-production plan, which left the
-- cheapest recipes at a 0-coin margin.) See docs/CORE_LOOP_SPEC.md §1.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
	local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
	local Kitchen = require(ReplicatedStorage.Shared.Config.Kitchen)

	-- What one served serving earns: floor(basePrice * servingPayoutFraction).
	-- This is the live payout in KitchenService.servingPayout / settlePlanOffline.
	local function servingRevenue(recipe: any): number
		return math.max(1, math.floor(recipe.basePrice * Kitchen.servingPayoutFraction))
	end

	-- Market value of the per-serving ingredient table at BASE unit price — the
	-- worst case, since bulk buying (MarketMath) only makes it cheaper.
	local function ingredientCostOf(recipe: any): number
		local total = 0
		if recipe.ingredients then
			for id, qty in recipe.ingredients do
				local def = Ingredients[id]
				if def then
					total += def.unitPrice * qty
				end
			end
		end
		return total
	end

	-- Regression thresholds for auto-plan recipes — a floor, NOT the design
	-- target (the pass lands them all at ~42–58% margin).
	local MIN_MARGIN_ABS = 2
	local MIN_MARGIN_FRACTION = 0.35

	describe("recipe cost invariants", function()
		it("every recipe's ingredientCost is positive and below basePrice", function()
			for id, recipe in Recipes do
				if not (recipe.ingredientCost > 0 and recipe.ingredientCost < recipe.basePrice) then
					error(
						("recipe '%s': ingredientCost %d must be > 0 and < basePrice %d"):format(
							id,
							recipe.ingredientCost,
							recipe.basePrice
						)
					)
				end
			end
		end)
	end)

	describe("auto-production per-serving margins", function()
		-- A recipe with productionMinutes is made by the plan, one ingredient
		-- table per single serving. slow_roast (the 8h appointment) has none and
		-- is deliberately excluded — it is cooked as one per-batch job.
		it("every plan recipe declares an ingredient table", function()
			for id, recipe in Recipes do
				if recipe.productionMinutes ~= nil then
					if recipe.ingredients == nil or next(recipe.ingredients) == nil then
						error(
							("plan recipe '%s' has productionMinutes but no ingredients — it would produce free stock"):format(
								id
							)
						)
					end
				end
			end
		end)

		it("every plan recipe nets a healthy per-serving margin", function()
			for id, recipe in Recipes do
				if recipe.productionMinutes ~= nil then
					local revenue = servingRevenue(recipe)
					local cost = ingredientCostOf(recipe)
					local net = revenue - cost
					if net < MIN_MARGIN_ABS or net < MIN_MARGIN_FRACTION * revenue then
						error(
							("recipe '%s': per-serving net %d (rev %d − cost %d) is too thin — need >= %d and >= %d%% of revenue"):format(
								id,
								net,
								revenue,
								cost,
								MIN_MARGIN_ABS,
								math.floor(MIN_MARGIN_FRACTION * 100)
							)
						)
					end
				end
			end
		end)
	end)
end
