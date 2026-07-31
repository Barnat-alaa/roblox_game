--!strict
-- Exterior personalisation (B4, owner request 2026-07-31): the café front is the
-- one thing every neighbour sees from the street, so it gets the deepest
-- customisation in the game — an architectural style, a colour, a motif, a door
-- style, a wood finish, a window shape and a glass tint, all chosen separately.
--
-- Everything multiplies: 3 architectures × 8 colours × 6 motifs × 6 door styles
-- × 6 woods × 3 window shapes × 3 glass tints. Independent axes rather than a
-- flat list of "themes" is what makes two cafés on the same street look different
-- without the config becoming thousands of rows.
--
-- ART: every look is built from plain parts plus Roblox's OWN engine materials
-- (Wood, WoodPlanks, Brick, Concrete…). Nothing is imported, so this stays inside
-- docs/ART_DIRECTION.md — the wood "textures" below are engine material + colour
-- + procedural grain lines, not downloaded images.

export type FacadeColor = { id: string, name: string, base: Color3, trim: Color3 }
export type FacadeMotif = { id: string, name: string, kind: string, bands: number }
export type Architecture = { id: string, name: string, crown: string, blurb: string }
export type DoorStyle = { id: string, name: string, panels: string }
export type DoorWood = {
	id: string,
	name: string,
	base: Color3,
	grain: Color3,
	material: string,
	lines: number,
}
export type WindowShape = { id: string, name: string, shape: string }
export type GlassTint = { id: string, name: string, color: Color3, transparency: number }

local Facade = {
	enabled = true,

	-- Restyling is a one-off purchase per change, cheap enough to experiment with.
	changePrice = 250,

	trimDepth = 0.14, -- how far motif battens/boards stand off the wall
	grainDepth = 0.05, -- how far door grain lines stand off the leaf
}

-- ————— 1. ARCHITECTURE: three genuinely different silhouettes —————
-- `crown` is what replaces the awning band above the door line, which is the
-- part of the front that actually changes the building's read from the street.
Facade.architectures = {
	{
		id = "awning",
		name = "Classic Awning",
		crown = "awning",
		blurb = "Striped canvas awning — the traditional street café",
	},
	{
		id = "gable",
		name = "Cottage Gable",
		crown = "gable",
		blurb = "A pitched roof gable over the door — storybook cottage",
	},
	{
		id = "modern",
		name = "Modern Flat",
		crown = "cornice",
		blurb = "A clean flat cornice and a deep sill — minimal and sharp",
	},
}

-- ————— 2. COLOURS: eight, each with its own trim tone —————
Facade.colors = {
	{
		id = "cream",
		name = "Cream",
		base = Color3.fromRGB(240, 231, 214),
		trim = Color3.fromRGB(186, 166, 134),
	},
	{
		id = "sage",
		name = "Sage",
		base = Color3.fromRGB(163, 188, 160),
		trim = Color3.fromRGB(96, 124, 94),
	},
	{
		id = "terracotta",
		name = "Terracotta",
		base = Color3.fromRGB(198, 116, 88),
		trim = Color3.fromRGB(132, 66, 46),
	},
	{
		id = "navy",
		name = "Navy",
		base = Color3.fromRGB(62, 84, 118),
		trim = Color3.fromRGB(206, 216, 232),
	},
	{
		id = "charcoal",
		name = "Charcoal",
		base = Color3.fromRGB(76, 78, 84),
		trim = Color3.fromRGB(198, 201, 208),
	},
	{
		id = "blush",
		name = "Blush",
		base = Color3.fromRGB(230, 188, 191),
		trim = Color3.fromRGB(168, 110, 116),
	},
	{
		id = "mustard",
		name = "Mustard",
		base = Color3.fromRGB(226, 178, 84),
		trim = Color3.fromRGB(150, 106, 34),
	},
	{
		id = "mint",
		name = "Mint",
		base = Color3.fromRGB(168, 214, 200),
		trim = Color3.fromRGB(74, 138, 120),
	},
}

-- ————— 3. MOTIFS: six, including the vertical and horizontal lines —————
Facade.motifs = {
	{ id = "plain", name = "Plain render", kind = "none", bands = 0 },
	{ id = "battens", name = "Vertical battens", kind = "vertical", bands = 7 },
	{ id = "clapboard", name = "Horizontal boards", kind = "horizontal", bands = 6 },
	{ id = "halftimber", name = "Half-timbered", kind = "both", bands = 4 },
	{ id = "wainscot", name = "Wainscot band", kind = "wainscot", bands = 1 },
	{ id = "pilasters", name = "Pilasters", kind = "pilaster", bands = 2 },
}

