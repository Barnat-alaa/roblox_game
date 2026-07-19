--!strict
-- Contract tests for the visible production/service forecast.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
	local Staff = require(ReplicatedStorage.Shared.Config.Staff)
	local Kitchen = require(ReplicatedStorage.Shared.Config.Kitchen)
	local Operations = require(ReplicatedStorage.Shared.Config.Operations)
	local OperationsMath = require(ReplicatedStorage.Shared.Utilities.OperationsMath)

	local function profile(): any
		return {
			staff = {
				{ typeId = "barista_mia", level = 1 },
				{ typeId = "waiter_noah", level = 1 },
			},
			placedFurniture = {
				{ catalogId = "coffee_machine" },
			},
			unlockedRecipes = { espresso = true },
			kitchen = {
				menu = { espresso = true },
				priorities = { espresso = 1 },
			},
		}
	end

	describe("Shift forecast", function()
		it("shows the configured espresso producer and waiter rates", function()
			local rates = OperationsMath.calculate(
				profile(),
				Recipes,
				Staff,
				Kitchen.staffLevelSpeedPerLevel,
				Kitchen.batchCostMultiplier,
				Kitchen.servingPayoutFraction,
				Operations.offlineEarningsDivisor
			)
			expect(rates.products.espresso.productionPerMinute).to.equal(3)
			expect(rates.products.espresso.serviceCapacityPerMinute).to.equal(2.5)
			expect(rates.products.espresso.bottleneck).to.equal("SERVER")
		end)

		it("makes offline net income exactly twenty times weaker", function()
			local rates = OperationsMath.calculate(
				profile(),
				Recipes,
				Staff,
				Kitchen.staffLevelSpeedPerLevel,
				Kitchen.batchCostMultiplier,
				Kitchen.servingPayoutFraction,
				Operations.offlineEarningsDivisor
			)
			expect(Operations.offlineTimeMultiplier).to.equal(20)
			expect(rates.offlineNetPerMinute * 20).to.equal(rates.netPerMinute)
		end)

		it("stops automatic income without a waiter", function()
			local data = profile()
			table.remove(data.staff, 2)
			local rates = OperationsMath.calculate(
				data,
				Recipes,
				Staff,
				Kitchen.staffLevelSpeedPerLevel,
				Kitchen.batchCostMultiplier,
				Kitchen.servingPayoutFraction,
				Operations.offlineEarningsDivisor
			)
			expect(rates.throughputPerMinute).to.equal(0)
			expect(rates.netPerMinute).to.equal(0)
		end)
	end)
end
