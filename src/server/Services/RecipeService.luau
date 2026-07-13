--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local RewardMath = require(Shared.Utilities.RewardMath)
local Types = require(Shared.Types)

local RecipeService = {}
RecipeService.Name = "RecipeService"

function RecipeService.GetRecipe(_self: any, recipeId: string): Types.RecipeDefinition?
	return Recipes[recipeId]
end

function RecipeService.IsUnlocked(_self: any, data: Types.PlayerData, recipeId: string): boolean
	return data.unlockedRecipes[recipeId] == true
end

function RecipeService.Payout(_self: any, recipeId: string, manualCook: boolean): number
	local recipe = Recipes[recipeId]
	if not recipe then
		return 0
	end
	return RewardMath.orderPayout(recipe, manualCook)
end

return RecipeService
