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
	pass: string?, -- kind == "pass": the perk key ("vip")
}

-- Levels the pantry products top up to.
local RESTOCK_LEVEL = 120
local REFILL_LEVEL = 150

local Products = {
	restockLevel = RESTOCK_LEVEL,
	refillLevel = REFILL_LEVEL,
}

-- VIP Membership perks (docs/MONETISATION.md §C). Convenience + cosmetic ONLY,
-- never exclusive power (rails). Applied server-side, gated on ownedPasses.vip:
-- the offline cap (CafeOperationsService), the session-gift bonus
-- (SessionRewardService), faster walk + the 👑 café-sign badge (CafeService).
Products.vipPerks = {
	walkSpeed = 20, -- a touch above the default 16 — convenience, not power
	giftMultiplier = 1.5, -- +50% on the session/playtime gift (the "daily bonus")
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

-- Game passes (permanent) keyed by Pass ID. (The old Auto-Collect pass was
-- removed 2026-07-26 — auto-collect is now free for everyone via
-- Kitchen.autoCollectCooks, so the pass was a redundant SKU. VIP is the flagship.)
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
}

-- ————— Stock packs (P4, reworked 2026-08-01) —————
--
-- Owner spec: "if a player chooses +5 it will add +5 in every item, ONE TIME
-- only (+5 coffees, +5 teas, etc)". So these are CONSUMABLE restocks, not the
-- permanent yield multiplier this started as — buying one immediately tops every
-- UNLOCKED dish up by `amount`, and buying it again does it again.
--
-- Consumable is why these are Developer Products rather than Game Passes: a Pass
-- can only be bought once, which is wrong for something you are meant to re-buy.
--
-- RAILS: far cleaner than the permanent multiplier it replaces. This is a
-- convenience restock you can also grind for with coins, not a permanent income
-- ceiling, so there is no economy-rebalance debt attached to it.
export type StockPack = {
	amount: number,
	name: string,
	blurb: string,
	icon: string,
	coinCost: number,
	productId: number,
	robuxPrice: number,
}

-- Bulk now actually pays (economy fix #9, docs/ECONOMY_ANALYSIS.md §5.1). Every
-- SKU used to sit in a 5.4-6.7 coins-per-Robux band, so there was no reason to
-- pick the 99 R$ pack over three 29 R$ ones — the bulk tiers were decoration.
-- The Robux PRICES are fixed on the Creator Dashboard, so the AMOUNTS moved
-- instead: +5 / +12 / +24 makes the top pack ~39% more units per Robux than the
-- smallest, which is the ordinary reason a player trades up.
--
-- ⚠️ OWNER ACTION: rename products 3612636928 and 3612637043 on the dashboard to
-- "Stock Pack +12" and "Stock Pack +24". The IDs and prices are unchanged so
-- purchases keep working, but the NATIVE Roblox prompt shows the DASHBOARD name
-- and would otherwise under-promise what the pack actually grants.
Products.stockPacks = {
	{
		amount = 5,
		name = "Stock Pack +5",
		blurb = "Instantly adds 5 of every dish you have unlocked",
		icon = "📦",
		coinCost = 900,
		productId = 3612636850,
		robuxPrice = 29,
	},
	{
		amount = 12,
		name = "Stock Pack +12",
		blurb = "Instantly adds 12 of every dish you have unlocked",
		icon = "🏭",
		coinCost = 1700,
		productId = 3612636928,
		robuxPrice = 59,
	},
	{
		amount = 24,
		name = "Stock Pack +24",
		blurb = "Instantly adds 24 of every dish you have unlocked",
		icon = "🚀",
		coinCost = 3000,
		productId = 3612637043,
		robuxPrice = 99,
	},
}

-- Look a pack up by its Dashboard Product ID (ProcessReceipt's entry point).
function Products.stockPackForProduct(productId: number): StockPack?
	for _, pack in Products.stockPacks do
		if pack.productId == productId then
			return pack
		end
	end
	return nil
end

-- …and by amount, for the coin path (the client sends an amount, never a price).
function Products.stockPackForAmount(amount: number): StockPack?
	for _, pack in Products.stockPacks do
		if pack.amount == amount then
			return pack
		end
	end
	return nil
end

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
}

return Products
