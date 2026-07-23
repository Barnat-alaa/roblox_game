--!strict
-- Pure pantry math: does the player hold enough stock to cook a recipe, and
-- the mutation that spends it. No DataModel, no services — safe to unit-test and
-- to require from both the manual-cook path (KitchenService) and the automatic
-- producer (ProductionService) so the two behave identically.
--
-- A recipe with no `ingredients` table needs no stock (coins-only, today's
-- behaviour) — every function treats that as "always available, consumes
-- nothing", so enforcement can be introduced recipe-by-recipe.

local Types = require(script.Parent.Parent.Types)

local IngredientMath = {}

-- True when the pantry covers every ingredient the recipe needs (or the recipe
-- needs none). Missing pantry keys read as 0.
function IngredientMath.has(recipe: Types.RecipeDefinition, pantry: { [string]: number }?): boolean
	local needs = recipe.ingredients
	if needs == nil then
		return true
	end
	local stock = pantry or {}
	for item, qty in needs do
		if (tonumber(stock[item]) or 0) < qty then
			return false
		end
	end
	return true
end

-- The ingredients (and how many) the pantry is short of, for messaging/UI.
-- Empty table means the recipe is fully cookable.
function IngredientMath.shortfall(
	recipe: Types.RecipeDefinition,
	pantry: { [string]: number }?
): { [string]: number }
	local out: { [string]: number } = {}
	local needs = recipe.ingredients
	if needs == nil then
		return out
	end
	local stock = pantry or {}
	for item, qty in needs do
		local have = tonumber(stock[item]) or 0
		if have < qty then
			out[item] = qty - have
		end
	end
	return out
end

-- Subtract the recipe's ingredients from the pantry in place. Assumes has()
-- was checked first; clamps at 0 defensively so a race can never drive stock
-- negative. Returns the same pantry table for chaining.
function IngredientMath.consume(
	recipe: Types.RecipeDefinition,
	pantry: { [string]: number }
): { [string]: number }
	local needs = recipe.ingredients
	if needs == nil then
		return pantry
	end
	for item, qty in needs do
		local left = (tonumber(pantry[item]) or 0) - qty
		pantry[item] = if left > 0 then math.floor(left) else nil
	end
	return pantry
end

return IngredientMath