-- ————— 4. DOOR STYLES: six —————
-- `panels` is the decorative arrangement welded onto the swinging leaf.
Facade.doorStyles = {
	{ id = "slab", name = "Plain slab", panels = "none" },
	{ id = "two", name = "Two panel", panels = "two" },
	{ id = "four", name = "Four panel", panels = "four" },
	{ id = "arched", name = "Arched top", panels = "arch" },
	{ id = "cottage", name = "Cottage window", panels = "window" },
	{ id = "barn", name = "Barn cross", panels = "cross" },
}

-- ————— 5. WOODS: six finishes that read as different timbers —————
-- Engine material + base colour + grain-line colour and count. Ash is pale with
-- many fine lines; mahogany is dark with few broad ones — that contrast is what
-- makes them read as different species rather than recolours of one plank.
Facade.doorWoods = {
	{
		id = "oak",
		name = "Golden Oak",
		base = Color3.fromRGB(176, 126, 74),
		grain = Color3.fromRGB(140, 94, 52),
		material = "Wood",
		lines = 5,
	},
	{
		id = "walnut",
		name = "Dark Walnut",
		base = Color3.fromRGB(96, 66, 46),
		grain = Color3.fromRGB(62, 40, 27),
		material = "Wood",
		lines = 4,
	},
	{
		id = "pine",
		name = "Pale Pine",
		base = Color3.fromRGB(214, 178, 128),
		grain = Color3.fromRGB(178, 138, 88),
		material = "WoodPlanks",
		lines = 7,
	},
	{
		id = "mahogany",
		name = "Red Mahogany",
		base = Color3.fromRGB(126, 58, 42),
		grain = Color3.fromRGB(88, 36, 26),
		material = "Wood",
		lines = 3,
	},
	{
		id = "ash",
		name = "White Ash",
		base = Color3.fromRGB(226, 212, 188),
		grain = Color3.fromRGB(186, 168, 140),
		material = "WoodPlanks",
		lines = 9,
	},
	{
		id = "ebony",
		name = "Smoked Ebony",
		base = Color3.fromRGB(58, 52, 50),
		grain = Color3.fromRGB(34, 30, 29),
		material = "Wood",
		lines = 4,
	},
}

-- ————— 6. WINDOWS: three shapes × three glass tints —————
Facade.windowShapes = {
	{ id = "square", name = "Squared", shape = "square" },
	{ id = "round", name = "Rounded", shape = "round" },
	{ id = "lozenge", name = "Lozenge", shape = "lozenge" },
}

Facade.glassTints = {
	{ id = "clear", name = "Clear", color = Color3.fromRGB(198, 226, 240), transparency = 0.35 },
	{ id = "sea", name = "Sea green", color = Color3.fromRGB(120, 194, 178), transparency = 0.28 },
	{ id = "amber", name = "Amber", color = Color3.fromRGB(238, 186, 106), transparency = 0.25 },
}

-- The default look, which is what every café has had until now.
Facade.defaults = {
	architecture = "awning",
	color = "cream",
	motif = "plain",
	doorStyle = "slab",
	doorWood = "oak",
	windowShape = "square",
	glass = "clear",
}

-- One lookup per axis, so validation is a table hit rather than a scan.
local function index(list: { any }): { [string]: any }
	local map = {}
	for _, entry in list do
		map[entry.id] = entry
	end
	return map
end

Facade.byId = {
	architecture = index(Facade.architectures),
	color = index(Facade.colors),
	motif = index(Facade.motifs),
	doorStyle = index(Facade.doorStyles),
	doorWood = index(Facade.doorWoods),
	windowShape = index(Facade.windowShapes),
	glass = index(Facade.glassTints),
}

-- Resolve a saved style, falling back per-axis to the default. Per-axis rather
-- than all-or-nothing means removing one entry from the config degrades that one
-- choice instead of resetting somebody's whole café front.
function Facade.resolve(style: any): { [string]: any }
	local out = {}
	for axis, fallback in Facade.defaults do
		local chosen = if typeof(style) == "table" then style[axis] else nil
		local entry = if typeof(chosen) == "string" then Facade.byId[axis][chosen] else nil
		out[axis] = entry or Facade.byId[axis][fallback]
	end
	return out
end

return Facade
