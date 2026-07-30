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

-- ————— Production-yield upgrade ladder (P4) —————
--
-- Owner spec (2026-07-30): "×5 to add 5 elements for each item — 5 coffees, 5
-- teas — but only to the items that are unlocked." So this multiplies what a
-- batch YIELDS, not what it sells for, and only for recipes the player has
-- unlocked.
--
-- RAILS: the owner chose PERMANENT tiers, which is only rails-clean because
-- every tier is **also buyable with coins**. Robux skips the grind; it never buys
-- power you cannot earn (HANDOFF §1, docs/MONETISATION.md). The coin prices are
-- deliberately steep so the ladder is a real long-game goal rather than a
-- formality — and so a paying player is ahead by TIME, not by ceiling.
--
-- ⚠️ Economy note: a permanent ×20 yield is a 20× income ceiling. The per-recipe
-- stock cap (Kitchen.maxStockPerRecipe) throttles it in practice, but the coin
-- economy still wants a rebalance pass once this is live — flagged in ROADMAP.
--
-- `productId = 0` means "not created in the Creator Dashboard yet": the coin path
-- works, and the Robux button is simply hidden until a real id is pasted in.
export type YieldTier = {
	tier: number,
	multiplier: number,
	name: string,
	blurb: string,
	icon: string,
	coinCost: number,
	productId: number,
	robuxPrice: number,
}

Products.yieldTiers = {
	{
		tier = 1,
		multiplier = 5,
		name = "Batch Output ×5",
		blurb = "Every batch you make yields 5× the items",
		icon = "📦",
		coinCost = 25000,
		productId = 0, -- paste the Dashboard Product ID here
		robuxPrice = 99,
	},
	{
		tier = 2,
		multiplier = 10,
		name = "Batch Output ×10",
		blurb = "Every batch you make yields 10× the items",
		icon = "🏭",
		coinCost = 120000,
		productId = 0,
		robuxPrice = 199,
	},
	{
		tier = 3,
		multiplier = 20,
		name = "Batch Output ×20",
		blurb = "Every batch you make yields 20× the items",
		icon = "🚀",
		coinCost = 500000,
		productId = 0,
		robuxPrice = 349,
	},
}

-- The multiplier a given tier grants. Tier 0 (or anything unrecognised) is ×1, so
-- an unset/corrupt save simply behaves as an un-upgraded café.
function Products.yieldMultiplier(tier: number?): number
	local t = math.floor(tonumber(tier) or 0)
	local best = 1
	for _, row in Products.yieldTiers do
		if row.tier <= t and row.multiplier > best then
			best = row.multiplier
		end
	end
	return best
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
