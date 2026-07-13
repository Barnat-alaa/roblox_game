--!strict
-- Pure grid math for placement. No Roblox side effects beyond CFrame/Vector3
-- construction, so the core helpers are unit-tested in tests/Placement.spec.luau.

local Grid = {}

Grid.CELL_SIZE = 4 -- studs per grid cell
Grid.PLOT_WIDTH = 12 -- cells along local X
Grid.PLOT_DEPTH = 12 -- cells along local Z

-- A footprint rotated 90 or 270 degrees swaps its width and depth.
function Grid.footprintSize(width: number, depth: number, rotation: number): (number, number)
	if rotation % 2 == 1 then
		return depth, width
	end
	return width, depth
end

function Grid.inBounds(
	gridX: number,
	gridY: number,
	width: number,
	depth: number,
	rotation: number
): boolean
	local w, d = Grid.footprintSize(width, depth, rotation)
	return gridX >= 0
		and gridY >= 0
		and (gridX + w) <= Grid.PLOT_WIDTH
		and (gridY + d) <= Grid.PLOT_DEPTH
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
