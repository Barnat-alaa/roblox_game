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
-- The rules mirror `claimSeat` exactly, including the non-obvious one: a seat
-- inside the staff-only kitchen rectangle does not count, because diners are kept
-- out of it, so a chair parked there is furniture rather than seating.
--
-- Updated 2026-08-06 with the table-and-chairs sets: occupancy is now keyed on
-- `instanceId#slot`, so a piece really does hold `seatCount` diners and this sums
-- `seatCount` rather than counting instances. Before the sets existed every piece
-- seated exactly one, so the two agreed.

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
				count += math.max(1, math.floor(tonumber(def.seatCount) or 1))
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
