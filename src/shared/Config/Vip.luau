--!strict
-- VIP customer event tuning (docs/GAMEPLAY_DIRECTION.md §3). A rare "brainrot"
-- celebrity walks the boulevard to the busiest café on the server, pays the owner
-- a premium order, and leaves an EARNED gift box (never a paid random box —
-- HANDOFF §1). Pure data; VipService reads it. Ships behind `enabled`.
local Vip = {
	enabled = true,

	-- P3 (2026-07-30): the VIP is a SCHEDULED SERVER EVENT, not a random drop-in.
	-- The old random 4–8 minute window meant nobody could plan for it and half the
	-- visits went unnoticed. Now every player sees the same countdown on the HUD,
	-- so "the VIP is due in 4 minutes" is something to get your café ready for.
	-- The clock is the SERVER's (workspace:GetServerTimeNow), so every client
	-- agrees; the client only renders what it is told.
	eventIntervalSeconds = 1800, -- 30 minutes between VIP events
	-- Grace after a server boots so the first event does not fire into an empty
	-- street before anyone has built anything.
	firstEventDelaySeconds = 300,
	-- If an event can't run (no café open, a VIP already out, assets not ready),
	-- retry this soon rather than losing the whole 30-minute slot.
	retryDelaySeconds = 60,

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
	--
	-- 2026-07-30 (P3): nearly doubled, 3 → 5.5 (owner: "make the NPC BIGGER"). It
	-- must still clear the door to get inside and sit — World.doorHeight is 7, so
	-- 5.5 leaves 1.5 studs of headroom. Do NOT raise this past ~6 without raising
	-- the door with it, or the VIP will not be able to enter.
	modelHeight = 5.5,
	hipHeight = 2.9,
	rigYOffset = 0,

	bannerText = "✨ A VIP is choosing a café!",
	bannerArrivedText = "⭐ VIP is here!",
}

return Vip
