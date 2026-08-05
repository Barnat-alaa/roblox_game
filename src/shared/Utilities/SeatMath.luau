--!strict
-- Where a customer can actually sit (owner report, 2026-08-05).
--
-- Two places need this answer and used to disagree. Online, a diner who cannot
-- claim a chair storms out and pays nothing (`CustomerService.claimSeat` →
-- "😡 NO EMPTY CHAIR!"). Offline, `settlePlanOffline` paid out the whole
-- production plan without ever asking whether anyone could have sat down — so an
-- unfurnished café earned while its owner was away and earned nothing while they
-- played. Both sides now count seats through here, so they cannot drift again.
--
-- The rules mirror `claimSeat` exactly, including its two non-obvious ones:
--   * a seat inside the staff-only kitchen rectangle does not count — diners are
--     kept out of it, so a chair parked there is furniture, not seating;
--   * occupancy is keyed on `instanceId`, so ONE placed item holds ONE diner
--     however large its `seatCount` is. We therefore count INSTANCES, not the
--     sum of `seatCount`, because that is what the game really allows.

local Furniture = require(script.Parent.Parent.Config.Furniture)
local World = require(script.Parent.Parent.Config.World)
local Grid = require(script.Parent.Grid)

local SeatMath = {}

local function isSeatDefinition(catalogId: unknown): boolean
	if typeof(catalogId) ~= "string" then
		return false
	end
	local def = Furniture[catalogId]
	return def ~= nil and (tonumber(def.seatCount) or 0) > 0
end

-- Seats a diner could actually claim right now, ignoring who is sitting in them.
function SeatMath.usableSeats(data: any): number
	local placed = if typeof(data) == "table" then (data :: any).placedFurniture else nil
	if typeof(placed) ~= "table" then
		return 0
	end
	local count = 0
	for _, item in placed do
		if typeof(item) == "table" and isSeatDefinition(item.catalogId) then
			local def = Furniture[item.catalogId]
			local w, d = Grid.footprintSize(def.width, def.depth, tonumber(item.rotation) or 0)
			local seatX = (tonumber(item.gridX) or 0) + w / 2
			local seatZ = (tonumber(item.gridY) or 0) + d / 2
			local inKitchen = seatX < World.kitchenWidthCells and seatZ < World.kitchenDepthCells
			if not inKitchen then
				count += 1
			end
		end
	end
	return count
end

-- Seats the player owns but has not placed yet. The difference between "go and
-- place one" and "go and buy one" is the difference between a helpful nudge and
-- a useless one, so the two live in separate offers.
function SeatMath.seatsInInventory(data: any): number
	local inventory = if typeof(data) == "table" then (data :: any).inventory else nil
	if typeof(inventory) ~= "table" then
		return 0
	end
	local count = 0
	for catalogId, quantity in inventory do
		if isSeatDefinition(catalogId) then
			count += math.max(0, math.floor(tonumber(quantity) or 0))
		end
	end
	return count
end

return SeatMath
