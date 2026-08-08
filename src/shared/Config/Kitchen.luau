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
	-- 2026-08-06 — THE STARTER KITCHEN COULD NOT FEED A ROOM.
	--
	-- A level-1 Barista worked 15 minutes an hour: 15 servings, 0.25 a minute.
	-- Arrivals are capped at what the kitchen can serve, so the café could never
	-- hold more than a fraction of a person and looked empty at every level
	-- (docs/ECONOMY_ANALYSIS.md §9). Filling four chairs honestly needs about 80
	-- servings an hour — five times what level 1 could make — so no amount of
	-- demand tuning could fix it; only production could.
	--
	-- base 15 → 40 with perLevel 5 → 3 raises the FLOOR of the curve without
	-- lifting its ceiling: level 1 makes 2.7x more, level 10 only 1.12x more
	-- (60 → 67 work-minutes an hour), so the late economy is left as tuned and
	-- the change lands where the problem was.
	workMinutesBase = 40,
	workMinutesPerLevel = 3,

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
	-- 1.2 → 1.3 on 2026-08-06 (owner: keep production "slowly under the
	-- projections"). This is the ONLY knob that sets how far demand runs ahead of
	-- the kitchen — production times change the scale of the café, not the
	-- shortfall, because arrivals are derived from production. At 1.3 roughly a
	-- QUARTER of arrivals cannot be served from stock, so the kitchen is a felt
	-- constraint with three honest answers: level a producer, add an appliance,
	-- or run a Double Shift.
	--
	-- It is deliberately kept modest. The rails forbid manufactured pressure, and
	-- the two free answers must stay ahead of the paid one: levelling a producer
	-- adds 3 work-minutes an hour permanently, where Double Shift doubles them
	-- for sixty minutes. Push this past ~1.4 and the café tips back toward the
	-- permanent-walkout failure §2.6 describes.
	demandHeadroom = 1.3,
	-- A café is never completely dead, even with no production plan set: this many
	-- walk-ins per minute still arrive to be served by hand.
	-- 0.35 -> 0.9 on 2026-08-06. Measured against the live formula, a starter café
	-- saw ONE customer every 171 seconds, because the production cap (economy fix
	-- #4) clamps arrivals to what the kitchen can serve and a level-1 Barista makes
	-- 0.25 servings a minute. The café read as deserted for the whole first hour.
	-- 0.9 is one arrival a minute or so, which is a room with someone in it,
	-- without lifting the ceiling that protects the economy.
	-- 0.35 → 0.9 → 0.8. The 0.9 was a regression: it exceeded what a level-1
	-- kitchen could serve, so 36 customers an hour arrived who could never be fed
	-- and stormed out angry. `GetDemandRate` now also clamps this floor to the
	-- serve capacity, so it can never outrun the kitchen again whatever it is set
	-- to — this number is now a request, not an override.
	spawnRateMinPerMinute = 0.8,

	-- WELCOME RUSH (owner 2026-08-06: "when a player connects make an instant rush
	-- so many clients go to him"). The first `welcomeRushCount` arrivals after a
	-- player joins come every `welcomeRushIntervalSeconds` instead of waiting on
	-- the demand rate, so a café is busy the moment you walk in — and, because
	-- they arrive faster than one can eat and leave, it is the moment a player
	-- discovers they need more chairs.
	welcomeRushCount = 5,
	welcomeRushIntervalSeconds = 3.5,

	-- HOW LONG A VISIT LASTS. Together with the ~12s it takes to walk in, sit and
	-- be served, these make a table occupied for about 150 seconds.
	--
	-- This is the knob that decides whether the café looks BUSY, and it was the
	-- whole problem. Full study 2026-08-06 across all ten stages: a visit lasted
	-- 30s, so the room held 0.5 people at level 1 and 1.2 at level 10 — visibly
	-- EMPTY at every single stage of the game, forever. Arrivals cannot fix that
	-- on their own: they are capped at what the kitchen can serve (economy fix
	-- #4), which tops out near 2.4/minute.
	--
	-- At a 150s visit the same arrivals fill the room instead: 2.2 people at
	-- level 1 rising to 6.0 at level 10 — and because concurrency now scales with
	-- level, CHAIRS finally scale too, from 2 to 6. Four free chairs carry a
	-- player to level 8, after which arrivals start being turned away and the
	-- shortage is real. That is the pressure to furnish, and it arrives on its own.
	--
	-- No economy change: identical servings for identical coins. Only the time a
	-- seat is held moves.
	diningSeconds = 45,
	-- Sitting on after the plate is cleared — the part of a café visit that is not
	-- eating. Kept separate from `diningSeconds` so the eating ANIMATION stays a
	-- sensible length while the visit gets its real duration.
	lingerSeconds = 90,

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
