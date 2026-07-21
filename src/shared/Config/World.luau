--!strict
-- Neighbourhood layout constants. plotCount is THE lobby-capacity knob:
-- Roblox fills servers to Max Players (set on the dashboard) and every player
-- gets one plot, so Max Players MUST be <= plotCount.
--
-- 2026-07-21: the lobby was cut from 30 cafés to 10 (owner request). Scale is
-- handled the way Roblox intends — not by a bigger server, but by MORE servers:
-- Roblox spawns a fresh instance whenever the current one fills, so total
-- concurrent players is unbounded while each street stays a readable 10.
-- ⚠️ The dashboard Max Players must be set to 10 to match. It is NOT settable
-- from code, and a mismatch strands the surplus players with no café at all
-- (CafeService.Start warns about this at boot, and now queues them for the
-- next café that frees up).
--
-- INVARIANT: plotCount == plotsPerRow * 2 — the street is two facing rows, and
-- plotOriginFor wraps its column index modulo plotsPerRow, so any extra plot
-- would silently stack a second café on an existing origin. CafeService
-- asserts this at boot and tests/StreetMath.spec.luau covers it.
--
-- S2 architecture (2026-07-16): every café is a real BUILDING — front facade
-- with an auto-opening door — and owns a fenced PRIVATE GARDEN behind it.
-- The interior starts at ~3x the original floor area and can expand deeper
-- into the garden in tiers (PlayerData.expansionTier; purchase flow lands in
-- S4 — the geometry, data field and rebuild path all exist now).
local World = {
	plotCount = 10, -- total cafés per server; MUST equal plotsPerRow * 2
	plotsPerRow = 5, -- cafés per street side
	boulevardWidth = 60, -- studs between the two facing rows
	plotGap = 12, -- studs between neighbouring plots
	-- Width of the tiled road running down the middle of the boulevard. What is
	-- left of boulevardWidth after the road is split into the two sidewalks, so
	-- this is the single source of truth for both the road tiles CafeService
	-- lays down and the pedestrian lanes in Utilities/StreetMath.
	roadWidth = 24,

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
	mapBoundaryHeight = 42,
	mapSafetyMargin = 6,
	doorWidth = 6, -- front door gap (wide enough for NPC pathfinding)
	doorHeight = 7,
	-- Front-door centre as a fraction of plot width. VERIFIED in Studio
	-- (2026-07-21): the player enters facing local +Z, and with Up=+Y that puts
	-- their RIGHT at LOW local X and their LEFT at HIGH local X. So 0.7 (local
	-- X 50.4 of 72) is the owner-facing "door more to the LEFT" they asked for,
	-- and the kitchen at cells 0-7 is correctly the front-RIGHT corner.
	-- Do NOT flip this to 0.3 — that would move the door to the right.
	doorCenterFrac = 0.7,
	gateWidth = 4, -- garden gate gap in the back wall
}

return World
