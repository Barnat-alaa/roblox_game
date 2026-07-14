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
}

return Economy
