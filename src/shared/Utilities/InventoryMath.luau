--!strict
-- Pure FIFO lot and reservation operations. Time is injected so production
-- and spoilage behavior stays deterministic in TestEZ simulations.

local InventoryMath = {}

local function ensure(state: any)
	state.lots = if typeof(state.lots) == "table" then state.lots else {}
	state.reservations = if typeof(state.reservations) == "table" then state.reservations else {}
	state.stock = if typeof(state.stock) == "table" then state.stock else {}
	state.nextLotId = math.max(0, tonumber(state.nextLotId) or 0)
	state.nextReservationId = math.max(0, tonumber(state.nextReservationId) or 0)
end

local function lotsFor(state: any, recipeId: string): { any }
	ensure(state)
	local lots = state.lots[recipeId]
	if typeof(lots) ~= "table" then
		lots = {}
		state.lots[recipeId] = lots
	end
	return lots
end

function InventoryMath.count(state: any, recipeId: string, now: number?): (number, number, number)
	local total = 0
	local available = 0
	local reserved = 0
	for _, lot in lotsFor(state, recipeId) do
		local quantity = math.max(0, tonumber(lot.quantity) or 0)
		local held = math.clamp(tonumber(lot.reserved) or 0, 0, quantity)
		if now == nil or (tonumber(lot.expiresAt) or 0) > now then
			total += quantity
			available += quantity - held
			reserved += held
		end
	end
	return total, available, reserved
end

function InventoryMath.addLot(
	state: any,
	recipeId: string,
	quantity: number,
	producedAt: number,
	expiresAt: number
): string?
	ensure(state)
	quantity = math.floor(quantity)
	if quantity <= 0 or expiresAt <= producedAt then
		return nil
	end
	state.nextLotId += 1
	local lotId = "lot_" .. tostring(state.nextLotId)
	table.insert(lotsFor(state, recipeId), {
		lotId = lotId,
		quantity = quantity,
		reserved = 0,
		producedAt = producedAt,
		expiresAt = expiresAt,
	})
	return lotId
end

function InventoryMath.release(state: any, reservationId: string): boolean
	ensure(state)
	local reservation = state.reservations[reservationId]
	if typeof(reservation) ~= "table" then
		return false
	end
	local byId: { [string]: any } = {}
	for _, lot in lotsFor(state, tostring(reservation.recipeId)) do
		byId[tostring(lot.lotId)] = lot
	end
	for _, allocation in reservation.allocations or {} do
		local lot = byId[tostring(allocation.lotId)]
		if lot then
			lot.reserved = math.max(
				0,
				(tonumber(lot.reserved) or 0) - math.max(0, tonumber(allocation.quantity) or 0)
			)
		end
	end
	state.reservations[reservationId] = nil
	return true
end

function InventoryMath.releaseExpiredReservations(state: any, now: number): number
	ensure(state)
	local expired = {}
	for reservationId, reservation in state.reservations do
		if (tonumber(reservation.expiresAt) or 0) <= now then
			table.insert(expired, reservationId)
		end
	end
	for _, reservationId in expired do
		InventoryMath.release(state, reservationId)
	end
	return #expired
end

function InventoryMath.reserve(
	state: any,
	recipeId: string,
	quantity: number,
	now: number,
	ttl: number
): string?
	ensure(state)
	InventoryMath.releaseExpiredReservations(state, now)
	quantity = math.floor(quantity)
	if quantity <= 0 then
		return nil
	end

	local ordered = table.clone(lotsFor(state, recipeId))
	table.sort(ordered, function(a, b)
		local aExpiry = tonumber(a.expiresAt) or 0
		local bExpiry = tonumber(b.expiresAt) or 0
		if aExpiry == bExpiry then
			return tostring(a.lotId) < tostring(b.lotId)
		end
		return aExpiry < bExpiry
	end)

	local remaining = quantity
	local allocations = {}
	for _, lot in ordered do
		if (tonumber(lot.expiresAt) or 0) > now then
			local free = math.max(0, (tonumber(lot.quantity) or 0) - (tonumber(lot.reserved) or 0))
			local take = math.min(free, remaining)
			if take > 0 then
				lot.reserved = (tonumber(lot.reserved) or 0) + take
				table.insert(allocations, { lotId = lot.lotId, quantity = take })
				remaining -= take
				if remaining <= 0 then
					break
				end
			end
		end
	end
	if remaining > 0 then
		for _, allocation in allocations do
			for _, lot in ordered do
				if lot.lotId == allocation.lotId then
					lot.reserved = math.max(0, lot.reserved - allocation.quantity)
					break
				end
			end
		end
		return nil
	end

	state.nextReservationId += 1
	local reservationId = "reservation_" .. tostring(state.nextReservationId)
	state.reservations[reservationId] = {
		reservationId = reservationId,
		recipeId = recipeId,
		allocations = allocations,
		createdAt = now,
		expiresAt = now + math.max(1, ttl),
	}
	return reservationId
end

function InventoryMath.commit(state: any, reservationId: string, now: number): string?
	ensure(state)
	local reservation = state.reservations[reservationId]
	if typeof(reservation) ~= "table" or (tonumber(reservation.expiresAt) or 0) <= now then
		InventoryMath.release(state, reservationId)
		return nil
	end
	local recipeId = tostring(reservation.recipeId)
	local lots = lotsFor(state, recipeId)
	local byId: { [string]: any } = {}
	for _, lot in lots do
		byId[tostring(lot.lotId)] = lot
	end
	for _, allocation in reservation.allocations or {} do
		local lot = byId[tostring(allocation.lotId)]
		local quantity = math.max(0, tonumber(allocation.quantity) or 0)
		if not lot or (tonumber(lot.quantity) or 0) < quantity then
			InventoryMath.release(state, reservationId)
			return nil
		end
	end
	for _, allocation in reservation.allocations or {} do
		local lot = byId[tostring(allocation.lotId)]
		local quantity = math.max(0, tonumber(allocation.quantity) or 0)
		lot.quantity = math.max(0, (tonumber(lot.quantity) or 0) - quantity)
		lot.reserved = math.max(0, (tonumber(lot.reserved) or 0) - quantity)
	end
	state.reservations[reservationId] = nil
	for index = #lots, 1, -1 do
		if (tonumber(lots[index].quantity) or 0) <= 0 then
			table.remove(lots, index)
		end
	end
	return recipeId
end

function InventoryMath.expire(state: any, now: number): { [string]: number }
	ensure(state)
	InventoryMath.releaseExpiredReservations(state, now)
	local spoiled: { [string]: number } = {}
	for recipeId, lots in state.lots do
		if typeof(lots) == "table" then
			for index = #lots, 1, -1 do
				local lot = lots[index]
				if (tonumber(lot.expiresAt) or 0) <= now and (tonumber(lot.reserved) or 0) <= 0 then
					spoiled[recipeId] = (spoiled[recipeId] or 0)
						+ math.max(0, tonumber(lot.quantity) or 0)
					table.remove(lots, index)
				end
			end
		end
	end
	return spoiled
end

function InventoryMath.shiftExpiry(state: any, seconds: number)
	ensure(state)
	seconds = math.max(0, math.floor(seconds))
	if seconds <= 0 then
		return
	end
	for _, lots in state.lots do
		if typeof(lots) == "table" then
			for _, lot in lots do
				lot.producedAt = (tonumber(lot.producedAt) or 0) + seconds
				lot.expiresAt = (tonumber(lot.expiresAt) or 0) + seconds
			end
		end
	end
end

return InventoryMath
