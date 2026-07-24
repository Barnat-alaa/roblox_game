--!strict
-- Tunable economy constants. Pure data — safe to require anywhere.
-- See docs/ECONOMY_BALANCE.md for the reasoning behind these numbers.

local Economy = {
	startingCoins = 150,
	startingReputation = 0,

	-- Build limits
	maxPlacedFurniture = 100,

	-- Reward tuning
	tipChancePercent = 25, -- percent chance an order also yields a tip
	tipFraction = 0.20, -- tip = basePrice * tipFraction * customer.tipMultiplier
	manualCookQualityBonus = 0.15, -- +15% of basePrice for a good manual cook
	reputationPerServe = 2,
	xpPerServe = 10,

	-- Staff automation (MVP: one free barista per café)
	staffServeAfterSeconds = 30, -- how long an order waits before the barista steps in
	staffPayoutMultiplier = 0.8, -- the barista keeps a 20% cut of the payout
	staffXpMultiplier = 0.5, -- automated serves grant half XP (manual play stays king)

	-- Save cadence (seconds) — see DataService
	autosaveIntervalSeconds = 60,

	-- Anti-spam: max accepted requests per key per window
	maxRequestsPerWindow = 10,
	rateWindowSeconds = 1,

	-- Market bulk-buy tiers for ingredients (docs/GAMEPLAY_DIRECTION.md §2). The
	-- market never forces tiny purchases; "Max" (buy all you can afford) is
	-- computed client-side. bulkDiscountPerTier makes the bigger crate cheaper
	-- per unit: unit price × (1 - bulkDiscountPerTier × tierIndex), floored at
	-- bulkMinPriceFraction. Server recomputes the total; the client total is
	-- never trusted.
	bulkTiers = { 25, 50, 100, 250 },
	bulkDiscountPerTier = 0.05,
	bulkMinPriceFraction = 0.6,
	maxIngredientBuy = 999, -- server cap on a single bulk order (guards a forged qty)
	-- Inventory warnings (docs/CORE_LOOP_SPEC.md §3b): at or below this many units
	-- an ingredient reads "Low"; at 0 it reads "OUT — buy now".
	lowIngredientThreshold = 5,
}

return Economy
