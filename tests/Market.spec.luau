--!strict
-- Run with a TestEZ runner in Studio (see docs/TEST_PLAN.md).
-- Covers MarketMath: bulk pricing the client previews and the server charges.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local MarketMath = require(ReplicatedStorage.Shared.Utilities.MarketMath)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)

	describe("MarketMath.discountSteps", function()
		it("earns one step per bulk tier met", function()
			expect(MarketMath.discountSteps(24)).to.equal(0)
			expect(MarketMath.discountSteps(25)).to.equal(1)
			expect(MarketMath.discountSteps(50)).to.equal(2)
			expect(MarketMath.discountSteps(100)).to.equal(3)
			expect(MarketMath.discountSteps(250)).to.equal(4)
			expect(MarketMath.discountSteps(999)).to.equal(4)
		end)
	end)

	describe("MarketMath.unitMultiplier", function()
		it("is cheaper per unit for a bigger crate", function()
			expect(MarketMath.unitMultiplier(250) < MarketMath.unitMultiplier(25)).to.equal(true)
		end)

		it("never drops below the floor", function()
			expect(MarketMath.unitMultiplier(999) >= Economy.bulkMinPriceFraction).to.equal(true)
		end)
	end)

	describe("MarketMath.costFor", function()
		it("charges full price below the first tier", function()
			local price = Ingredients.coffee_beans.unitPrice
			expect(MarketMath.costFor("coffee_beans", 10)).to.equal(price * 10)
		end)

		it("applies the bulk discount at a tier", function()
			-- 250 × 2 × 0.8 (four 5% steps) = 400
			expect(MarketMath.costFor("coffee_beans", 250)).to.equal(400)
		end)

		it("makes bulk cheaper per unit than singles", function()
			local perSingle = MarketMath.costFor("coffee_beans", 10) / 10
			local perBulk = MarketMath.costFor("coffee_beans", 250) / 250
			expect(perBulk < perSingle).to.equal(true)
		end)

		it("rejects unknown ingredients and non-positive quantities", function()
			expect(MarketMath.costFor("does_not_exist", 10)).to.equal(0)
			expect(MarketMath.costFor("coffee_beans", 0)).to.equal(0)
			expect(MarketMath.costFor("coffee_beans", -5)).to.equal(0)
		end)

		it("never costs less than 1 for a real order", function()
			for id in Ingredients do
				expect(MarketMath.costFor(id, 1) >= 1).to.equal(true)
			end
		end)
	end)
end
