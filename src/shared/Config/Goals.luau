--!strict
-- Daily goals + streak tuning (Phase 3b). Three goals roll each UTC day from
-- the pool; each pays coins on completion; finishing all three advances the
-- streak. Trophies at streak milestones are PERMANENT — a missed day restarts
-- the counter but never takes anything away (§35).
local Goals = {
	rewardCoins = { 30, 40, 50 }, -- payout per goal slot (1..3)
	allDoneBonus = 25, -- extra coins when the third goal lands
	trophyMilestones = { 3, 7, 14, 30 }, -- streak days → shelf trophies
	trophyBonusCoins = 100,

	pool = {
		{ id = "serve_customers", text = "Serve %d customers", target = 8 },
		{ id = "collect_batches", text = "Collect %d batches", target = 3 },
		{ id = "earn_coins", text = "Earn %d coins", target = 150 },
		{ id = "collect_tips", text = "Pick up %d tips", target = 2 },
		{ id = "visit_neighbour", text = "Visit %d neighbour café", target = 1 },
	},
}

return Goals
