--!strict
-- The ingredient palette — the raw stock every recipe draws from (see
-- docs/GAMEPLAY_DIRECTION.md §2). Pure data: safe to require anywhere.
--
-- Adding an ingredient is a single row here; recipes reference it by key in
-- Config/Recipes (recipe.ingredients), the market sells it, and the pantry
-- stores it. Nothing about the pantry, market, or cook paths hardcodes an
-- ingredient id — this table is the one source of truth.
--
-- `unitPrice` is the market cost of ONE unit; bulk tiers (Config/Economy.bulkTiers)
-- buy many at a discount. `unlockLevel` gates it in the market with the same
-- locked-blur treatment shop items use. `icon` is an emoji fallback for now —
-- real rendered icons arrive with the Market UI (Kenney Food Kit, see
-- docs/ASSET_LICENSES.md). Amounts/prices/rarities here are a first pass and
-- will be tuned in a balance pass before ingredient enforcement ships.

export type IngredientDefinition = {
	id: string,
	displayName: string,
	icon: string, -- emoji fallback until rendered icons land with the Market UI
	rarity: string, -- "common" | "uncommon" | "rare"
	unlockLevel: number, -- café level at which the market unlocks it
	unitPrice: number, -- coins per single unit at the market
}

local Ingredients: { [string]: IngredientDefinition } = {
	coffee_beans = {
		id = "coffee_beans",
		displayName = "Coffee Beans",
		icon = "🫘",
		rarity = "common",
		unlockLevel = 1,
		unitPrice = 2,
	},
	sugar = {
		id = "sugar",
		displayName = "Sugar",
		icon = "🧂",
		rarity = "common",
		unlockLevel = 1,
		unitPrice = 1,
	},
	tea_leaves = {
		id = "tea_leaves",
		displayName = "Tea Leaves",
		icon = "🍃",
		rarity = "common",
		unlockLevel = 1,
		unitPrice = 2,
	},
	milk = {
		id = "milk",
		displayName = "Milk",
		icon = "🥛",
		rarity = "common",
		unlockLevel = 2,
		unitPrice = 2,
	},
	bread = {
		id = "bread",
		displayName = "Bread",
		icon = "🍞",
		rarity = "common",
		unlockLevel = 2,
		unitPrice = 2,
	},
	cheese = {
		id = "cheese",
		displayName = "Cheese",
		icon = "🧀",
		rarity = "common",
		unlockLevel = 2,
		unitPrice = 3,
	},
	tomato = {
		id = "tomato",
		displayName = "Tomato",
		icon = "🍅",
		rarity = "common",
		unlockLevel = 2,
		unitPrice = 2,
	},
	ham = {
		id = "ham",
		displayName = "Ham",
		icon = "🍖",
		rarity = "common",
		unlockLevel = 2,
		unitPrice = 3,
	},
	flour = {
		id = "flour",
		displayName = "Flour",
		icon = "🌾",
		rarity = "uncommon",
		unlockLevel = 3,
		unitPrice = 2,
	},
	eggs = {
		id = "eggs",
		displayName = "Eggs",
		icon = "🥚",
		rarity = "uncommon",
		unlockLevel = 3,
		unitPrice = 2,
	},
	butter = {
		id = "butter",
		displayName = "Butter",
		icon = "🧈",
		rarity = "uncommon",
		unlockLevel = 3,
		unitPrice = 3,
	},
	berries = {
		id = "berries",
		displayName = "Berries",
		icon = "🫐",
		rarity = "uncommon",
		unlockLevel = 4,
		unitPrice = 3,
	},
	lemon = {
		id = "lemon",
		displayName = "Lemon",
		icon = "🍋",
		rarity = "rare",
		unlockLevel = 5,
		unitPrice = 3,
	},
	chocolate = {
		id = "chocolate",
		displayName = "Chocolate",
		icon = "🍫",
		rarity = "rare",
		unlockLevel = 6,
		unitPrice = 4,
	},
}

return Ingredients
