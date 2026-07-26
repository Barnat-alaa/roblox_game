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
	rewards = {
		{ weight = 50, kind = "coins", min = 40, max = 90, label = "Coins" },
		{ weight = 25, kind = "coins", min = 110, max = 190, label = "Coins" },
		{ weight = 20, kind = "reputation", min = 8, max = 18, label = "Reputation" },
		{ weight = 5, kind = "coins", min = 240, max = 340, label = "Big Coins" },
	},
}

return SessionRewards
