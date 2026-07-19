--!strict
-- Neighbourhood layout constants. plotCount is THE lobby-capacity knob:
-- Roblox fills servers to Max Players (set on the dashboard) and every player
-- gets one plot, so keep Max Players <= plotCount. Launch tuning: 24 plots /
-- 30 max players is wrong — keep Max Players at or below plotCount (30 → 24
-- means 6 players could go plotless; dashboard is set to 30, so plotCount 30).
--
-- S2 architecture (2026-07-16): every café is a real BUILDING — front facade
-- with an auto-opening door — and owns a fenced PRIVATE GARDEN behind it.
-- The interior starts at ~3x the original floor area and can expand deeper
-- into the garden in tiers (PlayerData.expansionTier; purchase flow lands in
-- S4 — the geometry, data field and rebuild path all exist now).
local World = {
	plotCount = 30, -- total cafés per server (two facing rows)
	plotsPerRow = 15, -- cafés per street side
	boulevardWidth = 60, -- studs between the two facing rows
	plotGap = 12, -- studs between neighbouring plots

	-- Interior depth per expansion tier, in grid cells (width is fixed at
	-- Grid.PLOT_WIDTH). Tier 0 = 18x24 cells = exactly 3x the original
	-- 12x12 floor area. Buying land (S4) moves the back wall into the garden.
	interiorDepthTiers = { 24, 28, 32 },

	-- The front-right corner (from the player's view while entering) is a
	-- staff-only open kitchen. A low L-shaped service counter keeps dining NPCs
	-- out while leaving the preparation theatre visible to the room.
	kitchenWidthCells = 8,
	kitchenDepthCells = 4,
	kitchenDividerHeight = 4.2,

	gardenMinDepth = 40, -- studs of private garden that remain even at max tier
	-- Human-scale walls, paired with an indoor-only jump cap so the room stays
	-- visually open without letting players vault out from tall furniture.
	wallHeight = 12,
	indoorJumpHeight = 3,
	indoorJumpPower = 28,
	-- Keep the decorative pickets friendly-sized, but put a real boundary
	-- behind them so the private garden cannot be used to jump out of the plot.
	gardenBoundaryHeight = 14,
	doorWidth = 6, -- front door gap (wide enough for NPC pathfinding)
	doorHeight = 7,
	gateWidth = 4, -- garden gate gap in the back wall
}

return World
