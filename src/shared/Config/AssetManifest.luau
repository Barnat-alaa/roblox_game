--!strict
-- Creator Store asset manifest (Step S1). Maps our logical asset keys to the
-- Roblox Creator Store IDs the owner picked, so AssetLibraryService can load,
-- sanitise (strip ALL scripts), rescale and cache them at boot — with the
-- procedural greybox always kept as fallback. Every ID here is logged in
-- docs/ASSET_LICENSES.md. Nothing that failed vetting (IP-named, unauthorised,
-- ragdoll/death scripts, duplicates) is listed. See docs/ASSET_SHOPPING_LIST.md.

export type FurnitureAsset = {
	assetId: number,
	name: string,
	-- Scale by TARGET HEIGHT (studs) to preserve real-world proportions, then
	-- clamp the horizontal span so nothing overflows its grid footprint.
	height: number,
	maxSpan: number, -- max horizontal studs after scaling (grid footprint cap)
	yaw: number?, -- degrees added at placement to align the imported model's visible front
	liftY: number?, -- studs above the floor (wall art, clocks, hanging lamps)
	flat: boolean?, -- rugs/mats: scale by SPAN (not height) and lay the thin axis down
}

export type WorldAsset = {
	assetId: number,
	name: string,
	height: number, -- target height in studs
	split: boolean?, -- pack: cache each child model as a separate variant
}

export type PropAsset = {
	assetId: number,
	name: string,
	fit: number, -- longest-axis target in studs (small tabletop props)
}

export type RetroPropSelection = {
	sourceName: string,
	fit: number,
}

