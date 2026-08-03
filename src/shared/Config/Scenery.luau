--!strict
-- Horizon, shoreline and sun tuning (owner request 2026-08-03: "make the horizon
-- better looking and make the edges of the map look like a beach that leads to an
-- infinite sea… add a sun with reflections so the game feels more vibrant").
--
-- Everything here is scenery. Nothing in this file affects the simulation, so it
-- is safe to tune live — but `beachEnabled` exists so the whole shoreline can be
-- switched off in one place if it ever costs too much on a phone.
--
-- HOW THE SHORELINE IS SHAPED
--
-- The island used to end in a hard 1.9-stud drop straight into a flat water slab,
-- which is what read as a cut-out edge. Instead it now steps down and outward in
-- rings that each get WIDER and DEEPER than the last:
--
--     width(i) = firstRingWidth * ringWidthGrowth^i
--     drop(i)  = firstRingDrop  * ringDropGrowth^i
--
-- Growing both is what produces a real coastal profile from one small loop: fine
-- steps in the shallows where the eye can resolve them, then a shelf that falls
-- away fast so the water darkens with distance instead of staying a uniform
-- paddling-pool blue. The last ring's height becomes the seabed, so there is no
-- cliff anywhere — the beach IS the seabed, continued.
--
-- The water is deliberately semi-transparent: the colour you see is the sand or
-- seabed underneath it, which is what makes shallows read turquoise and open
-- water read deep. Making the water opaque again would flatten the whole effect.

export type SceneryConfig = {
	beachEnabled: boolean,
	seaLevel: number,
	apronWidth: number,
	ringCount: number,
	seaHalfExtent: number,
	seaTileSpan: number,
	firstRingWidth: number,
	ringWidthGrowth: number,
	firstRingDrop: number,
	ringDropGrowth: number,
	ringThickness: number,
	sandDry: Color3,
	sandWet: Color3,
	seabedColor: Color3,
	seaColor: Color3,
	seaTransparency: number,
	seaReflectance: number,
	sunAngularSize: number,
	sunRaysIntensity: number,
	sunRaysSpread: number,
	bloomIntensity: number,
	bloomSize: number,
	bloomThreshold: number,
	saturation: number,
	contrast: number,
	tint: Color3,
	atmosphereDensity: number,
	atmosphereHaze: number,
	atmosphereGlare: number,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
}

local Scenery: SceneryConfig = {
	beachEnabled = true,

	-- Must match the Sea part's surface height in CafeService; rings above this
	-- are dry sand, rings below are wet sand seen through the water.
	seaLevel = -2.6,

	-- A walkable band of sand just inside the map boundary, so the ground you can
	-- actually stand on turns to beach before the water rather than ending in
	-- grass. Sits a hair ABOVE the grass so it wins the depth test outright —
	-- the same ordering trap that once let grass bleed up through the road.
	apronWidth = 46,

	-- The descending shoreline, outside the boundary walls.
	--
	-- Kept SHORT on purpose. These are nested rectangles, so their corners stack
	-- into a 45° staircase, and because water colour follows depth that staircase
	-- draws a diagonal line across the sea toward the horizon. A screenshot with
	-- nine rings spread over 800 studs made it an unmistakable straight scar. Five
	-- rings inside ~190 studs put the whole gradient in the band hugging the
	-- beach, where a drop-off contour is what a real shore looks like anyway, and
	-- everything past it is open water at one depth with nothing to draw a line.
	ringCount = 5,
	firstRingWidth = 16,
	ringWidthGrowth = 1.45,
	firstRingDrop = 0.7,
	ringDropGrowth = 2.0,
	-- Each ring is a deep slab so its underside always clears the next ring down;
	-- a thin one would show daylight under its lip at grazing angles.
	ringThickness = 80,

	sandDry = Color3.fromRGB(240, 220, 178),
	sandWet = Color3.fromRGB(198, 172, 136),
	seabedColor = Color3.fromRGB(16, 56, 86),

	-- A Roblox part is capped at 2048 studs PER AXIS, silently. The sea was
	-- declared 8000 wide for months and was really a 2048 square with a hard edge
	-- just past the island — a good part of why the map looked cut out. The water
	-- and seabed are therefore TILED to cover this half-extent, which has to stay
	-- comfortably beyond the shoreline's outermost ring (~570 studs at
	-- ringCount 5) or bare sand shows past the water's edge.
	seaHalfExtent = 4000,
	seaTileSpan = 2000,

	seaColor = Color3.fromRGB(52, 130, 176),
	-- Transparent enough to read the sand and seabed through — that is where the
	-- shallow/deep gradient comes from.
	seaTransparency = 0.28,
	-- Reflectance is what puts the SUN on the water: the surface picks up the sky
	-- box, including the sun disc, and turns it into a moving highlight.
	seaReflectance = 0.24,

	sunAngularSize = 21,
	sunRaysIntensity = 0.24,
	sunRaysSpread = 0.9,
	bloomIntensity = 0.7,
	bloomSize = 26,
	bloomThreshold = 1.15,

	-- A light grade rather than a filter: enough to lift the greens and the water,
	-- not enough to tint faces or make the UI look sunburnt.
	saturation = 0.14,
	contrast = 0.07,
	tint = Color3.fromRGB(255, 251, 244),

	-- Haze is the horizon: it stops the far edge of the water reading as a straight
	-- cut and dissolves it into the sky. Pulled back from 0.29/0.85 after a test
	-- shot — that much washed the colour out of the cafés down the street, not
	-- just the sea, and the street is where the game is actually played.
	atmosphereDensity = 0.24,
	atmosphereHaze = 0.55,
	atmosphereGlare = 0.22,
	atmosphereColor = Color3.fromRGB(203, 216, 232),
	atmosphereDecay = Color3.fromRGB(146, 152, 160),
}

return table.freeze(Scenery)
