--!strict
-- Pure geometry for the boulevard's two sidewalks and the narrow lane inside
-- each one that ambient pedestrians are allowed to walk.
--
-- The hard requirement is "sidewalks ONLY": an ambient NPC must never step onto
-- the road, never clip into a café's front wall, and never walk through the
-- street decor CafeService scatters along the kerb. All of that is decided
-- here, in pure numbers, so tests/StreetMath.spec.luau can assert containment
-- instead of us discovering a pedestrian jaywalking in a playtest.
--
-- Cross-section of the boulevard, looking down +X (Z grows toward the viewer):
--
--   Z =   0   row-0 café fronts
--         .   ← sidewalk A            (walkable band: laneBounds(0))
--   Z = -18   kerb / road edge
--         .   ← ROAD                  (never walkable)
--   Z = -42   kerb / road edge
--         .   ← sidewalk B            (walkable band: laneBounds(1))
--   Z = -60   row-1 café fronts

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local Grid = require(ReplicatedStorage.Shared.Utilities.Grid)

local StreetMath = {}

-- Distance CafeService insets the mailbox (side 0) and hydrant (side 1) from
-- the café front line. Pedestrian lanes must clear these or NPCs walk into
-- them: they are solid and NPCs collide with the world.
StreetMath.DECOR_INSET = 14

-- Breathing room kept between a lane edge and anything solid (café wall on one
-- side, street decor on the other). Roughly an NPC's shoulder width.
StreetMath.CLEARANCE = 3.5

-- Margin kept between the walkable X range and the very ends of the paving.
StreetMath.END_MARGIN = 20

function StreetMath.plotWidth(): number
	return Grid.PLOT_WIDTH * Grid.CELL_SIZE
end

function StreetMath.plotSpacing(): number
	return StreetMath.plotWidth() + World.plotGap
end

-- Length of the built-up street, front door of plot 1 to front door of the last
-- plot in a row. Mirrors CafeService's own streetLength.
function StreetMath.streetLength(): number
	return (World.plotsPerRow - 1) * StreetMath.plotSpacing() + StreetMath.plotWidth()
end

function StreetMath.sidewalkWidth(): number
	return (World.boulevardWidth - World.roadWidth) / 2
end

-- Which sidewalk a plot fronts onto. Row 0 (indices 1..plotsPerRow) faces
-- sidewalk A; the far row faces sidewalk B. Matches CafeService.plotOriginFor.
function StreetMath.sideForPlotIndex(index: number): number
	return if index <= World.plotsPerRow then 0 else 1
end

-- Z of the café front wall for a side: 0 for row 0, -boulevardWidth for row 1.
function StreetMath.frontLineZ(side: number): number
	return if side == 0 then 0 else -World.boulevardWidth
end

-- Full paved extent of one sidewalk, as (minZ, maxZ).
function StreetMath.sidewalkBounds(side: number): (number, number)
	local w = StreetMath.sidewalkWidth()
	if side == 0 then
		return -w, 0
	end
	return -World.boulevardWidth, -World.boulevardWidth + w
end

-- Z of the street decor sitting ON this sidewalk (mailbox / hydrant + tree),
-- which the lane has to stay clear of. Exposed so the spec can assert it.
function StreetMath.decorZs(side: number): { number }
	if side == 0 then
		-- Lamps sit right on the kerb line, mailboxes one inset in.
		return { -StreetMath.sidewalkWidth(), -StreetMath.DECOR_INSET }
	end
	local b = World.boulevardWidth
	return {
		-(b - StreetMath.sidewalkWidth()), -- kerb-line lamps
		-(b - StreetMath.DECOR_INSET), -- hydrants
		-44, -- the four boulevard trees
	}
end

-- The walkable band, as (minZ, maxZ): strictly inside the paving, clear of the
-- café fronts and clear of the decor. This is the ONLY Z range an ambient
-- pedestrian may occupy.
function StreetMath.laneBounds(side: number): (number, number)
	local c = StreetMath.CLEARANCE
	if side == 0 then
		-- Between the mailbox line (-14) and the café fronts (0).
		return -StreetMath.DECOR_INSET + c, -c
	end
	-- Mirror of side 0 about the boulevard centreline.
	local b = World.boulevardWidth
	return -b + c, -(b - StreetMath.DECOR_INSET) - c
end

-- Lane Z for alpha in [0, 1] — 0 is the kerb-most edge, 1 the café-most edge.
function StreetMath.laneZ(side: number, alpha: number): number
	local lo, hi = StreetMath.laneBounds(side)
	return lo + (hi - lo) * math.clamp(alpha, 0, 1)
end

-- True when z sits inside the walkable band for that side.
function StreetMath.inLane(side: number, z: number): boolean
	local lo, hi = StreetMath.laneBounds(side)
	return z >= lo and z <= hi
end

-- True when z is anywhere on that sidewalk's paving (looser than inLane).
function StreetMath.onSidewalk(side: number, z: number): boolean
	local lo, hi = StreetMath.sidewalkBounds(side)
	return z >= lo and z <= hi
end

-- Walkable X range along the boulevard, kept just inside the paved ends.
function StreetMath.walkXBounds(): (number, number)
	return -StreetMath.END_MARGIN, StreetMath.streetLength() + StreetMath.END_MARGIN
end

function StreetMath.clampX(x: number): number
	local lo, hi = StreetMath.walkXBounds()
	return math.clamp(x, lo, hi)
end

-- Snap any position back into the lane. The service calls this every leg so a
-- shove from a player (or a physics nudge) can never leave an NPC in the road.
function StreetMath.clampToLane(side: number, position: Vector3, laneZ: number): Vector3
	local lo, hi = StreetMath.laneBounds(side)
	return Vector3.new(StreetMath.clampX(position.X), position.Y, math.clamp(laneZ, lo, hi))
end

return StreetMath
