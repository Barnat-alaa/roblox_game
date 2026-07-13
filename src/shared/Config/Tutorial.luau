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
			id = "brew",
			text = "☕ When an order arrives, walk to your coffee machine, press E and stop the bar in the green!",
		},
		{
			id = "serve",
			text = "🤝 Tap the green Serve button to deliver the order.",
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
