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
	-- SERVED THROUGH THE THUMBNAIL PIPE, not the raw asset id (2026-08-06).
	--
	-- Every one of these rendered as a text letter on the owner's device for three
	-- rounds. The assets were never the problem: checked against Roblox's APIs
	-- they are AssetTypeId 1 (real Images, not Decals), created by the owner's own
	-- account, and thumbnail state "Completed" — approved, unmoderated, present.
	--
	-- What settled it was the owner's own screenshot: the ROAD and SIDEWALK
	-- textures were rendering in the same frame as the letters. Those go through
	-- `thumbnail()` (rbxthumb://); these went through raw `rbxassetid://`. Same
	-- game, same client, same instant — one scheme worked and the other did not,
	-- which is the signature of a PRIVATE image the client is not entitled to
	-- fetch directly. Roblox serves the rendered thumbnail of an approved asset
	-- publicly, so the same artwork arrives that way.
	--
	-- Keep new HUD art on `thumbnail()` for the same reason.
	UI = {
		-- Stat pills
		Money = thumbnail(138291685268649),
		Reputation = thumbnail(106159084202396),
		Buzz = thumbnail(105443225474473),
		-- Action dock
		Build = thumbnail(111961056777489),
		Cookbook = thumbnail(78909102358565),
		Staff = thumbnail(130832227566122),
		Upgrades = thumbnail(98681656717864),
		Shop = thumbnail(114379023520936),
		Market = thumbnail(90121225847460),
		-- Right rail
		Goals = thumbnail(72112954485657),
		Trophies = thumbnail(137488539860322),
		Map = thumbnail(78785839275091),
		Music = thumbnail(96404039920666),
		MusicOff = thumbnail(88490987948549),
		Settings = thumbnail(101966431239256),
		-- Inventory drawer button
		Pantry = thumbnail(114094476715548),
		-- Spare art from the owner's sheet, not on the HUD yet
		Coins = thumbnail(106117241055513),
		-- Same asset under the SINGULAR key. Theme.Glyphs calls it `Coin` and the
		-- HUD resolves icons dynamically via Theme.Images[def.key], so a definition
		-- keyed "Coin" was silently missing its image and falling back to the "$"
		-- text glyph. tests/Graphics.spec asserts the singular; both now resolve.
		Coin = thumbnail(106117241055513),
		Rankings = thumbnail(99014737661924),
		-- Button plates
		PlateSquare = thumbnail(110496594476795),
		PlateRound = thumbnail(118639991990376),
	},
	-- Icons that carry their OWN colour and must never be tinted. The rest are
	-- flat single-colour glyphs that Theme recolours per surface, so tinting is
	-- opt-out rather than blanket.
	UIFullColour = {
		Money = true,
		Reputation = true,
		Buzz = true,
		Build = true,
		Cookbook = true,
		Staff = true,
		Upgrades = true,
		Shop = true,
		Market = true,
		Goals = true,
		Trophies = true,
		Map = true,
		Music = true,
		MusicOff = true,
		Settings = true,
		Coins = true,
		Coin = true, -- singular alias; same approved asset
		Rankings = true,
	},
	-- Catalogue rows call this with an AssetManifest id to get the item's own
	-- picture.
	ItemThumbnail = itemThumbnail,
	-- One icon per dish, keyed by Config/Recipes id. Kenney Food Kit 2.0 (CC0)
	-- flat renders, self-uploaded — the fix docs/HUD_REDESIGN.md §4.3 called for.
	-- The 14 dishes are meshes inside one packaged model, so they have no
	-- individual Creator Store id to render a thumbnail from; these give each
	-- dish its own picture instead of four shared category photos.
	Dishes = {
		espresso = "rbxassetid://80930338989723",
		cappuccino = "rbxassetid://85121371995613",
		tea = "rbxassetid://87677406983122",
		croissant = "rbxassetid://98503280270358",
		sandwich = "rbxassetid://124917609220287",
		latte = "rbxassetid://120609673339594",
		muffin = "rbxassetid://116845304850777",
		iced_tea = "rbxassetid://102246519602825",
		fruit_salad = "rbxassetid://95586842311547",
		mocha = "rbxassetid://138226741866127",
		cinnamon_roll = "rbxassetid://131649668281254",
		club_sandwich = "rbxassetid://85863668096370",
		slow_roast = "rbxassetid://137686512001808",
		quiche = "rbxassetid://137520402102940",
	},
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
