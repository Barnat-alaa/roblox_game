--!strict
-- Robux catalogue (docs/MONETISATION.md). Maps each real product/pass id to its
-- server-side reward + the card display. Grant amounts live here, never sent by
-- the client. Rails: every SKU is also earnable with coins/levels in-game.
--
-- IDs are the owner's real Creator-Dashboard products (dev products consumable,
-- passes permanent). `price` is the Robux price for the CARD only — Roblox owns
-- the real charge; the card just triggers the native purchase prompt.

export type ProductInfo = {
	id: number,
	key: string,
	name: string,
	price: number, -- Robux, for the card label
	blurb: string,
	icon: string, -- emoji glyph on our card (the native prompt shows the real art)
	kind: string, -- bundle | refill_all | restock_low | boost | hire_all | pass
	ingredients: { [string]: number }?, -- kind == "bundle"
	boost: string?, -- kind == "boost": "coins" | "reputation"
	seconds: number?, -- kind == "boost": duration
	pass: string?, -- kind == "pass": the perk key ("vip" | "auto_collect")
}

-- Levels the pantry products top up to.
local RESTOCK_LEVEL = 120
local REFILL_LEVEL = 150

local Products = {
	restockLevel = RESTOCK_LEVEL,
	refillLevel = REFILL_LEVEL,
}

-- Developer products (consumable, repeatable) keyed by Product ID.
Products.developerProducts = {
	[3611621378] = {
		id = 3611621378,
		key = "emergency_restock",
		name = "Emergency Restock",
		price = 25,
		blurb = "Top every low ingredient back up",
		icon = "🧺",
		kind = "restock_low",
	},
	[3611621443] = {
		id = 3611621443,
		key = "barista_restock",
		name = "Barista Restock",
		price = 49,
		blurb = "A big bundle of coffee & tea ingredients",
		icon = "☕",
		kind = "bundle",
		ingredients = { coffee_beans = 250, milk = 150, sugar = 200, tea_leaves = 150 },
	},
	[3611621506] = {
		id = 3611621506,
		key = "kitchen_restock",
		name = "Kitchen Restock",
		price = 49,
		blurb = "A big bundle of baking & food ingredients",
		icon = "🥐",
		kind = "bundle",
		ingredients = {
			flour = 200,
			eggs = 150,
			butter = 120,
			bread = 120,
			cheese = 120,
			tomato = 120,
			ham = 120,
			berries = 100,
			lemon = 100,
			chocolate = 100,
		},
	},
	[3611621570] = {
		id = 3611621570,
		key = "full_pantry_refill",
		name = "Full Pantry Refill",
		price = 99,
		blurb = "Top up every ingredient at once",
		icon = "📦",
		kind = "refill_all",
	},
	[3611623096] = {
		id = 3611623096,
		key = "double_coins",
		name = "Double Coins — 1 Hour",
		price = 59,
		blurb = "2× all coin income for 60 minutes",
		icon = "💰",
		kind = "boost",
		boost = "coins",
		seconds = 3600,
	},
	[3611623160] = {
		id = 3611623160,
		key = "double_rep",
		name = "Double Reputation — 1 Hour",
		price = 59,
		blurb = "2× reputation for 60 minutes",
		icon = "⭐",
		kind = "boost",
		boost = "reputation",
		seconds = 3600,
	},
	[3611623208] = {
		id = 3611623208,
		key = "hire_full_crew",
		name = "Hire Full Crew",
		price = 149,
		blurb = "Instantly hire all your locked staff",
		icon = "👥",
		kind = "hire_all",
	},
}

-- Game passes (permanent) keyed by Pass ID.
Products.passes = {
	[1928898980] = {
		id = 1928898980,
		key = "vip",
		name = "VIP Membership",
		price = 399,
		blurb = "Daily bonus · 12h offline · faster walk · VIP badge",
		icon = "👑",
		kind = "pass",
		pass = "vip",
	},
	[1928521004] = {
		id = 1928521004,
		key = "auto_collect",
		name = "Auto-Collect",
		price = 149,
		blurb = "Finished batches drop straight to the counter",
		icon = "🅰️",
		kind = "pass",
		pass = "auto_collect",
	},
}

-- Display order for the shop (dev products first, then passes).
Products.order = {
	{ id = 3611623208, pass = false },
	{ id = 3611621570, pass = false },
	{ id = 3611621443, pass = false },
	{ id = 3611621506, pass = false },
	{ id = 3611621378, pass = false },
	{ id = 3611623096, pass = false },
	{ id = 3611623160, pass = false },
	{ id = 1928898980, pass = true },
	{ id = 1928521004, pass = true },
}

return Products
