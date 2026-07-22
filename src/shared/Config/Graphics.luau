--!strict
-- Owner-approved graphics. Decal listings are addressed through rbxthumb
-- because their listing IDs are not raw image IDs.
--
-- UI icons are self-uploaded renders of two CC0 packs (docs/ASSET_LICENSES.md):
--   glyphs  - Nieobie Game Icon Pack, github.com/Nieobie/Game-Icon-Pack,
--             pinned commit fb27988095086b3cafa85d070eccb8bc3e993911,
--             rendered white so Theme tints them via ImageColor3;
--   plates  - Kenney UI Pack 2.0 (kenney.nl/assets/ui-pack), grey
--             depth-gloss buttons, tinted warm in Theme.
-- An empty string means "not uploaded yet" and falls back to the code-drawn
-- glyph badge, so the HUD never renders blank.

local function thumbnail(assetId: number): string
	return string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", assetId)
end

-- Roblox renders a preview of any Creator Store asset for us, so catalogue rows
-- can show the real item instead of a coloured letter. Measured 2026-07-22:
-- type=Asset serves ONLY 150x150 and 420x420 — every other size the string
-- accepts silently returns a blank image, so do not "optimise" this number.
local function itemThumbnail(assetId: number): string
	return string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", assetId)
end

local Graphics = {
	SourceAssets = {
		Sidewalk = 2922135969,
		RoadStraight = 17092935,
		RoadLeft = 17093010,
		RoadRight = 17092971,
		WoodFloor = 136501975130226,
		Sky = 4462186698,
		RetroFood = 134670664555156,
	},
	UI = {
		-- Stat pills
		Money = "rbxassetid://80375713494681",
		Reputation = "rbxassetid://75203433466466",
		Buzz = "rbxassetid://120973646100849",
		-- Action dock
		Build = "rbxassetid://89794042167710",
		Cookbook = "rbxassetid://89252167506542",
		Staff = "rbxassetid://125822390757999",
		Upgrades = "rbxassetid://114343896557596",
		Shop = "rbxassetid://98312388730885",
		-- Right rail
		Goals = "rbxassetid://128144538146723",
		Trophies = "rbxassetid://127872459522051",
		Map = "rbxassetid://95010028808469",
		Music = "rbxassetid://130857741918858",
		MusicOff = "rbxassetid://72428685512561",
		Settings = "rbxassetid://78498019750021",
		-- Inventory drawer button
		Pantry = "rbxassetid://114094476715548",
		-- Button plates
		PlateSquare = "rbxassetid://110496594476795",
		PlateRound = "rbxassetid://118639991990376",
	},
	-- Catalogue rows call this with an AssetManifest id to get the item's own
	-- picture.
	ItemThumbnail = itemThumbnail,
	Surfaces = {
		Sidewalk = thumbnail(2922135969),
		RoadStraight = thumbnail(17092935),
		RoadLeft = thumbnail(17093010),
		RoadRight = thumbnail(17092971),
		WoodFloor = thumbnail(136501975130226),
		Sky = thumbnail(4462186698),
	},
}

return table.freeze(Graphics)
