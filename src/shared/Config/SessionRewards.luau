--!strict
-- Session + playtime reward tuning (owner bug 1, 2026-07-26). A gift is granted
-- the moment a player connects, and another for every `intervalSeconds` of
-- CONNECTED play, with a live countdown pill on the HUD. Pure data;
-- SessionRewardService reads it, RewardMath.rollReward rolls it.
--
-- Rails (HANDOFF §1): EARNED by playing, never paid, no fake urgency — the
-- countdown only ever counts DOWN to something good, and the odds never touch
-- money. The rewards are deliberately modest so they season the loop instead of
-- dwarfing it (the VIP gift box in Config/Gifts is the big one).
local Gifts = require(script.Parent.Gifts)

export type SessionConfig = {
	enabled: boolean,
	intervalSeconds: number, -- connected seconds between playtime gifts
	broadcastSeconds: number, -- how often the server re-sends the countdown target
	rewards: { Gifts.GiftReward }, -- weighted table, same shape as the gift box
}

local SessionRewards: SessionConfig = {
	enabled = true,
	intervalSeconds = 900, -- 15 minutes
	broadcastSeconds = 10, -- covers the join/late-load race + corrects clock drift
	-- Rebalanced 2026-08-03 (economy fix #8, docs/ECONOMY_ANALYSIS.md §4). These
	-- used to average 84.5 coins a gift — 338 an hour for doing nothing, which was
	-- HALF of all lifetime income and effectively 100% of it in the first hour. A
	-- player idling on the plaza earned nearly as much as one running a café well,
	-- which is the wrong lesson for a management game to teach. Now ~27 a gift,
	-- about 110 an hour: roughly 30% of a mid-game café and 14% of a maxed one, so
	-- it seasons the loop instead of being the loop.
	rewards = {
		{ weight = 50, kind = "coins", min = 12, max = 28, label = "Coins" },
		{ weight = 25, kind = "coins", min = 35, max = 60, label = "Coins" },
		{ weight = 20, kind = "reputation", min = 8, max = 18, label = "Reputation" },
		{ weight = 5, kind = "coins", min = 90, max = 130, label = "Big Coins" },
	},
}

return SessionRewards
