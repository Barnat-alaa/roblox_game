--!strict
-- Pure payout math shared by the server (OrderService) and the tests
-- (tests/Economy.spec.luau). No player/instance references here on purpose.

local EconomyConfig = require(script.Parent.Parent.Config.Economy)
local Types = require(script.Parent.Parent.Types)

local RewardMath = {}

-- Coins for completing an order, before any tip.
function RewardMath.orderPayout(recipe: Types.RecipeDefinition, manualCook: boolean): number
	local profit = recipe.basePrice - recipe.ingredientCost
	if manualCook then
		profit += math.floor(recipe.basePrice * EconomyConfig.manualCookQualityBonus)
	end
	return math.max(0, profit)
end

-- Tip coins. `roll` is a 1..100 value supplied by the caller (Random on the server,
-- a fixed value in tests) so this stays deterministic and testable.
function RewardMath.tipAmount(recipe: Types.RecipeDefinition, roll: number, tipMultiplier: number): number
	if roll <= EconomyConfig.tipChancePercent then
		return math.floor(recipe.basePrice * EconomyConfig.tipFraction * tipMultiplier)
	end
	return 0
end

return RewardMath
