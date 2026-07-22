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
| 99176447965360 | Simulator Icon Pack | ~~HUD resources and edge-menu icons~~ **retired 2026-07-22**, see below | 112 decals, no scripts; script audit only, never a provenance audit |
| 6020249531 | Coin Icon | ~~Coin HUD badge~~ **retired 2026-07-22** (replaced by the CC0 coin below) | clean single decal |
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

## HUD icons — self-uploaded CC0 renders (adopted 2026-07-22)

The chunky-icon HUD (`docs/HUD_REDESIGN.md`) draws every image from two **CC0
1.0** packs, rendered locally and **self-uploaded by the owner**, so the account
that holds the assets is the account that ships them. Attribution burden: none.
Licences were re-read at adoption, not taken from the earlier research pass.

| Pack | Source | Licence | Verified how (2026-07-22) |
| --- | --- | --- | --- |
| **Nieobie Game Icon Pack** | <https://github.com/Nieobie/Game-Icon-Pack> pinned at commit `fb27988095086b3cafa85d070eccb8bc3e993911` | CC0 1.0 Universal | Cloned the repo and read `LICENSE` directly — it contains the full CC0 1.0 legal deed, not a README claim |
| **Kenney UI Pack 2.0** | <https://kenney.nl/assets/ui-pack> (`kenney_ui-pack.zip`, created 12-06-2024) | CC0 1.0 Universal | `License.txt` inside the downloaded zip: "License: (Creative Commons Zero, CC0)… free to use in personal, educational and commercial projects". Site-wide terms at <https://kenney.nl/support> confirm "Attribution is not required" |

**Preparation.** Nieobie glyphs are the `svg/padding` variants rendered to
256×256 PNG with `fill` forced to white, so `Theme.Hud.IconTint` recolours them
per-surface via `ImageColor3` rather than shipping one PNG per colour. Kenney
plates are the **Grey** `button_square_depth_gloss` / `button_round_depth_gloss`
vectors at 256×256, tinted warm in `Theme` so the cool default never fights the
maroon/oak palette. Rendering and recolouring are both permitted by CC0.

Kenney asks that his **logo** not be reused; that is a trademark reservation and
does not constrain the art. No logo ships.

| Our key | Roblox asset id | Pack | Source file |
| --- | ---: | --- | --- |
| `UI.Money` | 80375713494681 | Nieobie | `2-items/coin.svg` |
| `UI.Reputation` | 75203433466466 | Nieobie | `12-misc/five-pointed-star.svg` |
| `UI.Buzz` | 120973646100849 | Nieobie | `4-nature/fire.svg` |
| `UI.Build` | 89794042167710 | Nieobie | `2-items/hammer.svg` |
| `UI.Cookbook` | 89252167506542 | Nieobie | `2-items/book.svg` |
| `UI.Staff` | 125822390757999 | Nieobie | `8-ui/user-group.svg` |
| `UI.Upgrades` | 114343896557596 | Nieobie | `8-ui/arrow-up-02.svg` |
| `UI.Shop` | 98312388730885 | Nieobie | `6-buildings/shop.svg` |
| `UI.Goals` | 128144538146723 | Nieobie | `6-buildings/target.svg` |
| `UI.Trophies` | 127872459522051 | Nieobie | `1-game/trophy.svg` |
| `UI.Map` | 95010028808469 | Nieobie | `2-items/map.svg` |
| `UI.Music` | 130857741918858 | Nieobie | `9-media/music.svg` |
| `UI.MusicOff` | 72428685512561 | Nieobie | `9-media/no-music.svg` |
| `UI.Settings` | 78498019750021 | Nieobie | `8-ui/settings.svg` |
| `UI.Pantry` | 114094476715548 | Nieobie | `2-items/chest.svg` |
| `UI.PlateSquare` | 110496594476795 | Kenney UI Pack | `Vector/Grey/button_square_depth_gloss.svg` |
| `UI.PlateRound` | 118639991990376 | Kenney UI Pack | `Vector/Grey/button_round_depth_gloss.svg` |

All seventeen were confirmed rendering in a live playtest (`IsLoaded == true` on
every HUD image), so none landed Restricted under the 2026-05-05 Asset Privacy
default. `Components.Icon` still falls back to a code-drawn glyph badge if an
image ever fails to load.

### Retired 2026-07-22 — Simulator Icon Pack `99176447965360`

The nine HUD icons previously drawn from this pack are **no longer referenced by
any source file**; `Graphics.UI` now points exclusively at the CC0 uploads above.
This deliberately retires the provenance risk recorded in
`docs/HUD_REDESIGN.md` §4.5: the pack is published on the Creator Store three
times with byte-identical descriptions, each claiming originality, with no
findable artist footprint — and a Creator Store licence cannot warrant rights
the uploader never held. Nothing was mixed: all thirteen HUD icons moved at once,
because mismatched corner radii read badly side by side in one toolbar.

The pack's row remains in the table above as history; it is no longer shipped.

