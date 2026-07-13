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

	-- Save cadence (seconds) — see DataService
	autosaveIntervalSeconds = 60,

	-- Anti-spam: max accepted requests per key per window
	maxRequestsPerWindow = 10,
	rateWindowSeconds = 1,
}

return Economy
