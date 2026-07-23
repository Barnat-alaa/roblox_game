--!strict
-- Run with a TestEZ runner in Studio (see docs/TEST_PLAN.md).
-- Covers the ingredient backbone: the pure pantry math and the data-driven
-- invariant that every recipe's ingredients reference a real palette entry.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local IngredientMath = require(ReplicatedStorage.Shared.Utilities.IngredientMath)
	local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
	local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)

	local function recipeWith(ingredients: { [string]: number }?): any
		return {
			id = "test",
			displayName = "Test",
			category = "Coffee",
			ingredientCost = 1,
			ingredients = ingredients,
			basePrice = 10,
			preparationTime = 1,
			applianceId = "coffee_machine",
			requiredLevel = 1,
			requiredReputation = 0,
			baseQuality = 1,
			masteryThresholds = {},
			cookTime = 1,
			servings = 1,
			productionTime = 1,
			productionYield = 1,
			spoilTime = 1,
			serveTime = 1,
			staffRole = "Barista",
		}
	end

	describe("IngredientMath.has", function()
		it("is always true for a recipe with no ingredients", function()
			expect(IngredientMath.has(recipeWith(nil), {})).to.equal(true)
			expect(IngredientMath.has(recipeWith(nil), nil)).to.equal(true)
		end)

		it("is true when the pantry covers every ingredient", function()
			local recipe = recipeWith({ flour = 2, milk = 1 })
			expect(IngredientMath.has(recipe, { flour = 5, milk = 3 })).to.equal(true)
		end)

		it("is true at exactly the required amount", function()
			local recipe = recipeWith({ flour = 2 })
			expect(IngredientMath.has(recipe, { flour = 2 })).to.equal(true)
		end)

		it("is false when any ingredient is short", function()
			local recipe = recipeWith({ flour = 2, milk = 1 })
			expect(IngredientMath.has(recipe, { flour = 5 })).to.equal(false)
			expect(IngredientMath.has(recipe, { flour = 1, milk = 1 })).to.equal(false)
		end)

		it("treats a nil pantry as empty", function()
			expect(IngredientMath.has(recipeWith({ flour = 1 }), nil)).to.equal(false)
		end)
	end)

	describe("IngredientMath.consume", function()
		it("subtracts each ingredient", function()
			local pantry = { flour = 5, milk = 3 }
			IngredientMath.consume(recipeWith({ flour = 2, milk = 1 }), pantry)
			expect(pantry.flour).to.equal(3)
			expect(pantry.milk).to.equal(2)
		end)

		it("removes an ingredient that hits zero", function()
			local pantry = { flour = 2 }
			IngredientMath.consume(recipeWith({ flour = 2 }), pantry)
			expect(pantry.flour).to.equal(nil)
		end)

		it("never leaves a negative count", function()
			local pantry = { flour = 1 }
			IngredientMath.consume(recipeWith({ flour = 5 }), pantry)
			expect(pantry.flour).to.equal(nil)
		end)

		it("does nothing for a recipe with no ingredients", function()
			local pantry = { flour = 5 }
			IngredientMath.consume(recipeWith(nil), pantry)
			expect(pantry.flour).to.equal(5)
		end)
	end)

	describe("IngredientMath.shortfall", function()
		it("reports only the missing amounts", function()
			local recipe = recipeWith({ flour = 3, milk = 2 })
			local short = IngredientMath.shortfall(recipe, { flour = 1, milk = 2 })
			expect(short.flour).to.equal(2)
			expect(short.milk).to.equal(nil)
		end)

		it("is empty when the recipe is fully cookable", function()
			local short = IngredientMath.shortfall(recipeWith({ flour = 1 }), { flour = 4 })
			expect(next(short)).to.equal(nil)
		end)
	end)

	describe("recipe ↔ ingredient palette integrity", function()
		it("every recipe ingredient exists in the palette", function()
			for recipeId, recipe in Recipes do
				if recipe.ingredients then
					for item, qty in recipe.ingredients do
						if Ingredients[item] == nil then
							error(
								("recipe '%s' references unknown ingredient '%s'"):format(
									recipeId,
									item
								)
							)
						end
						expect(typeof(qty)).to.equal("number")
						expect(qty > 0).to.equal(true)
						expect(math.floor(qty)).to.equal(qty)
					end
				end
			end
		end)
	end)

	describe("ingredient palette sanity", function()
		it("every entry is well-formed", function()
			local rarities = { common = true, uncommon = true, rare = true }
			for id, def in Ingredients do
				expect(def.id).to.equal(id)
				expect(#def.displayName > 0).to.equal(true)
				expect(rarities[def.rarity]).to.equal(true)
				expect(def.unlockLevel >= 1).to.equal(true)
				expect(def.unitPrice > 0).to.equal(true)
			end
		end)
	end)
end
