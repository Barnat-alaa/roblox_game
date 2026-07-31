--!strict
-- Floor + wall customisation (B3, owner request 2026-07-31): buy 1×1 floor tiles
-- and wall panels and place them yourself.
--
-- A surface style is a COLOUR × MOTIF pair rather than one flat list, so eight
-- colours and five motifs give forty looks out of thirteen rows of config —
-- adding a colour adds five looks, adding a motif adds eight. Every motif is
-- drawn from plain parts (thin stripes laid over the base slab), so this stays
-- 100% original procedural art with no imported textures (docs/ART_DIRECTION.md).
--
-- Each colour carries its own `ink`: the contrast tone its lines are drawn in.
-- Pairing every motif against one global line colour looked wrong on the dark
-- tones, and letting players pick both would have doubled the UI for no gain.

export type SurfaceColor = {
	id: string,
	name: string,
	base: Color3,
	ink: Color3,
}

export type SurfaceMotif = {
	id: string,
	name: string,
	-- How many stripe bands the renderer draws, and along which axis.
	-- "none"        — the base slab only
	-- "vertical"    — bands across the run (the owner's "vertical lines")
	-- "horizontal"  — bands along the run (the owner's "horizontal lines")
	-- "both"        — a grid of the two
	-- "checker"     — alternating squares
	kind: string,
	bands: number,
}

local Surfaces = {
	enabled = true,

	-- Painting is pay-as-you-go: a tile is charged when you place it, rather than
	-- bought into an inventory first. Stocking hundreds of individual tiles would
	-- have meant an inventory screen nobody wants to manage.
	floorTilePrice = 45,
	wallPanelPrice = 70,

	-- A wall panel is one cell wide and the FULL height of the wall, so panels sit
	-- side by side along a wall the way floor tiles sit on the grid. Painting a
	-- whole wall is several panels, which is what makes mixing motifs possible.
	panelThickness = 0.12,
	tileThickness = 0.12,
	-- The motif sits slightly proud of the base so the two never z-fight.
	motifLift = 0.06,
	motifWidth = 0.55, -- stud width of each drawn line
}

-- Eight colours. Base is the field, ink is the line colour drawn on top of it.
Surfaces.palette = {
	{
		id = "cream",
		name = "Cream",
		base = Color3.fromRGB(245, 237, 221),
		ink = Color3.fromRGB(198, 178, 145),
	},
	{
		id = "sage",
		name = "Sage",
		base = Color3.fromRGB(178, 199, 173),
		ink = Color3.fromRGB(104, 133, 100),
	},
	{
		id = "terracotta",
		name = "Terracotta",
		base = Color3.fromRGB(206, 126, 96),
		ink = Color3.fromRGB(140, 72, 50),
	},
	{
		id = "ocean",
		name = "Ocean",
		base = Color3.fromRGB(126, 168, 196),
		ink = Color3.fromRGB(58, 96, 128),
	},
	{
		id = "charcoal",
		name = "Charcoal",
		base = Color3.fromRGB(84, 86, 92),
		ink = Color3.fromRGB(196, 199, 206),
	},
	{
		id = "blush",
		name = "Blush",
		base = Color3.fromRGB(234, 194, 197),
		ink = Color3.fromRGB(176, 118, 124),
	},
	{
		id = "honey",
		name = "Honey",
		base = Color3.fromRGB(240, 199, 118),
		ink = Color3.fromRGB(170, 122, 48),
	},
	{
		id = "mint",
		name = "Mint",
		base = Color3.fromRGB(180, 224, 208),
		ink = Color3.fromRGB(84, 150, 130),
	},
}

-- Five motifs, including the vertical and horizontal lines the owner asked for.
Surfaces.motifs = {
	{ id = "plain", name = "Plain", kind = "none", bands = 0 },
	{ id = "vlines", name = "Vertical lines", kind = "vertical", bands = 3 },
	{ id = "hlines", name = "Horizontal lines", kind = "horizontal", bands = 3 },
	{ id = "grid", name = "Grid", kind = "both", bands = 2 },
	{ id = "checker", name = "Checker", kind = "checker", bands = 2 },
}

local colorById: { [string]: SurfaceColor } = {}
for _, entry in Surfaces.palette do
	colorById[entry.id] = entry
end
local motifById: { [string]: SurfaceMotif } = {}
for _, entry in Surfaces.motifs do
	motifById[entry.id] = entry
end

function Surfaces.color(id: string): SurfaceColor?
	return colorById[id]
end

function Surfaces.motif(id: string): SurfaceMotif?
	return motifById[id]
end

-- A style is stored as one "colour:motif" string, so a painted cell is a single
-- short value in the save rather than a nested table per cell.
function Surfaces.styleId(colorId: string, motifId: string): string
	return colorId .. ":" .. motifId
end

-- Split a stored style back into its two halves. Returns nil for anything that
-- is not a live colour AND a live motif, so a renamed or removed entry degrades
-- to "unpainted" instead of erroring on every render.
function Surfaces.parse(styleId: string): (SurfaceColor?, SurfaceMotif?)
	local colorId, motifId = string.match(styleId, "^([^:]+):([^:]+)$")
	if not colorId or not motifId then
		return nil, nil
	end
	return colorById[colorId], motifById[motifId]
end

return Surfaces
