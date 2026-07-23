--!strict
-- Continuous idle-tycoon kitchen tuning. Perishable lots age only while the
-- owner is online, and the HUD warns before stock expires.
local Kitchen = {
	-- Economy and inventory
	batchCostMultiplier = 3,
	servingPayoutFraction = 0.5,
	freshWindowMultiplier = 2,
	freshBonusFraction = 0.15,
	xpPerCollect = 10,
	maxStockPerRecipe = 99,
	maxMenuSlots = 4,
	defaultTargetBatches = 2,
	minTargetStock = 0,
	maxTargetStock = 48,
	reservationSeconds = 15,
	productionTickSeconds = 1,
	staffLevelSpeedPerLevel = 0.08,
	manualServingShelfLife = 120,

	-- Ingredient system (docs/GAMEPLAY_DIRECTION.md §2). When false, recipes cost
	-- coins only and the pantry is inert stock metadata — today's behaviour. The
	-- backbone (Config/Ingredients, recipe.ingredients, PlayerData.pantry) ships
	-- first with this OFF so the live loop is unchanged; the Market UI + buy remote
	-- land in step 2, then this flips ON to make running dry actually stop a cook.
	enforceIngredients = false,

	-- Buzz and demand
	buzzStart = 10,
	buzzMax = 105,
	buzzPerFedCustomer = 1,
	buzzPerWalkout = -2,
	spawnRateBasePerMinute = 1.2,
	spawnRateBestPerMinute = 2.8,
	spawnRatePerExtraSeat = 0.04,
	spawnRateNoWaiterCap = 1.2,
	spawnRatePerWaiterCap = 2.8,

	-- Recipe mastery
	masteryTimeReductionPerStar = 0.05,
	masteryCostReductionPerStar = 0.05,
	masteryBonusServingAt = 2,
	masteryFreshBoostAt = 4,
	masteryFreshMult = 1.5,
}

return Kitchen