**Rejected for the HUD (2026-07-21 research, re-affirmed at adoption):**
game-icons.net (CC BY 3.0, per-author attribution, 6 credits forever) ·
OpenMoji (CC BY-**SA**, recolouring forces SA re-release) · Noto Emoji
("**most**" resources Apache 2.0 — cannot assert per-image coverage) · CraftPix
free (licence forbids redistribution, conflicts with uploading to Roblox) ·
Lucide (dual ISC+MIT, thin outlines) · Filwarka "2D Roblox Food Icons"
(itch.io blocked licence verification — **UNVERIFIED**, do not adopt).

## Catalogue item pictures (2026-07-22) — no new assets needed

Shop rows, build-placement rows, cookbook cards and pantry rows now show the
**real item**, rendered by Roblox from the Creator Store asset we already ship
(`rbxthumb://type=Asset&id=<id>&w=150&h=150`, built by `Graphics.ItemThumbnail`).
Nothing was uploaded and no new licence applies: these are previews of assets
already recorded in the tables above, generated on demand by Roblox.

**Measured constraints (live, 2026-07-22)** — do not "optimise" these away:

| Fact | Detail |
| --- | --- |
| Valid `type=Asset` sizes | **Only 150×150 and 420×420.** 48/60/75/100/110/128/140/160/180/250/256/352/512/720 all return a blank image while silently accepting the string. |
| First request is slow | Roblox generates the preview server-side on first ask (seconds). `UIController` warms every furniture + prop thumbnail with `ContentProvider:PreloadAsync` on a background thread at join. |
| No GUI blur exists | `BlurEffect` is a Lighting post-process on the 3D world. With no small thumbnail available to upscale either, the locked-item blur is composited: the same picture drawn 14× at small offsets. 20 blurred rows = 260 ImageLabels = 61 fps. |

### Coverage

| Catalogue | Entries | Real per-item picture? |
| --- | ---: | --- |
| Furniture (buy + place) | 20 | ✅ **20/20** — every catalogue id has a Creator Store model, all verified rendering |
| Recipes / dishes | 14 | ✅ **14/14** — one Kenney Food Kit icon each (see next section) |
| Staff | 4 | ✅ rig thumbnails render, ❌ but no staff panel exists to show them yet |

~~The one real gap: per-dish art.~~ **Closed 2026-07-22 — see below.**

## Dish icons — Kenney Food Kit (CC0), self-uploaded 2026-07-22

The 14 dishes are meshes *inside* one packaged model (`retroPropPack`), so no
dish has a Creator Store id of its own to render a thumbnail from; they shared
four category photos. Each dish now has **its own icon**, which is the fix
`docs/HUD_REDESIGN.md` §4.3 specified.

**Source: Kenney Food Kit 2.0** — <https://kenney.nl/assets/food-kit>,
`kenney_food-kit.zip` (created 26-06-2024). **CC0 1.0**, verified in the zip's
own `License.txt`: *"License: (Creative Commons Zero, CC0)… You can use this
content for personal, educational, and commercial purposes."* No attribution
required; Kenney's logo is not used.

The kit ships a flat 2D render per model in `Previews/` (64×64 PNG, transparent)
— the 3D-model-to-2D-icon step §4.3 describes, already done by the artist. Each
was upscaled to 256px (Lanczos) for upload. Two were modified, which CC0 permits:
`iced_tea` is `soda-glass` hue-rotated from purple to tea colour, and
`cappuccino` uses `cup` because `cup-saucer` renders as an empty plate.

| Recipe id | Dish | Food Kit model | Roblox asset id |
| --- | --- | --- | ---: |
| `espresso` | Espresso | `cup-coffee` | 80930338989723 |
| `cappuccino` | Cappuccino | `cup` | 85121371995613 |
| `tea` | House Tea | `cup-tea` | 87677406983122 |
| `croissant` | Croissant | `croissant` | 98503280270358 |
| `sandwich` | Café Sandwich | `sandwich` | 124917609220287 |
| `latte` | Silky Latte | `mug` | 120609673339594 |
| `muffin` | Berry Muffin | `muffin` | 116845304850777 |
| `iced_tea` | Garden Iced Tea | `soda-glass` (hue-shifted) | 102246519602825 |
| `fruit_salad` | Sunrise Fruit Bowl | `bowl-cereal` | 95586842311547 |
| `mocha` | Velvet Mocha | `frappe` | 138226741866127 |
| `cinnamon_roll` | Cinnamon Swirl | `donut` | 131649668281254 |
| `club_sandwich` | Terrace Club | `sub` | 85863668096370 |
| `slow_roast` | Overnight Roast Blend | `bag` | 137686512001808 |
| `quiche` | Morning Quiche | `pie` | 137520402102940 |

Ids live in `Graphics.Dishes`, keyed by `Config/Recipes` id. All 14 verified
loading live in the cookbook (each row scrolled into view — Roblox does not
fetch images it is not currently rendering, so an off-screen row reporting
"not loaded" is normal, not a fault).

**Coverage is now complete for everything the player can buy, place or cook.**

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
