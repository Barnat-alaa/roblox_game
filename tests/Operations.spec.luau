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
			-- The plan is what drives production now (Kitchen.useProductionPlan).
			-- A Barista at level 1 gets workMinutesBase = 15 work-minutes an hour
			-- and Espresso costs 1 of them, so 20 asked for is trimmed to 15.
			productionPlan = { Barista = { espresso = 20 } },
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
			-- 15 work-minutes an hour / 1 minute per Espresso = 15 an hour.
			-- The old forecast claimed 3 A MINUTE (180/h) by modelling the
			-- disabled legacy scheduler — twelve times the truth.
			expect(rates.products.espresso.productionPerMinute).to.equal(15 / 60)
			expect(rates.products.espresso.serviceCapacityPerMinute).to.equal(2.5)
			-- One waiter covers 0.25 servings a minute easily, so the kitchen is
			-- the limit now, not the floor.
			expect(rates.products.espresso.bottleneck).to.equal("PRODUCTION")
			-- Ingredients are per SERVING, not a batch cost divided by yield.
			expect(rates.products.espresso.ingredientPerServing).to.equal(
				Recipes.espresso.ingredientCost
			)
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

		it("shares one hourly budget across a role's recipes", function()
			local data = profile()
			data.unlockedRecipes.cappuccino = true
			data.kitchen.menu.cappuccino = true
			-- Both are Barista work off the SAME 15 minutes. Cappuccino sorts
			-- first and costs 1.5 each, so 8 of them eat 12 minutes and leave 3
			-- for Espresso. The old forecast reported each recipe as if it had the
			-- whole kitchen to itself.
			data.productionPlan = { Barista = { cappuccino = 8, espresso = 20 } }
			local rates = OperationsMath.calculate(
				data,
				Recipes,
				Staff,
				Kitchen.staffLevelSpeedPerLevel,
				Kitchen.batchCostMultiplier,
				Kitchen.servingPayoutFraction,
				Operations.offlineEarningsDivisor
			)
			expect(rates.products.cappuccino.productionPerMinute).to.equal(8 / 60)
			expect(rates.products.espresso.productionPerMinute).to.equal(3 / 60)
		end)
	end)
end
