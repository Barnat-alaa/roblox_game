--!strict
-- Run with a TestEZ runner in Studio (see docs/TEST_PLAN.md).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RewardMath = require(ReplicatedStorage.Shared.Utilities.RewardMath)
	local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)

	describe("RewardMath", function()
		it("pays base profit for an auto-cooked order", function()
			local espresso = Recipes.espresso
			expect(RewardMath.orderPayout(espresso, false)).to.equal(
				espresso.basePrice - espresso.ingredientCost
			)
		end)

		it("adds a bonus for a manual cook", function()
			local espresso = Recipes.espresso
			expect(RewardMath.orderPayout(espresso, true) > RewardMath.orderPayout(espresso, false)).to.equal(
				true
			)
		end)

		it("never returns a negative payout", function()
			local fake = {
				id = "x",
				displayName = "x",
				category = "x",
				ingredientCost = 999,
				basePrice = 1,
				preparationTime = 1,
				applianceId = "x",
				requiredLevel = 1,
				requiredReputation = 0,
				baseQuality = 1,
				masteryThresholds = {},
			}
			expect(RewardMath.orderPayout(fake, false)).to.equal(0)
		end)

		it("gives no tip when the roll misses the chance", function()
			expect(RewardMath.tipAmount(Recipes.espresso, 100, 1)).to.equal(0)
		end)

		it("gives a tip when the roll hits", function()
			expect(RewardMath.tipAmount(Recipes.espresso, 1, 1) > 0).to.equal(true)
		end)

		it("scales tips by the customer multiplier", function()
			local low = RewardMath.tipAmount(Recipes.cappuccino, 1, 0.5)
			local high = RewardMath.tipAmount(Recipes.cappuccino, 1, 2.0)
			expect(high > low).to.equal(true)
		end)
	end)
end
