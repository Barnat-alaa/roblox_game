--!strict
-- Sound asset registry. Every id here comes from Roblox's LICENSED partner
-- catalogs (ProSoundEffects, DistroKid via DistrokidOfficial) — provenance
-- and licence are logged per-asset in docs/ASSET_LICENSES.md. Never add a
-- community re-upload here without checking its source first.
local Audio = {
	music = {
		-- "Cozy Cafe Focus Piano" — DistrokidOfficial (Roblox licensed music)
		id = 97316511727172,
		volume = 0.35,
	},
	sfx = {
		bell = {
			-- "Desk Bell Counter Service 1" — ProSoundEffects. Order arrives.
			id = 9125485591,
			volume = 0.55,
		},
		serve = {
			-- "Desk Bell Counter Service 2" — ProSoundEffects. Payout ding.
			id = 9125485659,
			volume = 0.7,
		},
		brew = {
			-- "Blender Water 1" — ProSoundEffects. Coffee machine whirr.
			id = 9113456593,
			volume = 0.45,
		},
	},
}

return Audio
