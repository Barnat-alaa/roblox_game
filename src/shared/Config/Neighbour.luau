--!strict
-- Helping a neighbour by WORKING (P2c). Helping is no longer a button on a card:
-- you walk INSIDE a neighbour's café and do the real jobs — scrub the floor,
-- clear a dirty plate, run an order from the shelf to the table. Those actions
-- were gated to the café OWNER; they are now open to a visitor standing in the
-- room, and each one PAYS the helper.
--
-- The owner keeps everything their café earns (the sale, the Buzz, the
-- satisfaction). The helper is paid a separate fee out of nothing — it is a
-- reward for showing up, not a cut of the till — so helping can never drain the
-- café you are helping. That is what keeps this co-operative rather than a way
-- to farm a friend's shop.
local Neighbour = {
	enabled = true,

	-- Coins paid to the HELPER per action done in a neighbour's café. Serving is
	-- worth most: it is several steps (fetch from the shelf, carry, deliver to the
	-- right table) and it is the action that actually rescues a waiting customer.
	payPerAction = {
		clean_floor = 10,
		clean_plate = 12,
		serve = 22,
	},
	defaultPay = 10,

	-- Anti-farm, per helper per NEIGHBOUR per day. Past the cap the actions still
	-- WORK — you can keep helping a friend all day — they simply stop paying, so
	-- there is no incentive to camp one café. Replaces the old once-per-action-
	-- per-day HELP_ACTIONS lock, which only allowed 4 taps total.
	maxPaidActionsPerNeighbourPerDay = 15,

	-- First paid help of the day at ANY neighbour, once daily (the old Good
	-- Neighbour bonus, kept).
	goodNeighbourBonus = 25,

	-- Friendship points per paid action (PlayerData.social.friendship).
	friendshipPerAction = 1,

	-- The helper must be INSIDE the café, not shouting from the pavement.
	-- Grid.distanceToPlotRect is 0 anywhere inside the plot, so this is a small
	-- tolerance around the footprint rather than a radius from the centre.
	insideTolerance = 4,
}

return Neighbour
