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
			-- THIRD attempt at this step, and this time it asks for the thing the
			-- game is actually about. It was "brew" (needed a minigame the waiter
			-- reached first), then "menu" (needed the AUTO PRODUCTION tab, which
			-- the owner still could not complete: "i still think the introduction
			-- steps are not doable"). Both were teaching a mechanism.
			--
			-- Serving is the loop. It completes on `customersServed >= 1`, which
			-- ticks whether the player carries the plate themselves OR Noah does
			-- it — so it cannot dead-end on a waiter being faster, and with the
			-- welcome rush a customer is already in the room when this step
			-- appears. The old separate "serve" step is folded into this one;
			-- six steps became five.
			id = "serve",
			text = "🤝 Serve your first customer — carry the plate to their table, or let"
				.. " your waiter do it. Either counts!",
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
