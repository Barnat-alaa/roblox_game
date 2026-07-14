--!strict
-- Cook-ahead kitchen + Buzz tuning (Phase 1 of the loop pivot).
-- Ethics rule (§35): being late NEVER punishes — food doesn't spoil; being
-- prompt PAYS (fresh bonus). Buzz rewards keeping counters stocked.
local Kitchen = {
	-- Economy of a batch
	batchCostMultiplier = 3, -- batch ingredients = recipe.ingredientCost * this
	servingPayoutFraction = 0.5, -- coins per consumed serving = basePrice * this
	freshWindowMultiplier = 2, -- collect within cookTime * this → fresh bonus
	freshBonusFraction = 0.15, -- bonus = batch value * this (rounded down)
	xpPerCollect = 10,
	maxStockPerRecipe = 99,

	-- Buzz (0..105): the score on your café sign
	buzzStart = 10,
	buzzMax = 105,
	buzzPerFedCustomer = 1,
	buzzPerWalkout = -2,

	-- Customer flow scales with Buzz: interval lerps base → best
	spawnIntervalBase = 10, -- seconds between customers at Buzz 0
	spawnIntervalBest = 3, -- seconds between customers at max Buzz

	-- Recipe mastery effects (see Utilities/Mastery + tests/Mastery.spec)
	masteryTimeReductionPerStar = 0.05, -- -5% cook time per star (max -20%)
	masteryCostReductionPerStar = 0.05, -- -5% batch cost per star
	masteryBonusServingAt = 2, -- +1 serving from ★★
	masteryFreshBoostAt = 4, -- ★★★★ boosts the fresh bonus…
	masteryFreshMult = 1.5, -- …by 1.5×
}

return Kitchen
