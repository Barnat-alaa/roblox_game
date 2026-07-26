--!strict
-- VIP customer event tuning (docs/GAMEPLAY_DIRECTION.md §3). A rare "brainrot"
-- celebrity walks the boulevard to the busiest café on the server, pays the owner
-- a premium order, and leaves an EARNED gift box (never a paid random box —
-- HANDOFF §1). Pure data; VipService reads it. Ships behind `enabled`.
local Vip = {
	enabled = true,

	-- Spawn cadence: one VIP attempt every [min,max] seconds. If no café is open
	-- the attempt is skipped and the timer restarts. Only one VIP exists at a time.
	spawnIntervalMinSeconds = 240,
	spawnIntervalMaxSeconds = 480,

	walkSpeed = 10, -- struts a touch faster than the ambient crowd
	lingerSeconds = 6, -- pause at the entrance ("placing the premium order")
	leaveAfterSeconds = 4, -- stroll-off time before despawn

	-- The premium order paid to the winning café's owner when the VIP eats: it
	-- orders the fanciest UNLOCKED dish and pays basePrice × premiumMultiplier
	-- (premiumCoins is the fallback if no dish resolves). Served instantly.
	premiumCoins = 120,
	premiumReputation = 15,
	premiumMultiplier = 4,
	insideDepth = 12, -- studs inside the door where the VIP stops to order + eat

	giftDespawnSeconds = 180, -- gift box auto-cleans if left unopened

	-- Café scoring: score = buzz * buzzWeight (widen with more factors later).
	-- Highest wins; ties break to the lowest plot index. Must be OPEN (claimed).
	buzzWeight = 1.0,

	-- Brainrot presentation (VipService welds the model onto an invisible
	-- Humanoid). Tune by eye in a playtest — these only affect how it sits/scales.
	-- modelHeight must match AssetManifest.vip.height; hipHeight ≈ half of it puts
	-- the model's feet on the ground, and rigYOffset nudges it up/down from there.
	modelHeight = 3, -- small enough to walk through the 6-stud door and eat inside
	hipHeight = 1.6,
	rigYOffset = 0,

	bannerText = "✨ A VIP is choosing a café!",
	bannerArrivedText = "⭐ VIP is here!",
}

return Vip
