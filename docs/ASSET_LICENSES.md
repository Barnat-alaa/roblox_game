# Asset licences

Every shipped asset (model, texture, image, audio, font) is recorded here with its
source and licence **before** it ships. Code dependencies live in
[../THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

## Current assets
All 3D/UI art is **code-generated greybox** (see docs/ART_DIRECTION.md) — no
imported visual assets. Icon and thumbnail are staged screenshots of our own
game. Audio comes exclusively from Roblox's licensed partner catalogs:

| Asset ID | Name | Type | Creator | Source | Licence | Roblox asset id | Approved for prod |
| --- | --- | --- | --- | --- | --- | --- | --- |
| audio_bell | Desk Bell Counter Service 1 | Audio SFX | ProSoundEffects | Creator Store | Roblox licensed SFX partner catalog (on-platform use) | 9125485591 | ✅ |
| audio_serve | Desk Bell Counter Service 2 | Audio SFX | ProSoundEffects | Creator Store | Roblox licensed SFX partner catalog | 9125485659 | ✅ |
| audio_brew | Blender Water 1 | Audio SFX | ProSoundEffects | Creator Store | Roblox licensed SFX partner catalog | 9113456593 | ✅ |
| audio_music | Cozy Cafe Focus Piano | Audio music | DistrokidOfficial | Creator Store | Roblox licensed-music program (on-platform use) | 97316511727172 | ✅ |

Audio rule: only Roblox partner catalogs (ProSoundEffects, APM,
DistrokidOfficial, Monstercat…) or original/commissioned audio. Community
re-uploads of stock sounds are provenance risks — never ship them.

## Creator Store models (Step S1 — adopted 2026-07-15)

Owner-selected via docs/ASSET_SHOPPING_LIST.md, loaded through
`AssetLibraryService` which **strips every script** (BaseScript/ModuleScript/
Remote/Bindable/Tool/Sound) before use, rescales to the grid footprint, and
keeps the procedural greybox as fallback. All are free Creator Store assets
licensed for on-platform use; IDs pinned in `src/shared/Config/AssetManifest.luau`.

| Our key | Asset ID | Name | Creator | Notes |
| --- | --- | --- | --- | --- |
| furniture:coffee_machine | 122811151607354 | Coffee Machine Espresso | Crazer1Shifteru1Soni | 45 parts, fits 1×1 cell |
| furniture:oven | 2866867999 | Ze pizza oven | Frenzzyy | 358 parts — heavy; scaled to 2×1 footprint (revisit for mobile) |
| furniture:counter | 8509855137 | Counter and Cash Register | oceanicwavss | register included; fits 3×1 |
| furniture:chair_wood | 14269301866 | Realistic Chair | Chuba7 | single mesh, clean |
| prop:Coffee | 5371778048 | Coffee Cup | Think_yDev | counter + diner plate |
| prop:Tea | 6169001071 | Cup of Tea | Jellywelly666 | counter + diner plate |
| prop:Pastry | 9500111031 | [PBR] Croissant | ordinarytyson | counter + diner plate |
| prop:Sandwich | 2528907852 | Sandwich on plate | magaia10 | counter + diner plate |
| customerRig | 7315192066 | Walking and talking NPC | Victional101 | R6 appearance donor |
| customerRig | 7907970704 | Walking NPC | ARISTOKRAT1CHE | R15 appearance donor |
| customerRig | 8243272714 | Mom's NPC | RAMAS_RMZ | R6 appearance donor |
| customerRig | 75156750439794 | NPC Civilian | BlazePixelAce3480 | R6 appearance donor |
| staff:Barista | 139800912587260 | Barista Coffee Shop | Xx_PhoenixVenomTiger | Mia (auto-rejected at load if it fails the walk-joint gate) |
| staff:Cook | 108490018615318 | Chef NPC | TurboTigerByte2002 | Sam · Cook |
| staff:Waiter | 7907970704 | Walking NPC | ARISTOKRAT1CHE | Noah — customer base + navy uniform apron (walk-verified rig policy) |
| staff:Cleaner | 8243272714 | Mom's NPC | RAMAS_RMZ | Pia — customer base + green uniform apron; shop a dedicated maid rig (shopping list #63) |

**Rejected 2026-07-16 (rig policy — cannot walk):**
- `154539270` "Waiter" (SweII) — no native HumanoidRootPart/walk joints; slid
  and teleported in play. AssetLibraryService now auto-rejects any such rig
  (native HRP + ≥4 Motor6D joints required).

**Rejected during vetting (2026-07-15), do NOT adopt:**
- `8678272489` "Miraculous Ladybug Table" — IP-named (copyrighted franchise).
- `17056776920` "Wooden Chair (Doors)" — asset from the game *Doors*.
- `13032279413` "Mug" & `111478068926774` "Kitchen Counter/Prep Table" —
  return "User is not authorized" (not freely licensed to us).
- `10141391344`, `90025178048963`, `76971459946852` — duplicate base rig /
  ragdoll-death or AI-bot scripts; redundant with the four kept rigs.

## Rules (do NOT skip)
- No ripping/decompiling/extracting from any game. No tracing protected artwork.
- No reusing another work's textures, music, SFX, logos, character designs, UI
  icons, identifiable maps, or distinctive fictional recipe names.
- Credit does **not** grant permission. Don't assume old/discontinued games are
  public domain. Never market as an official remake.
- References are analysed into **abstract principles**, then re-created originally.

## Before adding any asset
1. Identify the true original source.
2. Read the licence; confirm it permits our use (commercial, on Roblox).
3. Record the exact version/commit or purchase/commission proof.
4. Add a row above (with poly count + mobile notes) and, for code, a
   THIRD_PARTY_NOTICES entry.
5. For Creator Store models: prefer reputable creators, inspect/disable scripts,
   strip suspicious remotes/obfuscated code, rebuild core gameplay ourselves.

## Sourcing plan
Original assets in Blender/Blockbench; UI in Figma; audio only original/commissioned/
properly licensed via Roblox's permitted systems. AI-assisted meshes are drafts to be
reviewed, simplified, optimised, and ownership-checked — never final art as-is.

## References
- <https://create.roblox.com/docs/production/publishing/dmca-guidelines>
- <https://create.roblox.com/docs/ip-licensing/creators>
- <https://create.roblox.com/docs/production/creator-store>
