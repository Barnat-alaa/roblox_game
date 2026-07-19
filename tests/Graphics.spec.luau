--!strict
-- Contracts for the owner-approved UI, surface, and retro-food graphics.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local AssetManifest = require(ReplicatedStorage.Shared.Config.AssetManifest)
	local Graphics = require(ReplicatedStorage.Shared.Config.Graphics)
	local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)

	describe("Approved graphics", function()
		it("defines a non-empty image for every persistent HUD icon", function()
			for _, key in
				{
					"Coin",
					"Reputation",
					"Level",
					"Buzz",
					"Goals",
					"Cookbook",
					"Build",
					"Shop",
					"Pantry",
				}
			do
				local image = Graphics.UI[key]
				expect(type(image)).to.equal("string")
				expect(#image > 0).to.equal(true)
			end
		end)

		it("defines all six environment surfaces", function()
			local count = 0
			for _, image in Graphics.Surfaces do
				count += 1
				expect(string.find(image, "rbxthumb://", 1, true) == 1).to.equal(true)
			end
			expect(count).to.equal(6)
		end)

		it("maps a sanitised retro food mesh for every recipe", function()
			local mapped = AssetManifest.retroPropPack.recipes
			for recipeId in Recipes do
				local selection = mapped[recipeId]
				expect(selection ~= nil).to.equal(true)
				expect(selection.fit > 0).to.equal(true)
			end
		end)

		it("does not ship the branded diner-logo model", function()
			for _, assetId in Graphics.SourceAssets do
				expect(assetId == 79519710309081).to.equal(false)
			end
			expect(AssetManifest.retroPropPack.assetId).to.equal(134670664555156)
		end)
	end)
end
