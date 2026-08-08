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
			-- Deliberately far more than any budget: the point of these tests is
			-- that the ROLE'S hourly work-minutes trim the plan, so the ask has to
			-- exceed them. Asserting against a literal broke the moment
			-- workMinutesBase was retuned (15 → 40 on 2026-08-06).
			productionPlan = { Barista = { espresso = 999 } },
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
			-- A level-1 Barista's whole hourly budget / 1 minute per Espresso.
			-- The old forecast claimed 3 A MINUTE (180/h) by modelling the
			-- disabled legacy scheduler — twelve times the truth.
			local budget = Kitchen.workMinutesBase
			expect(rates.products.espresso.productionPerMinute).to.equal(budget / 60)
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
			-- Both are Barista, working off the SAME hourly budget. Cappuccino
			-- sorts first and costs 1.5 minutes each; Espresso then gets whatever
			-- minutes are left, NOT a budget of its own. The old forecast reported
			-- each recipe as if it had the whole kitchen to itself.
			local budget = Kitchen.workMinutesBase
			local cappMinutes = Recipes.cappuccino.productionMinutes :: number
			local cappuccinos = math.floor(budget / 3 / cappMinutes)
			data.productionPlan = { Barista = { cappuccino = cappuccinos, espresso = 999 } }
			local rates = OperationsMath.calculate(
				data,
				Recipes,
				Staff,
				Kitchen.staffLevelSpeedPerLevel,
				Kitchen.batchCostMultiplier,
				Kitchen.servingPayoutFraction,
				Operations.offlineEarningsDivisor
			)
			-- Espresso costs exactly 1 work-minute, so the leftover minutes ARE the
			-- leftover servings. Both figures are derived from config so a retune
			-- of either recipe cannot silently invalidate this test.
			local leftover = math.floor(budget - cappuccinos * cappMinutes)
			expect(rates.products.cappuccino.productionPerMinute).to.equal(cappuccinos / 60)
			expect(rates.products.espresso.productionPerMinute).to.equal(leftover / 60)
			-- The whole point: the two together never exceed the ONE budget.
			expect(cappuccinos * cappMinutes + leftover <= budget).to.equal(true)
		end)
	end)
end
