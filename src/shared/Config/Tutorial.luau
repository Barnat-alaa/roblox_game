--!strict
-- Learn-by-doing onboarding steps, in strict order (master plan §34: no text
-- walls — the player learns by performing meaningful actions). The client
-- detects each condition locally and reports CompleteTutorialStep(index);
-- the server only accepts index == tutorialStep + 1, so steps can never be
-- skipped, replayed, or farmed.
local Tutorial = {
	completionRewardCoins = 25,
	steps = {
		{
			id = "place_furniture",
			text = "👋 Welcome! Tap 🔨 Build and place a table and two chairs.",
		},
		{
			-- Was "brew", and the tutorial DEAD-ENDED here. That step wanted the
			-- timing minigame, which needs a live order — and a waiter serves
			-- orders before the player can reach the machine. Cooking by hand is
			-- no better: the automatic production loop holds a job on the
			-- appliance, so a manual StartCook answers "stove_busy" (measured).
			-- The menu IS the player's real lever over the kitchen in a
			-- cook-ahead game, and it is always available.
			id = "menu",
			text = "☕ Your kitchen cooks on its own. Open 🥫 Pantry (bottom-left) and choose what it makes.",
		},
		{
			id = "serve",
			text = "🤝 When a customer orders, pick the plate up at the kitchen pass and carry it to their table.",
		},
		{
			id = "buy",
			text = "🛒 Open the Shop and buy a decoration.",
		},
		{
			id = "place_decor",
			text = "🎨 Place your new decoration in 🔨 Build — make the café yours.",
		},
		{
			id = "plaza",
			text = "⛲ Walk to the plaza fountain down the street — meet the neighbourhood!",
		},
	},
}

return Tutorial
