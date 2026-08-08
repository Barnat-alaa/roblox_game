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
					-- "Level" is deliberately absent: no approved Level artwork has
					-- been uploaded, so that pill renders from Theme.Glyphs.Level
					-- ("L") instead. Listing it here made this spec fail for months
					-- while describing a rule the project had not adopted. Put it
					-- back the moment an asset exists — see docs/RELEASE_ASSETS.md.
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

		it("serves every HUD icon through the thumbnail pipe", function()
			-- These rendered as text letters on a real device for three rounds while
			-- the environment surfaces — identical artwork pipeline, but authored
			-- with `thumbnail()` — rendered fine in the same frame. Raw
			-- `rbxassetid://` is refused for a private image the client is not
			-- entitled to fetch; the thumbnail of an approved asset is public.
			--
			-- This test is the guard: put a raw asset id back in Graphics.UI and it
			-- fails here rather than silently becoming letters on someone's phone.
			local checked = 0
			for key, image in Graphics.UI do
				checked += 1
				expect(type(image)).to.equal("string")
				if string.find(image, "rbxassetid://", 1, true) == 1 then
					error(
						("Graphics.UI.%s uses a raw asset id; HUD art must use thumbnail() — see the note in Config/Graphics"):format(
							key
						)
					)
				end
				expect(string.find(image, "rbxthumb://", 1, true) == 1).to.equal(true)
			end
			expect(checked > 0).to.equal(true)
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