local AssetManifest = {
	-- Furniture: replaces the matching catalogId's procedural builder when the
	-- template loads. Keys MUST match Config/Furniture catalog ids. Heights are
	-- chosen so pieces read at a consistent human scale (a seated customer is
	-- ~5 studs; chair seat ~1.6, counter ~3.8, oven a taller hero piece).
	furniture = {
		coffee_machine = {
			assetId = 122811151607354,
			name = "Coffee Machine Espresso (Crazer1Shifteru1Soni)",
			height = 3.6,
			maxSpan = 4.6,
		},
		oven = {
			assetId = 2866867999,
			name = "Ze pizza oven (Frenzzyy)",
			height = 5.2,
			maxSpan = 8,
		},
		counter = {
			assetId = 8509855137,
			name = "Counter and Cash Register (oceanicwavss)",
			height = 3.8,
			maxSpan = 12,
			yaw = 90, -- native long axis is on Z; rotate it onto the 3-cell X span
		},
		chair_wood = {
			assetId = 14269301866,
			name = "Realistic Chair (Chuba7)",
			height = 3.3,
			maxSpan = 3.4,
			yaw = 180, -- native back is -Z; flip it to match the game's +Z chair back
		},
		-- Priorité 4 interior (owner haul 2026-07-17):
		painting_wall = {
			assetId = 100568868323466,
			name = "Desert Painting (owner pick)",
			height = 3.2,
			maxSpan = 7.4,
			liftY = 4.6,
		},
		menu_board = {
			assetId = 105938474697422,
			name = "Cafe Menu Board",
			height = 4.2,
			maxSpan = 3.6,
		},
		ceiling_lamp = {
			assetId = 98590526337131,
			name = "Ceiling Lamp Modern",
			height = 1.9,
			maxSpan = 3.4,
			liftY = 8.2,
		},
		shelf_plants = {
			assetId = 115524597372020,
			name = "Garden Shelf Decor",
			height = 5.2,
			maxSpan = 7.4,
		},
		shelf_wall = {
			assetId = 71513583918977,
			name = "Wall Shelf Bookshelf",
			height = 2.6,
			maxSpan = 7.4,
			liftY = 4.6,
		},
		wall_clock = {
			assetId = 121238777618172,
			name = "Regulator Wall Clock",
			height = 3.4,
			maxSpan = 3.4,
			liftY = 5.6,
		},
		curtains = {
			assetId = 129812037524677,
			name = "Window Curtains",
			height = 5,
			maxSpan = 7.4,
			liftY = 2.6,
		},
		booth_diner = {
			assetId = 8740051429,
			name = "Diner Booth",
			height = 3.6,
			maxSpan = 11.4,
		},
		bar_stool = {
			assetId = 127833501873867,
			name = "Bar Stool",
			height = 2.6,
			maxSpan = 3.2,
		},
		coat_rack = {
			assetId = 18647331589,
			name = "Coat Hanger",
			height = 4.6,
			maxSpan = 3.2,
		},
		cake_display = {
			assetId = 175775615,
			name = "Cake Display Case",
			height = 2.9,
			maxSpan = 7.4,
		},
		-- Owner haul 2026-07-19 — the last 5 greybox shop items get real models.
		prep_station = {
			assetId = 100119851703802,
			name = "Kitchen Counter/Prep (owner pick)",
			height = 3.6,
			maxSpan = 7.6,
		},
		table_round = {
			assetId = 2052055475,
			name = "Glass Table (owner pick)",
			height = 3,
			maxSpan = 7.4,
		},
		plant_small = {
			assetId = 111366669245364,
			name = "Low Poly Potted Plant",
			height = 3.4,
			maxSpan = 3.4,
		},
		lamp_floor = {
			assetId = 101194656934237,
			name = "Floor Lamp (owner pick)",
			height = 4.8,
			maxSpan = 3.2,
		},
		rug_round = {
			assetId = 12141085266,
			name = "KotSS Carpet (owner pick)",
			height = 0.4,
			maxSpan = 7.6,
			flat = true,
		},
	} :: { [string]: FurnitureAsset },

	-- World dressing (garden + street + plaza), applied automatically by
	-- CafeService — not buyable items. Procedural fallback everywhere.
	world = {
		flowers = { assetId = 108093169082433, name = "Plants and Flowers pack", height = 2.6 },
		hedge = { assetId = 128530453132742, name = "Remastered Bush", height = 3.4 },
		garden_bench = { assetId = 111807972344737, name = "Low Poly Bench", height = 3.2 },
		lantern = { assetId = 77070881706017, name = "Lamp post (owner pick)", height = 9 },
		tree = {
			assetId = 111344033786189,
			name = "Low Poly Tree Pack",
			height = 11,
			split = true,
		},
		street_lamp = { assetId = 96506787384113, name = "Low Poly Lamppost", height = 11 },
		mailbox = { assetId = 118252021806923, name = "Mailbox Classic", height = 4 },
		fountain = { assetId = 5477511653, name = "Fancy fountain with benches", height = 12 },
		hydrant = { assetId = 116893320502654, name = "Fire Hydrant", height = 2.8 },
	} :: { [string]: WorldAsset },

	-- Single-instance decor loaded by ID for a specific feature (not buyable,
	-- not auto-dressed). Scaled by `fit` (longest axis) so FLAT meshes stay
	-- flat. AssetLibraryService exposes GetDecor(key).
	decor = {
		-- Replaces the procedural brown splat with a real spill mesh (dirt).
		dirt = { assetId = 9738324539, name = "Spill puddle MeshPart", fit = 3.4 },
		-- Neon "Coffee Cup" sign mounted on each café's exterior facade.
		cafe_sign = {
			assetId = 83710614887731,
			name = "Neon Coffee Cup Sign (owner pick)",
			fit = 4.5,
		},
	} :: { [string]: PropAsset },

	-- Food/drink props, keyed by recipe CATEGORY, shown on counters and diner
	-- plates in place of the old coloured cylinders.
	props = {
		Coffee = {
			assetId = 134685565050613,
			name = "Coffee packaging cup (owner pick)",
			fit = 1.4,
		},
		Tea = { assetId = 6169001071, name = "Cup of Tea (Jellywelly666)", fit = 1.3 },
		Pastry = { assetId = 9500111031, name = "[PBR] Croissant (ordinarytyson)", fit = 1.6 },
		Sandwich = { assetId = 2528907852, name = "Sandwich on plate (magaia10)", fit = 1.8 },
	} :: { [string]: PropAsset },

	-- The owner-approved retro pack is a 118-mesh model, not a set of flat UI
	-- icons. AssetLibraryService loads it once, strips its five scripts, and
	-- extracts only these small food meshes as recipe-specific counter/plate
	-- props. Existing category props remain the fallback if the pack fails.
	retroPropPack = {
		assetId = 134670664555156,
		name = "Retro Food Pack - Old Roblox Meshes",
		recipes = {
			espresso = { sourceName = "Starblox Coffee", fit = 1.3 },
			cappuccino = { sourceName = "Hot Chocolate With Marshmellow Faces", fit = 1.3 },
			tea = { sourceName = "Teapot", fit = 1.35 },
			croissant = { sourceName = "8-bit Donut", fit = 1.5 },
			sandwich = { sourceName = "Cheeseburger", fit = 1.7 },
			latte = { sourceName = "Chocolate Milk", fit = 1.3 },
			muffin = { sourceName = "Muffin", fit = 1.45 },
			iced_tea = { sourceName = "Bloxiade", fit = 1.3 },
			fruit_salad = { sourceName = "Fruit Bowl", fit = 1.65 },
			mocha = { sourceName = "Hot Chocolate", fit = 1.3 },
			cinnamon_roll = { sourceName = "Pancakes", fit = 1.5 },
			club_sandwich = { sourceName = "Double Cheeseburger", fit = 1.75 },
			slow_roast = { sourceName = "Pirate Cup", fit = 1.35 },
			quiche = { sourceName = "Apple Pie", fit = 1.55 },
		} :: { [string]: RetroPropSelection },
	},

	-- Customer appearance donors: real clothed rigs (R6/R15). One is picked at
	-- random per walk-in; our name tag + order bubble + walk logic are attached.
	customerRigs = {
		{ assetId = 7315192066, name = "Walking and talking NPC (Victional101)" },
		{ assetId = 7907970704, name = "Walking NPC (ARISTOKRAT1CHE)" },
		{ assetId = 8243272714, name = "Mom's NPC (RAMAS_RMZ)" },
		{ assetId = 75156750439794, name = "NPC Civilian (BlazePixelAce3480)" },
	},

	-- Staff rigs, keyed by our crew role. POLICY (owner, 2026-07-16): staff use
	-- only rigs proven to WALK correctly — the modern bases the customers use.
	-- The old "waiter" kit (154539270) slid/teleported and is permanently
	-- rejected. Waiter/Cleaner borrow customer bases and get a role-coloured
	-- uniform apron on top (StaffService); shop dedicated rigs later via
	-- docs/ASSET_SHOPPING_LIST.md. Any rig that fails the walk-capability gate
	-- in AssetLibraryService falls back to the procedural chibi.
	staff = {
		-- The barista kit (139800912587260) had a 5/6-joint skeleton and
		-- limped — rejected by the walk gate; Mia uses a verified base + apron.
		Barista = { assetId = 7315192066, name = "Walking NPC base (Victional101)" },
		Cook = { assetId = 108490018615318, name = "Chef NPC (TurboTigerByte2002)" },
		-- Butler: R15, complete 15/15 skeleton, zero scripts — Noah's real look.
		Waiter = { assetId = 3230955000, name = "Butler (Verdonis)" },
		-- The maid rig (14466134917) is R15 with 13/15 joints — only the two
		-- ankles are missing, so hips+knees still drive a clean walk. Accepted
		-- 2026-07-19 (the walk gate was relaxed to allow missing ankles).
		Cleaner = { assetId = 14466134917, name = "Black Maid (owner pick)" },
	},
}

return AssetManifest
