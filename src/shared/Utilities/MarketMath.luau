--!strict
-- Pure market pricing for bulk ingredient buys. The client calls this to PREVIEW
-- a price and the server calls the SAME function as the authority, so the number
-- the player sees is exactly the number they pay. No services, no DataModel —
-- safe to require anywhere and to unit-test. See docs/GAMEPLAY_DIRECTION.md §2.

local Economy = require(script.Parent.Parent.Config.Economy)
local Ingredients = require(script.Parent.Parent.Config.Ingredients)

local MarketMath = {}

-- How many bulk-discount steps a quantity earns: one per configured tier
-- threshold it meets or exceeds, so a bigger crate is cheaper per unit.
function MarketMath.discountSteps(qty: number): number
	local steps = 0
	for _, tier in Economy.bulkTiers do
		if qty >= tier then
			steps += 1
		end
	end
	return steps
end

-- Per-unit price multiplier after the bulk discount, floored so the market never
-- gives ingredients away no matter how many tiers are added later.
function MarketMath.unitMultiplier(qty: number): number
	local mult = 1 - Economy.bulkDiscountPerTier * MarketMath.discountSteps(qty)
	return math.max(Economy.bulkMinPriceFraction, mult)
end

-- Total coin cost of `qty` units of an ingredient. Returns 0 for an unknown id
-- or a non-positive quantity so callers can reject the request cleanly.
function MarketMath.costFor(ingredientId: string, qty: number): number
	local def = Ingredients[ingredientId]
	if not def or qty <= 0 then
		return 0
	end
	local units = math.floor(qty)
	local raw = def.unitPrice * units * MarketMath.unitMultiplier(units)
	return math.max(1, math.floor(raw + 0.5))
end

return MarketMath
