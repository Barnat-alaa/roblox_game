--!strict
-- Weighted reward table for the VIP gift box (docs/GAMEPLAY_DIRECTION.md §3).
-- This is a GIFT box, NOT a loot box: it is earned by play and opened for free —
-- the odds never touch money (HANDOFF §1, Roblox policy). New reward TYPES are
-- new rows: coins/reputation today; furniture / skins / ingredient-crates /
-- boosts / seasonal collectibles slot in later without touching logic (the grant
-- switch in VipService just gains a case).
export type GiftReward = {
	weight: number, -- relative chance among all rows
	kind: string, -- "coins" | "reputation"
	min: number, -- inclusive amount floor
	max: number, -- inclusive amount ceiling
	label: string, -- shown on the open popup / float text
}

local Gifts: { GiftReward } = {
	{ weight = 45, kind = "coins", min = 120, max = 260, label = "Coins" },
	{ weight = 30, kind = "reputation", min = 20, max = 45, label = "Reputation" },
	{ weight = 20, kind = "coins", min = 300, max = 500, label = "Big Coins" },
	{ weight = 5, kind = "coins", min = 700, max = 1000, label = "Jackpot!" },
}

return Gifts
