--!strict
-- Pure grid math for placement. No Roblox side effects beyond CFrame/Vector3
-- construction, so the core helpers are unit-tested in tests/Placement.spec.luau.

local Grid = {}

Grid.CELL_SIZE = 4 -- studs per grid cell
Grid.PLOT_WIDTH = 18 -- cells along local X (fixed for every expansion tier)
Grid.PLOT_DEPTH = 32 -- cells along local Z at MAX expansion tier

-- A footprint rotated 90 or 270 degrees swaps its width and depth.
function Grid.footprintSize(width: number, depth: number, rotation: number): (number, number)
	if rotation % 2 == 1 then
		return depth, width
	end
	return width, depth
end

-- Optional plotWidth/plotDepth override the constants so callers can clamp to
-- the owner's CURRENT expansion tier (World.interiorDepthTiers) — placement
-- must never spill into the not-yet-purchased garden.
function Grid.inBounds(
	gridX: number,
	gridY: number,
	width: number,
	depth: number,
	rotation: number,
	plotWidth: number?,
	plotDepth: number?
): boolean
	local maxW = plotWidth or Grid.PLOT_WIDTH
	local maxD = plotDepth or Grid.PLOT_DEPTH
	local w, d = Grid.footprintSize(width, depth, rotation)
	return gridX >= 0 and gridY >= 0 and (gridX + w) <= maxW and (gridY + d) <= maxD
end

-- Horizontal distance (studs) from a world position to the plot's interior
-- rectangle — 0 when inside. Proximity checks ("am I at my café?") must use
-- this instead of distance-to-centre: on deep plots the centre is far from
-- the front counters, so a radius check would reject a player standing at
-- their own stove.
function Grid.distanceToPlotRect(
	origin: CFrame,
	worldPos: Vector3,
	widthCells: number?,
	depthCells: number?
): number
	local w = (widthCells or Grid.PLOT_WIDTH) * Grid.CELL_SIZE
	local d = (depthCells or Grid.PLOT_DEPTH) * Grid.CELL_SIZE
	local lp = origin:PointToObjectSpace(worldPos)
	local dx = math.max(-lp.X, lp.X - w, 0)
	local dz = math.max(-lp.Z, lp.Z - d, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Axis-aligned rectangle overlap in cell space.
function Grid.rectsOverlap(
	ax: number,
	ay: number,
	aw: number,
	ad: number,
	bx: number,
	by: number,
	bw: number,
	bd: number
): boolean
	return ax < bx + bw and bx < ax + aw and ay < by + bd and by < ay + ad
end

-- Rotation for a seat whose local LookVector should point toward a target.
-- Grid rotations map as: 0 = -Z, 1 = -X, 2 = +Z, 3 = +X.
function Grid.rotationFacingDelta(dx: number, dz: number): number?
	if math.abs(dx) < 0.001 and math.abs(dz) < 0.001 then
		return nil
	end
	if math.abs(dx) >= math.abs(dz) then
		return if dx > 0 then 3 else 1
	end
	return if dz > 0 then 2 else 0
end

function Grid.occupiedCells(
	gridX: number,
	gridY: number,
	width: number,
	depth: number,
	rotation: number
): { { x: number, y: number } }
	local w, d = Grid.footprintSize(width, depth, rotation)
	local cells = {}
	for dx = 0, w - 1 do
		for dy = 0, d - 1 do
			table.insert(cells, { x = gridX + dx, y = gridY + dy })
		end
	end
	return cells
end

-- World CFrame for the centre of a footprint, given the plot origin.
-- The caller sizes the part with the ORIGINAL width/depth and lets this rotation
-- swap the world extents, keeping the render aligned with the occupancy grid.
function Grid.cellToWorld(
	origin: CFrame,
	gridX: number,
	gridY: number,
	width: number,
	depth: number,
	rotation: number,
	height: number
): CFrame
	local w, d = Grid.footprintSize(width, depth, rotation)
	local localX = (gridX + w / 2) * Grid.CELL_SIZE
	local localZ = (gridY + d / 2) * Grid.CELL_SIZE
	local centre = origin * CFrame.new(localX, height / 2, localZ)
	return centre * CFrame.Angles(0, math.rad(90 * rotation), 0)
end

-- Convert a world position to the grid cell it sits in (for client previews).
function Grid.worldToCell(origin: CFrame, worldPos: Vector3): (number, number)
	local localPos = origin:PointToObjectSpace(worldPos)
	local gx = math.floor(localPos.X / Grid.CELL_SIZE)
	local gy = math.floor(localPos.Z / Grid.CELL_SIZE)
	return gx, gy
end

return Grid
