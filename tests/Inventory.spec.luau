--!strict
-- Contract tests for FIFO perishables, atomic reservations, and all 14 product rates.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local InventoryMath = require(ReplicatedStorage.Shared.Utilities.InventoryMath)
	local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)

	local function state(): any
		return {
			lots = {},
			reservations = {},
			stock = {},
			nextLotId = 0,
			nextReservationId = 0,
		}
	end

	describe("Perishable inventory", function()
		it("commits the earliest-expiring serving first", function()
			local inventory = state()
			InventoryMath.addLot(inventory, "espresso", 2, 10, 200)
			InventoryMath.addLot(inventory, "espresso", 1, 20, 100)

			local reservation = InventoryMath.reserve(inventory, "espresso", 1, 30, 15)
			expect(reservation ~= nil).to.equal(true)
			expect(InventoryMath.commit(inventory, reservation :: string, 30)).to.equal("espresso")
			expect(#inventory.lots.espresso).to.equal(1)
			expect(inventory.lots.espresso[1].quantity).to.equal(2)
		end)

		it("prevents two reservations from claiming the same serving", function()
			local inventory = state()
			InventoryMath.addLot(inventory, "tea", 1, 10, 200)

			local first = InventoryMath.reserve(inventory, "tea", 1, 20, 15)
			local second = InventoryMath.reserve(inventory, "tea", 1, 20, 15)
			expect(first ~= nil).to.equal(true)
			expect(second).to.equal(nil)
		end)

		it("releases abandoned reservations after their timeout", function()
			local inventory = state()
			InventoryMath.addLot(inventory, "tea", 1, 10, 200)
			InventoryMath.reserve(inventory, "tea", 1, 20, 5)

			expect(InventoryMath.releaseExpiredReservations(inventory, 26)).to.equal(1)
			local _, available = InventoryMath.count(inventory, "tea", 26)
			expect(available).to.equal(1)
		end)

		it("spoils expired lots without touching fresh lots", function()
			local inventory = state()
			InventoryMath.addLot(inventory, "muffin", 3, 10, 50)
			InventoryMath.addLot(inventory, "muffin", 4, 20, 100)

			local spoiled = InventoryMath.expire(inventory, 60)
			expect(spoiled.muffin).to.equal(3)
			local total = InventoryMath.count(inventory, "muffin", 60)
			expect(total).to.equal(4)
		end)

		it("pauses shelf-life countdowns during offline time", function()
			local inventory = state()
			InventoryMath.addLot(inventory, "croissant", 2, 10, 100)
			InventoryMath.shiftExpiry(inventory, 300)

			expect(inventory.lots.croissant[1].producedAt).to.equal(310)
			expect(inventory.lots.croissant[1].expiresAt).to.equal(400)
		end)
	end)

	describe("Production balance", function()
		it(
			"defines production, spoilage, serving, appliance, and staff data for all products",
			function()
				local count = 0
				for _, recipe in Recipes do
					count += 1
					expect(recipe.productionTime > 0).to.equal(true)
					expect(recipe.productionYield > 0).to.equal(true)
					expect(recipe.spoilTime > recipe.serveTime).to.equal(true)
					expect(recipe.applianceId ~= "").to.equal(true)
					expect(recipe.staffRole == "Barista" or recipe.staffRole == "Cook").to.equal(
						true
					)
				end
				expect(count).to.equal(14)
			end
		)

		it("keeps the starter espresso producer slightly ahead of one waiter", function()
			local espresso = Recipes.espresso
			local producedPerMinute = espresso.productionYield * 60 / espresso.productionTime
			local servedPerMinute = 60 / espresso.serveTime
			expect(producedPerMinute).to.equal(3)
			expect(servedPerMinute).to.equal(2.5)
			expect(producedPerMinute > servedPerMinute).to.equal(true)
		end)

		it("keeps normal products near the two-to-three servings per minute band", function()
			for id, recipe in Recipes do
				if id ~= "slow_roast" then
					local rate = recipe.productionYield * 60 / recipe.productionTime
					expect(rate >= 2 and rate <= 3).to.equal(true)
				end
			end
		end)
	end)
end
