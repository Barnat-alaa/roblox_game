--!strict
-- Contract tests for seat counting (owner report, 2026-08-05).
--
-- `SeatMath` exists so the online rule and the offline settlement cannot drift:
-- online a diner who cannot claim a chair storms out and pays nothing, and
-- offline the plan now refuses to settle at all without a seat. If these rules
-- ever disagree again, an unfurnished café goes back to earning while its owner
-- is away and earning nothing while they play.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local SeatMath = require(ReplicatedStorage.Shared.Utilities.SeatMath)
	local Furniture = require(ReplicatedStorage.Shared.Config.Furniture)
	local World = require(ReplicatedStorage.Shared.Config.World)

	-- A dining cell, safely clear of the staff-only kitchen rectangle.
	local DINING_X = World.kitchenWidthCells + 2
	local DINING_Y = World.kitchenDepthCells + 2

	local function seat(gridX: number, gridY: number, instanceId: string): any
		return {
			instanceId = instanceId,
			catalogId = "chair_wood",
			gridX = gridX,
			gridY = gridY,
			rotation = 0,
		}
	end

	local function profile(placed: any, inventory: any?): any
		return { placedFurniture = placed, inventory = inventory or {} }
	end

	describe("SeatMath.usableSeats", function()
		it("is zero for the starter café, which places no chairs", function()
			-- The exact situation the owner hit: a counter and a coffee machine are
			-- placed, the chairs are still sitting in inventory.
			local starter = profile({
				{
					instanceId = "seed_counter",
					catalogId = "counter",
					gridX = 4,
					gridY = 3,
					rotation = 0,
				},
			}, { chair_wood = 4, table_round = 2 })
			expect(SeatMath.usableSeats(starter)).to.equal(0)
		end)

		it("counts a chair placed in the dining area", function()
			expect(SeatMath.usableSeats(profile({ seat(DINING_X, DINING_Y, "a") }))).to.equal(1)
		end)

		it("counts each placed chair separately", function()
			local placed = {
				seat(DINING_X, DINING_Y, "a"),
				seat(DINING_X + 2, DINING_Y, "b"),
				seat(DINING_X + 4, DINING_Y, "c"),
			}
			expect(SeatMath.usableSeats(profile(placed))).to.equal(3)
		end)

		it("ignores a chair parked inside the staff-only kitchen", function()
			-- claimSeat skips these, so counting them would let the offline
			-- settlement pay for diners the online game turns away.
			expect(SeatMath.usableSeats(profile({ seat(0, 0, "kitchen") }))).to.equal(0)
		end)

		it("ignores furniture that is not seating", function()
			local placed = {
				{
					instanceId = "t",
					catalogId = "table_round",
					gridX = DINING_X,
					gridY = DINING_Y,
					rotation = 0,
				},
				{
					instanceId = "p",
					catalogId = "plant_small",
					gridX = DINING_X + 2,
					gridY = DINING_Y,
					rotation = 0,
				},
			}
			expect(SeatMath.usableSeats(profile(placed))).to.equal(0)
		end)

		it("survives a malformed or missing furniture list", function()
			expect(SeatMath.usableSeats(nil)).to.equal(0)
			expect(SeatMath.usableSeats({})).to.equal(0)
			expect(SeatMath.usableSeats(profile("not a table"))).to.equal(0)
			expect(SeatMath.usableSeats(profile({ { catalogId = "no_such_thing" } }))).to.equal(0)
		end)
	end)

	describe("SeatMath.seatsInInventory", function()
		it("counts unplaced chairs, which decides WHICH nudge the player gets", function()
			expect(SeatMath.seatsInInventory(profile({}, { chair_wood = 4 }))).to.equal(4)
		end)

		it("is zero when the player owns only non-seating furniture", function()
			expect(SeatMath.seatsInInventory(profile({}, { table_round = 2, plant_small = 1 }))).to.equal(
				0
			)
		end)

		it("survives a malformed or missing inventory", function()
			expect(SeatMath.seatsInInventory(nil)).to.equal(0)
			expect(SeatMath.seatsInInventory({ inventory = "nope" })).to.equal(0)
			expect(SeatMath.seatsInInventory(profile({}, { chair_wood = -3 }))).to.equal(0)
		end)
	end)

	describe("the seating catalogue itself", function()
		it("still contains at least one placeable seat", function()
			-- If seatCount were ever dropped from every entry, both the online loop
			-- and the offline settlement would silently earn nothing forever.
			local seats = 0
			for _, def in Furniture do
				if (tonumber(def.seatCount) or 0) > 0 then
					seats += 1
				end
			end
			expect(seats > 0).to.equal(true)
		end)
	end)
end
