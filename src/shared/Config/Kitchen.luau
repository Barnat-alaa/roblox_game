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
	enforceIngredients = true,

	-- New auto-production model (docs/CORE_LOOP_SPEC.md §4). Each producer staff
	-- works `workMinutesBase + (level-1)*workMinutesPerLevel` minutes per hour
	-- (Barista Lv1 = 15 → Lv10 = 60) and the player allocates those minutes across
	-- products via `PlayerData.productionPlan`. Ships OFF: while false the old
	-- target-stock/priority scheduler runs unchanged. The scheduler logic lands
	-- behind this flag, then it flips on together with enforceIngredients.
	useProductionPlan = true,
	workMinutesBase = 15,
	workMinutesPerLevel = 5,

	-- Auto-collect finished MANUAL cooks straight into stock the moment their
	-- timer ends, instead of waiting for the player to press Collect (owner
	-- request 2026-07-26 — "make it automatic"). The 1s kitchen tick performs the
	-- collect, so it is always prompt and the fresh bonus always lands. Set false
	-- to restore the press-to-collect ritual.
	autoCollectCooks = true,

	-- Finished-food display: instead of piling every dish on the service counter,
	-- show one wall shelf per UNLOCKED recipe — a permanent food prop + a live
	-- "xN" count — on the wall opposite the front kitchen. New shelves appear as
	-- recipes unlock. Set false to fall back to the counter pile.
	useFoodShelves = true,

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
