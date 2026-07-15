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
	yaw: number?, -- degrees to rotate so the model's long axis aligns to +X
}

export type PropAsset = {
	assetId: number,
	name: string,
	fit: number, -- longest-axis target in studs (small tabletop props)
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
		},
	} :: { [string]: FurnitureAsset },

	-- Food/drink props, keyed by recipe CATEGORY, shown on counters and diner
	-- plates in place of the old coloured cylinders.
	props = {
		Coffee = { assetId = 5371778048, name = "Coffee Cup (Think_yDev)", fit = 1.3 },
		Tea = { assetId = 6169001071, name = "Cup of Tea (Jellywelly666)", fit = 1.3 },
		Pastry = { assetId = 9500111031, name = "[PBR] Croissant (ordinarytyson)", fit = 1.6 },
		Sandwich = { assetId = 2528907852, name = "Sandwich on plate (magaia10)", fit = 1.8 },
	} :: { [string]: PropAsset },

	-- Customer appearance donors: real clothed rigs (R6/R15). One is picked at
	-- random per walk-in; our name tag + order bubble + walk logic are attached.
	customerRigs = {
		{ assetId = 7315192066, name = "Walking and talking NPC (Victional101)" },
		{ assetId = 7907970704, name = "Walking NPC (ARISTOKRAT1CHE)" },
		{ assetId = 8243272714, name = "Mom's NPC (RAMAS_RMZ)" },
		{ assetId = 75156750439794, name = "NPC Civilian (BlazePixelAce3480)" },
	},

	-- Staff rigs, keyed by our crew role.
	staff = {
		Barista = { assetId = 139800912587260, name = "Barista Coffee Shop (Xx_PhoenixVenomTiger)" },
		Waiter = { assetId = 154539270, name = "Waiter (SweII)" },
		Cleaner = { assetId = 108490018615318, name = "Chef NPC (TurboTigerByte2002)" },
	},
}

return AssetManifest
