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

	-- ————— Buzz and demand (rebalanced 2026-08-03, docs/ECONOMY_ANALYSIS.md) —————
	--
	-- THE PROBLEM THIS FIXES. Demand used to depend only on Buzz and seats, so a
	-- brand-new café producing 15 servings an hour faced 77 arrivals an hour and
	-- 62 of them stormed out ANGRY, every hour, forever. No amount of correct play
	-- fixed it: even a fully-maxed café (70/hour) still lost 35/hour. The café was
	-- in visible failure from the first minute of a new save to the last.
	--
	-- Demand is now capped at what the kitchen can actually deliver, times a
	-- little headroom, so there is always slightly more custom than you can serve
	-- — pressure, not carnage. Raise `demandHeadroom` to make the game meaner.
	useDemandCap = true,
	demandHeadroom = 1.2,
	-- A café is never completely dead, even with no production plan set: this many
	-- walk-ins per minute still arrive to be served by hand.
	-- 0.35 -> 0.9 on 2026-08-06. Measured against the live formula, a starter café
	-- saw ONE customer every 171 seconds, because the production cap (economy fix
	-- #4) clamps arrivals to what the kitchen can serve and a level-1 Barista makes
	-- 0.25 servings a minute. The café read as deserted for the whole first hour.
	-- 0.9 is one arrival a minute or so, which is a room with someone in it,
	-- without lifting the ceiling that protects the economy.
	spawnRateMinPerMinute = 0.9,

	-- WELCOME RUSH (owner 2026-08-06: "when a player connects make an instant rush
	-- so many clients go to him"). The first `welcomeRushCount` arrivals after a
	-- player joins come every `welcomeRushIntervalSeconds` instead of waiting on
	-- the demand rate, so a café is busy the moment you walk in — and, because
	-- they arrive faster than one can eat and leave, it is the moment a player
	-- discovers they need more chairs.
	welcomeRushCount = 5,
	welcomeRushIntervalSeconds = 3.5,

	buzzStart = 10,
	buzzMax = 105,
	buzzPerFedCustomer = 1,
	buzzPerWalkout = -2,
	-- Buzz DECAYS. Without this it is not a measure of anything: as a pure
	-- accumulator, `served - 2 x walkouts` is positive for any headroom below 2.0,
	-- so every café drifts to the cap and the number stops distinguishing a good
	-- café from a bad one — while at headroom 2.0 half the room storms out and we
	-- are back to the bug above. With a decay term Buzz settles where gains
	-- balance losses, so it becomes a live readout of THROUGHPUT: a bigger, better
	-- run café holds a higher number. Fraction of current Buzz shed per minute.
	buzzDecayPerMinute = 0.009,
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
