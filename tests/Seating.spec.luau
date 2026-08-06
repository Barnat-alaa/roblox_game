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

	describe("multi-seat sets", function()
		local function set(catalogId: string, gridX: number, gridY: number): any
			return {
				instanceId = catalogId .. "_1",
				catalogId = catalogId,
				gridX = gridX,
				gridY = gridY,
				rotation = 0,
			}
		end

		it("counts every seat on a set, not the set itself", function()
			-- The whole point of the 2026-08-06 haul: a four-top seats four. Before
			-- occupancy was keyed on instanceId#slot, a set of any size seated one
			-- and its other chairs sat visibly empty forever.
			for _, case in
				{
					{ id = "set_cafe_two", seats = 2 },
					{ id = "set_fancy_two", seats = 2 },
					{ id = "set_diner_four", seats = 4 },
				}
			do
				expect(Furniture[case.id]).to.be.ok()
				expect(Furniture[case.id].seatCount).to.equal(case.seats)
				expect(SeatMath.usableSeats(profile({ set(case.id, DINING_X, DINING_Y) }))).to.equal(
					case.seats
				)
			end
		end)

		it("adds a set's seats to the loose chairs around it", function()
			local placed = {
				set("set_diner_four", DINING_X, DINING_Y),
				seat(DINING_X + 6, DINING_Y, "loose_a"),
				seat(DINING_X + 8, DINING_Y, "loose_b"),
			}
			expect(SeatMath.usableSeats(profile(placed))).to.equal(6)
		end)

		it("gives every seating catalogue entry a sane seat count", function()
			-- A "Seating" piece with a chair in its model but seatCount 0 would look
			-- sittable and never be sat on, which is the bug this whole file exists
			-- to prevent. Tables legitimately seat nobody, so only the ceiling is
			-- asserted here.
			for id, def in Furniture do
				local seats = tonumber(def.seatCount) or 0
				expect(seats >= 0).to.equal(true)
				expect(seats <= 4).to.equal(true)
				if seats > 1 then
					-- A multi-seat piece needs room for its diners to sit apart.
					expect(def.width * def.depth >= seats).to.equal(true, id)
				end
			end
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
