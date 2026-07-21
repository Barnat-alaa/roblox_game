--!strict
-- Containment contract for ambient pedestrian lanes. The owner's requirement is
-- "sidewalks only", so these assert the lane can never put an NPC on the road,
-- inside a café wall, or on top of the street decor.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local World = require(ReplicatedStorage.Shared.Config.World)
	local StreetMath = require(ReplicatedStorage.Shared.Utilities.StreetMath)

	local SIDES = { 0, 1 }

	-- The road occupies the middle of the boulevard, between the two sidewalks.
	local function roadBounds(): (number, number)
		local w = StreetMath.sidewalkWidth()
		return -World.boulevardWidth + w, -w
	end

	describe("sidewalk geometry", function()
		it("splits the boulevard into road + two equal sidewalks", function()
			local w = StreetMath.sidewalkWidth()
			expect(w * 2 + World.roadWidth).to.equal(World.boulevardWidth)
		end)

		it("places sidewalk A against the row-0 fronts and B against row-1", function()
			local aLo, aHi = StreetMath.sidewalkBounds(0)
			expect(aHi).to.equal(0)
			expect(aLo).to.equal(-StreetMath.sidewalkWidth())

			local bLo, bHi = StreetMath.sidewalkBounds(1)
			expect(bLo).to.equal(-World.boulevardWidth)
			expect(bHi).to.equal(-World.boulevardWidth + StreetMath.sidewalkWidth())
		end)

		it("maps plot indices to the sidewalk their door faces", function()
			expect(StreetMath.sideForPlotIndex(1)).to.equal(0)
			expect(StreetMath.sideForPlotIndex(World.plotsPerRow)).to.equal(0)
			expect(StreetMath.sideForPlotIndex(World.plotsPerRow + 1)).to.equal(1)
			expect(StreetMath.sideForPlotIndex(World.plotCount)).to.equal(1)
		end)
	end)

	describe("pedestrian lanes stay on the pavement", function()
		it("keeps every lane strictly inside its own sidewalk", function()
			for _, side in SIDES do
				local laneLo, laneHi = StreetMath.laneBounds(side)
				local walkLo, walkHi = StreetMath.sidewalkBounds(side)
				expect(laneLo > walkLo).to.equal(true)
				expect(laneHi < walkHi).to.equal(true)
				expect(laneLo < laneHi).to.equal(true)
			end
		end)

		it("never overlaps the road", function()
			local roadLo, roadHi = roadBounds()
			for _, side in SIDES do
				local laneLo, laneHi = StreetMath.laneBounds(side)
				-- No part of the lane may fall within [roadLo, roadHi].
				local overlaps = laneLo <= roadHi and roadLo <= laneHi
				expect(overlaps).to.equal(false)
			end
		end)

		it("keeps clearance from the café front walls", function()
			for _, side in SIDES do
				local laneLo, laneHi = StreetMath.laneBounds(side)
				local front = StreetMath.frontLineZ(side)
				local nearest = math.min(math.abs(laneLo - front), math.abs(laneHi - front))
				expect(nearest >= StreetMath.CLEARANCE).to.equal(true)
			end
		end)

		it("keeps clearance from every piece of street decor", function()
			for _, side in SIDES do
				local laneLo, laneHi = StreetMath.laneBounds(side)
				for _, z in StreetMath.decorZs(side) do
					-- The decor must sit outside the lane...
					expect(z >= laneLo and z <= laneHi).to.equal(false)
					-- ...with real breathing room, not just barely outside.
					local gap = math.min(math.abs(z - laneLo), math.abs(z - laneHi))
					expect(gap >= StreetMath.CLEARANCE).to.equal(true)
				end
			end
		end)

		it("returns an on-pavement Z for every alpha across the lane", function()
			for _, side in SIDES do
				for step = 0, 10 do
					local z = StreetMath.laneZ(side, step / 10)
					expect(StreetMath.inLane(side, z)).to.equal(true)
					expect(StreetMath.onSidewalk(side, z)).to.equal(true)
				end
			end
		end)

		it("clamps out-of-range alphas back into the lane", function()
			for _, side in SIDES do
				expect(StreetMath.inLane(side, StreetMath.laneZ(side, -5))).to.equal(true)
				expect(StreetMath.inLane(side, StreetMath.laneZ(side, 5))).to.equal(true)
			end
		end)
	end)

	describe("recovery clamp", function()
		it("pulls a shoved pedestrian back onto its sidewalk", function()
			for _, side in SIDES do
				-- Simulate being pushed into the middle of the road.
				local shoved = Vector3.new(400, 3, -30)
				local fixed = StreetMath.clampToLane(side, shoved, StreetMath.laneZ(side, 0.5))
				expect(StreetMath.inLane(side, fixed.Z)).to.equal(true)
				expect(StreetMath.onSidewalk(side, fixed.Z)).to.equal(true)
			end
		end)

		it("clamps X to the paved run of the street", function()
			local lo, hi = StreetMath.walkXBounds()
			expect(StreetMath.clampX(-9999)).to.equal(lo)
			expect(StreetMath.clampX(9999)).to.equal(hi)
			expect(lo < hi).to.equal(true)
		end)
	end)
end
