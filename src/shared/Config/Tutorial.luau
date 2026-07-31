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
			-- 2026-07-31 (owner: "always stuck in step 2/6"). The step was NOT
			-- broken — it was unreachable. The only action that satisfied it was
			-- the AUTO toggle, which lives on the pantry's second tab, and the
			-- text never said so: you opened the pantry, saw a list of stock
			-- numbers, and there was nothing to "choose". Fixed on three fronts —
			-- the text now names the tab, the pantry OPENS on that tab while this
			-- step is active (InventoryController), and tuning a target or
			-- priority now counts too (ProductionService fires `kitchen_tuned`).
			id = "menu",
			text = "☕ Your kitchen cooks on its own. Open 🥫 PANTRY (bottom-left) → the"
				.. " AUTO PRODUCTION tab, and switch a dish ON.",
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
