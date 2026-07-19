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

## Priorité 4 haul (adopted 2026-07-17, live-verified)

All free Creator Store models, scripts stripped by AssetLibraryService, IDs
pinned in `Config/AssetManifest.luau` (furniture/world sections):

| Our key | Asset ID | Use |
| --- | --- | --- |
| furniture:painting_wall | 100568868323466 | buyable wall art (liftY mount) |
| furniture:menu_board | 105938474697422 | buyable menu board |
| furniture:ceiling_lamp | 98590526337131 | buyable hanging lamp |
| furniture:shelf_plants | 115524597372020 | buyable plant shelf |
| furniture:shelf_wall | 71513583918977 | buyable wall shelf |
| furniture:wall_clock | 121238777618172 | buyable clock (scripts stripped) |
| furniture:curtains | 129812037524677 | buyable window curtains |
| furniture:booth_diner | 8740051429 | buyable seat (87 parts — perf note) |
| furniture:bar_stool | 127833501873867 | buyable seat |
| furniture:coat_rack | 18647331589 | buyable decor |
| furniture:cake_display | 175775615 | buyable display |
| world:flowers / hedge / garden_bench / lantern | 108093169082433 / 128530453132742 / 111807972344737 / 77070881706017 | automatic garden dressing |
| world:tree (11 split variants) | 111344033786189 | gardens + street |
| world:street_lamp / mailbox / hydrant | 96506787384113 / 118252021806923 / 116893320502654 | street furniture |
| world:fountain | 5477511653 | plaza centrepiece (247 parts, single instance) |
| staff:Waiter | 3230955000 | Butler — R15, 15/15 joints, zero scripts |

## UI and neighbourhood graphics (owner-approved 2026-07-19)

The owner added these Creator Store listings to their inventory and explicitly
approved their use in Social Cafe. Decal listing IDs are loaded through
`rbxthumb://type=Asset` because listing IDs are not raw image content IDs.

| Asset ID | Store item | Shipped use | Audit |
| ---: | --- | --- | --- |
| 99176447965360 | Simulator Icon Pack | HUD resources and edge-menu icons | 112 decals, no scripts; only nine selected image IDs ship |
| 6020249531 | Coin Icon | Coin HUD badge | clean single decal |
| 2922135969 | Sidewalk2 | tiled boulevard sidewalks | clean single decal |
| 17092935 | Road - Straight | two-lane boulevard modules | clean single decal |
| 17093010 | Road - Left Turn | west boulevard turn | clean single decal |
| 17092971 | Road - Right Turn | east boulevard turn | clean single decal |
| 136501975130226 | Wooden floor | tiled restaurant floor | clean single decal |
| 4462186698 | Sky | cafe skybox | clean single decal |
| 134670664555156 | Retro Food Pack - Old Roblox Meshes | 14 recipe-specific counter/plate props | 118 meshes; five scripts stripped; only named selections cached |

**Rejected 2026-07-19:**
- `79519710309081` "American Diner Meal Logo Pack Icons USA Food" — 659
  instances, two embedded scripts, and real restaurant brand logos. It is not
  shipped or referenced by source configuration.

**Rejected 2026-07-17:**
- `14466134917` "Black Maid" — incomplete skeleton (13/15 Motor6D), fails the
  walk gate; shop another maid rig (shopping list #63).
- `10014128477` "Updated TrashCan" — 636 parts with a hidden R6 rig inside.

**Rejected 2026-07-16/17 (rig policy — cannot walk correctly):**
- `139800912587260` "Barista Coffee Shop" — 5/6-joint R6 skeleton, limped in
  live measurement; Mia uses a verified walking base + apron instead.

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
