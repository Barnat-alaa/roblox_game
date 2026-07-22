# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Docs — 2026-07-22 — handoff rewritten around what the game actually is
- **`docs/GAMEPLAY_DIRECTION.md` (new)** — the loop read out of the services
  rather than the design docs: the nine things a player can physically do, and
  the two findings behind them. **There are no ingredients** — `ingredientCost`
  is a coin deduction with no item, no stock and no supplier anywhere in the
  codebase — and **the game automates away its own gameplay**, because staff
  progressively remove every physical action. Ends with seven ranked mechanics
  inside the ethics rails and an explicit "do not build yet" list.
- **`docs/SESSION_HANDOFF.md`** — rewritten. Adds a "hard-won facts" section so
  the next session does not re-derive them: `rbxthumb` serves only 150 and 420,
  Roblox has no GUI blur, Roblox does not fetch images it is not rendering,
  automatic production monopolises appliances (`stove_busy`), MCP cannot reach
  the running singletons, and generated icon sheets are not really transparent.
- **`HANDOFF.md`** — the UI section described a "compact tycoon UI" with a
  collapsed action menu and blank `Theme.Images`, none of which is true since
  the HUD rebuild; the platform line still said 30 plots. Both corrected, the
  bootstrap prompt rewritten, and §6 now leads with the honest priority: the
  biggest gap is design, not polish.

### Fixed — 2026-07-22 — the tutorial dead-ended on step 2
Owner report: "it only stops at step 2 even though I did it." It was not a
detection bug — **the step was impossible**.

Step 2 asked for the brew timing minigame, which needs a *live order*; once a
waiter is on shift, orders are served automatically before the player can reach
the machine. Retargeting it to cook-by-hand does not help either: the automatic
production loop holds a job on the appliance, so a manual `StartCook` answers
`stove_busy` — measured live, on the seed café's only coffee machine.

Step 2 is now the **menu**, which is the player's real lever over a cook-ahead
kitchen and is always available: *"Your kitchen cooks on its own. Open Pantry
and choose what it makes."* `ProductionService` emits a `menu_changed` notify so
the tutorial has a signal it can attribute to the player; collecting a batch or
landing the brew minigame still count for anyone who catches an idle appliance.
Step 3's text also stopped describing a "green Serve button" that no longer
exists — the flow is pick up at the pass, then carry to the table.

Verified live end to end: 1 → 2 → 3 → 6 with no dead end.

### Changed — 2026-07-22 — HUD rearranged and rebadged (owner request)
- **Camera pad hidden on desktop.** The Q/E/+/− cluster duplicated the keyboard
  and the scroll wheel and owned the top-left corner. It stays on touch, where
  it is the *only* way to rotate the camera.
- **Café health bars moved to top-centre** (SAT / CLEAN / BARISTA / WAITER).
  Narrow viewports still drop them into the left column, and the camera pad
  reads the same shared geometry so the two cannot overlap.
- **Tutorial card moved to the top-left corner** it freed, below Roblox's own
  top bar — at the obvious y=8 the platform's menu and chat buttons sit on top
  of it and it cannot be read.
- **New button art** from the owner's icon sheet: Build, Staff, Shop, Upgrades,
  Goals, Trophies, Music, and the Money / Reputation / Buzz pills. Tinting is
  now opt-out (`Graphics.UIFullColour`) so full-colour art keeps its palette
  while the flat CC0 glyphs are still recoloured per surface, and a colour pill
  icon replaces its coloured disc rather than sitting on it.
  `Cookbook`, `Map` and `Settings` arrived on a second sheet, so **every** HUD
  button and stat pill is now on the owner's art — no mixed styles left. The
  muted-music icon is derived from the owner's own music note (desaturated and
  dimmed) rather than falling back to a flat glyph.
- `scripts/slice_icon_sheet.py` takes `--rows/--cols/--names`, so the next sheet
  is one command.

### Changed — 2026-07-22 — furniture renders 1.5× bigger; round table is one cell
Owner request: placed furniture read too small next to a character, and a round
table should occupy a single cell so chairs sit square against it.

- **`AssetManifest.displayScale = 1.5`** — one number scales every placed piece.
  It multiplies both `height` and `maxSpan`, because height alone gets undone by
  the span clamp that keeps a model inside its footprint. The procedural greybox
  fallback scales by the same figure, growing from the floor so it neither sinks
  nor hovers, and grid footprints are deliberately **not** scaled — a piece may
  now overhang its cells, which is what makes a room look furnished.
- **`table_round` is 1×1** (was 2×2). The four orthogonally adjacent cells are
  now exactly the four chair positions. Measured live: each chair sits **4.00
  studs** from the table centre with a **+0.07 to +0.14 stud** edge gap — tucked
  in, not clipping. `BuildService.autoFaceSeats` already turns each chair to
  face the table, so a set snaps together with no fiddling.
- **The counter keeps its length.** `widen` is applied *after* the uniform scale,
  so it multiplied it: the counter measured **36 studs inside a 24-stud
  footprint**, hanging 6 studs off each end. `maxSpan` cannot fix this (it
  clamps before `widen` and never bound here), so the counter's `widen` is
  divided by `displayScale`. It now measures exactly 24.0.

### Fixed — 2026-07-22 — `deepen`, the missing companion to `widen`
Closes a tracked issue. The counter body imported ~3.1 studs deep inside a
4-stud cell, so appliances standing on it hung off the front and back, and there
was no mechanism to correct a model that is too thin rather than too short.
`deepen` stretches the **short** horizontal axis exactly as `widen` stretches the
long one; the counter now fills its cell depth at 3.9 studs.

### Added — 2026-07-22 — every dish has its own picture
Closes the one gap the coverage audit found. The 14 dishes are meshes *inside*
one packaged model, so no dish had a Creator Store id to render a thumbnail
from — Espresso and Latte showed the same coffee-cup photo, and the four
pastries shared one croissant.

- **14 dish icons from Kenney Food Kit 2.0 (CC0)**, self-uploaded, one per
  recipe, keyed by `Config/Recipes` id in `Graphics.Dishes`. The kit ships a
  flat 2D render per model, which is exactly the 3D-to-2D step
  `docs/HUD_REDESIGN.md` §4.3 called for; each was upscaled to 256px. Two were
  modified (CC0 permits it): the iced tea is hue-shifted from the stock purple
  to tea colour, and the cappuccino uses `cup` because `cup-saucer` renders as
  an empty plate.
- `Components.ItemThumbnail` gained an `image` option so a dish can pass its own
  uploaded icon, while furniture keeps rendering from its Creator Store model.
- The **always-visible stock dock** slots now show the dish icon instead of a
  coloured letter puck, with the puck kept as the fallback.
- Verified live: 14 cookbook cards, **14 distinct images**, all loading. (Rows
  scrolled out of view report "not loaded" — Roblox does not fetch images it is
  not rendering. Walking the list confirms 14/14.)

Art coverage is now complete for everything the player can buy, place or cook.

### Added — 2026-07-22 — catalogue rows show the actual item, blurred when locked
Owner report: "in the shop or when I want to put an item I can't find the photo
of the item I will be putting." Every catalogue row showed a two-letter category
badge (`AP`, `SE`, `DE`) or, in the build list, nothing but a coloured bar.

- **`Components.ItemThumbnail`** — a row's picture of the real item. Roblox
  renders a preview of any Creator Store asset, so this is the actual model we
  ship, not a stand-in. Falls back to the code-drawn glyph badge when an item
  has no asset, so a row is never empty.
- **Locked items show the same picture heavily blurred**, with the level
  requirement over it. Roblox has no GUI blur (`BlurEffect` is a Lighting
  post-process on the 3D world) and `rbxthumb` serves **only 150×150 and
  420×420** — every other size silently returns blank, so there is no
  low-resolution source to upscale either. The blur is therefore composited:
  the same picture drawn 14× at small offsets. Measured 20 blurred rows = 260
  ImageLabels = 61 fps.
- **Shop** rows: 56px picture; blur toggles live as you level up, since the
  rows are mutated rather than rebuilt. Being short of coins does *not* blur —
  you should be able to see what you are saving for.
- **Build placement** rows: 46px picture, replacing the coloured accent bar. The
  row text also stops being one space-indented string and becomes real labels.
- **Cookbook** cards and **pantry** rows: the category's plate prop, blurred
  while the recipe is locked instead of a bare "?".
- Thumbnails are warmed with `ContentProvider:PreloadAsync` on a background
  thread at join, because Roblox generates a preview server-side on first
  request and that measured several seconds.

**Coverage audit** (asked for in the same report — full table in
`docs/ASSET_LICENSES.md`): all **20/20** buyable/placeable furniture items have
real per-item art, verified rendering live. The gap is **per-dish art**: the 14
recipes are meshes inside one packaged model, so no dish has its own asset id;
they share 4 category pictures. `docs/HUD_REDESIGN.md` §4.3 already documents
the fix (render Kenney Food Kit models to flat icons).

### Changed — 2026-07-22 — the chunky icon HUD (docs/HUD_REDESIGN.md)
The menu rework the owner asked for. The old HUD put a stat capsule at the top
and a small text dock bottom-right; it now reads like a tycoon toolbar.
- **Bottom-left stat pills** — Money · Reputation · Buzz as stacked rounded
  pills with a coloured icon disc, stacked above the active-stock dock. Values
  **tween** to their new number (measured: 16 intermediate frames on a −15 coin
  purchase) and the pill pops to 1.08 and settles. Nothing snaps. The Level chip
  is gone from the HUD; level still drives the level-up celebration.
- **Bottom-centre action dock** — five chunky rounded-square plates: **Build 1,
  Cookbook 2, Staff 3, Upgrades 4, Shop 5**, each with a numbered badge.
  Hovering lifts the plate to 1.10 and fades its **name in underneath**;
  pressing dips to 0.94 and settles back ("pop"); the button whose panel is open
  stays raised with a bright accent stroke.
- **Right rail** — Goals `G`, Trophies `T`, Map `M`, Music `B`, Settings `V` as
  smaller round plates, each with its key in a **tiny pill beside the button**.
  Music is a toggle: it shows its on-state through stroke and tint (and swaps to
  a crossed-out note when muted) rather than sitting permanently raised.
- **`Components.IconButton`** — the dock and the rail are the same component,
  not hand-rolled markup, so restyling is one edit. `Theme.Hud` holds every
  size, scale, tint and motion value; the controllers carry no layout literals.
- **One shortcut table.** `HUD_BUTTONS` in `UIController` declares id, zone,
  order, key, badge, label and accent together; controllers only attach
  behaviour via `registerAction(id, callback)`. Buttons without a panel yet
  (Staff, Upgrades, Map, Settings) say so in a toast instead of doing nothing.
- **`ResponsiveLayout.hudLayout`** — one function computes every HUD rectangle,
  and `UIController`, `InventoryController`, `OperationsController`,
  `CameraController`, `CookingController` and `TutorialController` all read it.
  They used to each guess, which is what let elements land on top of each other.
  On narrow screens the dock slides right out of the pill column (11px on a
  560px phone) rather than restacking the whole left side, and floats above the
  stock dock when a centred dock would sit on it.
- **Landscape phones now get phone-sized controls.** `ResponsiveLayout` is
  landscape-first, so a 668×376 phone reports "Compact" and used to be handed
  72px desktop plates. Sizing now keys off the short axis (`Theme.Hud.ShortViewport`).

Measured live in Studio, all three modes, zero overlapping elements:

| viewport | mode | world visible | floor |
| --- | --- | ---: | ---: |
| 1173×627 | Desktop | **80.3%** | 62% |
| 668×376 | Compact (landscape phone) | **64.4%** | 62% |
| 560×365 | Phone | **56.3%** | 55% |

### Fixed — 2026-07-22 — collisions the HUD move exposed
- **Tutorial card no longer covers the stat pills.** It sat where the pills now
  live and is opaque, so a new player could not read any currency for the whole
  of onboarding. It moves to the band under the café-health card, or to the top
  strip on short viewports.
- **Tutorial card sizing actually applies.** `applyMinimized` hardcoded 360×72
  and ran after the responsive pass, silently undoing every narrow-screen size.
- **Camera pad, café-health card and stat pills stop stacking** on small
  viewports — the pad reads the shared layout and clamps above whatever is below
  it, and the health card's geometry now comes from that same function.
- **Brew panel stops covering the serve button** on desktop (serve moved up with
  the dock), and is clamped so it can never be pushed off the top of a short
  screen.
- **Goals and Trophies no longer both light up.** They open the same panel until
  Trophies gets its own; only the button actually pressed reads as active.
- **Panels sink clicks** (`panel.Active`), so a tap on panel dead space no longer
  falls through to the HUD button underneath it.
- **A slow-loading icon is no longer discarded.** `Components.Icon` used to
  destroy the image at exactly 6s if it had not loaded; it now covers it with the
  glyph badge and swaps the image back in if it arrives.

### Changed — 2026-07-22 — HUD icons are CC0 art we uploaded ourselves
- **17 images self-uploaded** (`docs/ASSET_LICENSES.md`): glyphs from the
  **Nieobie Game Icon Pack** (CC0 1.0, pinned at commit `fb27988`, licence read
  from the repo's own `LICENSE` file) rendered white so `Theme` tints them, and
  button plates from **Kenney UI Pack 2.0** (CC0 1.0, confirmed in the zip's
  `License.txt` and at kenney.nl/support). Zero attribution burden.
- **Retires the Simulator Icon Pack** (`99176447965360`) from the HUD. It is
  published on the Creator Store three times with byte-identical descriptions,
  each claiming originality, and our audit of it was a *script* audit, never a
  *provenance* one. All thirteen icons moved at once rather than mixing packs.
- Every id is verified rendering live (`IsLoaded` true on all 17), so none landed
  Restricted under the 2026-05-05 Asset Privacy default.

### Docs — 2026-07-21 — HUD redesign spec + a truthful status pass
- **`docs/HUD_REDESIGN.md` (new)** — full spec for the menu rework the owner
  asked for: bottom-left stat pills (money/reputation/buzz), a bottom-centre
  dock of five chunky icon buttons with numbered shortcuts that lift and show
  their name on hover, and a right-hand rail with single-key shortcuts. Records
  what we take from the owner's reference screenshot (layout, information
  architecture, interaction pattern) and what we explicitly do not (its icon
  art, skins, wording) — the same line `docs/MENU_SPEC.md` draws for Café World.
  Includes the exact list of icon slots still needed from the owner.
- **`docs/SESSION_HANDOFF.md`** — rewritten: merged work, the DataStore
  environment split, the real offline-earnings formula, and an explicit
  "merged but never actually run" section (the 10-café street,
  `PedestrianService`, the `saveBlocked` path).
- **`NEXT_ACTIONS.md`** — was badly stale: it still listed publishing the
  experience as "the only real blocker left" when the experience has been
  published since 2026-07-20. Rewritten around what is actually outstanding.
- **`KNOWN_ISSUES.md`** — corrected the claim that capped offline earnings
  "remains a later idle-progression feature"; it shipped. The two real
  remaining gaps (Waiter-only capacity scale, and `lastSeenAt` being stamped
  even when settlement never ran) are recorded instead.
- **`CURRENT_STATUS.md`** — persistence is no longer blocked on publishing;
  points at the session handoff as the authoritative status doc.

### Changed — 2026-07-21 — 10-café lobbies, and the surplus-player path made real
The lobby drops from 30 cafés to **10** (owner request). Scale now comes from
Roblox spawning MORE servers, not bigger ones — total concurrent players stays
unbounded while each street stays a readable 10.
- **`World.plotCount` 30 → 10, `plotsPerRow` 15 → 5.** streetLength 1248 → 408
  studs. Nearly all geometry was already parameterised and rescaled cleanly
  (plot origins, road tiling, sidewalk slabs, plaza, sky backdrop, StreetGround,
  world boundary, and all of `StreetMath`).
- **⚠️ The dashboard Max Players must be set to 10 to match.** It is not
  settable from code. At the recorded setting of 30, twenty players per server
  would join with no café.
- **Surplus players are no longer stranded.** `assignPlot` returning nil used to
  `return` silently: no plot, no PlotOrigin attribute, no furniture rendered, no
  teleport, no fall-recovery, and a build mode that swallowed every tap without
  explanation. They now join a **waiting queue**, are told so, and are handed the
  next café that frees up (`serveNextWaiting` on `onPlayerRemoving`).
- **`plotCount == plotsPerRow * 2` is now enforced.** `plotOriginFor` wraps its
  column modulo `plotsPerRow`, so a mismatch silently stacked a second café on an
  existing origin and handed two players the same building. Asserted at boot and
  covered in `tests/StreetMath.spec.luau`.
- **Pedestrians could be trapped outside the world boundary.** `END_MARGIN` was a
  flat 20 studs, but the StreetGround slab only reaches `plotSpacing/2 - 32` = 10
  studs past the last plot, with the boundary wall on that edge — so a spawn in
  that strip landed *outside* the wall and `clampX` kept it there forever.
  `walkXBounds` now clamps the margin to what actually fits (20 → 6). Pre-existing,
  but the odds roughly tripled on the shorter street. Covered by a new spec case.
- **Street decor now scales with the street.** Trees were a hardcoded `for i = 1, 4`,
  which on a 408-stud street meant one tree per café (~3x intended density); the
  count is now derived from length (2 trees, 210-stud spacing). The `% 3` / `% 4`
  accent strides collapsed to 2 mailboxes and a single lone hydrant on the whole
  far pavement; the stride is now size-aware (3 mailboxes, 2 hydrants).

### Fixed — 2026-07-21 — ghost profiles, and an unprotected loop that could disable the shift system
- **Ghost profile overwriting real saves.** `DataService.onPlayerAdded` yields
  inside `loadAsync` (a GetAsync, plus up to 3 retries with 2s waits). It then
  populated `profiles`/`loaded`/`saveBlocked` *after* that yield — so a player who
  left mid-load had `onPlayerRemoving` run first against empty tables, and the
  load then **repopulated them for the life of the server**. The 60s autosave kept
  writing that orphaned snapshot over their real save. The load result is now
  discarded if the player has already left.
- **The 5s operations loop had no `pcall`.** It owns offline settlement, staff
  capacity recovery, satisfaction decay, dirt spawning and `lastSeenAt` freshness.
  One uncaught error from any single player's tick killed the thread and silently
  disabled all of that for **every** player on the server, permanently. Every
  comparable loop in the codebase was already protected; this one was not.

### Fixed — 2026-07-21 — persistence safety: a failed load no longer wipes the account
Found while verifying "does a returning player get their progress back".
- **A transient DataStore outage permanently erased accounts.** When all three
  `GetAsync` attempts failed, `loadAsync` returned a blank `defaultProfile()`
  and logged "NOT persisted this session" — but **nothing enforced that**.
  `saveAsync` had no idea the load had failed, so the next 60s autosave (or
  save-on-leave) wrote that blank straight over the player's real save. One
  DataStore blip = a wiped café, irreversibly. `loadAsync` now returns
  `(profile, safeToSave)` and users whose save could not be read are added to
  `saveBlocked`, which every write path skips. They can still play on the blank
  profile; it just never persists.
- **The DataStore name is now resolved at boot instead of hardcoded to `DEV`.**
  Two bugs in one: publishing would have filed live players into the DEV store,
  and — worse — once the place was published a Studio playtest would have read
  and overwritten PRODUCTION saves. Studio and unpublished servers are pinned to
  `DEV`; a live server resolves to `PROD`; an `Environment` attribute on the
  place overrides both (e.g. `STAGING`). Verified: Studio resolves to
  `DEV_PlayerProfiles_v1`.
- **Join no longer renders an empty café on a slow load.** `CafeService` waited
  a fixed 20s for the profile and then rendered regardless, which would draw a
  blank shop for a player who actually had saved furniture. It now waits while
  the player is still in the server (logging every 10s, hard cap 3 min) and
  bails without rendering rather than showing a wrong, empty café.
- **Capacity guard rail.** One café per player is the whole premise, but
  `MaxPlayers` lives on the Roblox dashboard and can be changed without touching
  this code. `CafeService.Start` now asserts the invariant out loud at boot,
  naming the exact numbers, instead of the surplus players silently arriving
  with nowhere to play.

### Added — 2026-07-21 — permanent street crowd: ambient pedestrians on the sidewalks
The boulevard now has a standing cast of NPCs so the neighbourhood reads as
alive instead of empty, and some of them wander into **any** open café — every
claimed plot, not just the local player's.
- **`PedestrianService`** keeps `Pedestrians.count` (16) walkers alive for the
  whole server session, split across the two sidewalks, in their own
  `workspace.Pedestrians` folder. They are pure set dressing: they never queue,
  order, tip, or touch satisfaction/Buzz, and nothing that scans
  `Customers`/`Staff` sees them.
- **Sidewalks only, by construction.** Street movement uses a direct
  `Humanoid:MoveTo` along a fixed lane — deliberately NOT PathfindingService,
  which happily routes an NPC diagonally across the road. Pathfinding is used
  only once a pedestrian is inside a café, where it has to route around
  furniture. A per-tick clamp snaps anyone shoved off the paving back into lane.
- **`Utilities/StreetMath`** holds the geometry as pure numbers so it is
  unit-testable: sidewalk A is Z [-18, 0], the road is Z [-42, -18], sidewalk B
  is Z [-60, -42]. The walkable lanes are Z [-10.5, -3.5] and [-56.5, -49.5] —
  inset to clear the café fronts AND the street decor, since CafeService puts
  mailboxes at Z -14 and hydrants/trees at Z -46/-44, right where a naive
  "walk down the middle of the pavement" would collide. Verified against the
  built world: measured sidewalks/road/decor match these numbers exactly.
- **`tests/StreetMath.spec.luau`** asserts the containment contract — lanes are
  strictly inside the paving, never overlap the road, and keep ≥3.5 studs from
  every café wall and decor prop.
- Cafés count as OPEN when the plot is claimed (unowned plots are shuttered and
  read CLOSED). Pedestrians only consider cafés fronting their own sidewalk, so
  a visit never means crossing the road, and `maxVisitorsPerCafe` (3) stops one
  café swallowing the crowd.
- `World.roadWidth` is now the single source of truth for the road/sidewalk
  split, shared by CafeService's tiling and StreetMath's lanes.
- `CafeService` door proximity now also counts the `Pedestrians` folder, so a
  passer-by no longer walks into a shut door.

### Fixed — 2026-07-21 — kitchen layout VERIFIED in Studio; counter fills its footprint, machine sits flush
Closes the one open item from the 2026-07-20 handoff, which had been set blind
and never visually confirmed. Measured live in Studio against the real assets
rather than reasoned about, since the previous pass was burned by mirrored
left/right intuition.
- **Left/right layout was already correct — no flip needed.** Ground truth: the
  player enters facing local +Z, and with Up = +Y that puts their RIGHT at LOW
  local X. Measured positions: espresso machine pivot at local X 18 (owner's
  RIGHT ✓), front door at local X 50.4 (owner's LEFT ✓), kitchen at cells 0-7
  (front-RIGHT corner ✓). `World.doorCenterFrac` and the seed `gridX` are now
  commented with this result so a future pass does not "fix" it backwards.
- **Counter now fills its 6-cell footprint** (`AssetManifest.counter.widen`
  2.1 → 2.56). The normalised body is 9.38 studs before the multiplier and the
  footprint is 24 studs, so 2.1 left it spanning only 19.7 — measured 24.02
  after the change.
- **Espresso machine no longer floats** (`DataService` seed `seed_coffee.liftY`
  3.5 → 2.43). `liftY` is the model's BOTTOM height and the counter worktop
  measures 2.43, so the machine had been hanging 1.07 studs in mid-air. The
  earlier 3.5 was derived from a bounding box polluted by the StockDisplay
  (top 5.28) rather than the worktop itself. Verified live: flush gap −0.004.
- Together these also fix the machine hanging off the counter's right end — it
  sat at the footprint edge (X 15.7) while the short counter only began at 18.1.

### Added — 2026-07-19 — graphics haul: last greybox items, real dirt, maid, warm walls
- **The 5 remaining greybox shop items now use real models**: Prep Station,
  Round Table (glass), Potted Plant, Floor Lamp, Round Rug.
- **Pivot normalization** (AssetLibraryService): furniture templates now get an
  axis-aligned pivot at their centre, so the loaded upright pose survives
  placement instead of inheriting a random part's rotation — this fixed the
  floor lamp (was lying down) and the rug (was standing on edge). Flat items
  (`flat = true`) rotate their thinnest axis vertical and scale by span.
  Verified live: every furniture piece upright/flat and sitting on the floor,
  no regressions to coffee machine / counter / chair / oven.
- **Dirt is a real spill mesh** now (owner pick), not the procedural brown
  splat, and the "DIRT! CLEAN ME" text is gone — the mesh is the signal.
- **Pia the cleaner uses the owner's maid rig** (14466134917). Re-verified: R15
  with 13/15 joints (only the ankles missing), which walks cleanly — so the
  walk gate was relaxed from 15 to 13 for R15. Live movement check: 4.1
  studs/step, no teleporting.
- **Warm plaster walls** replace the harsh orange (interior + facade); the red
  awning accent stays. **Neon "Coffee Cup" café sign** mounted on each café's
  exterior facade. Coffee drinks use the new coffee-cup prop.
- Rejected: the barista rig (4646109032 — no HumanoidRootPart/Head, 8 scripts);
  the wallpaper asset (13010827217 — "not authorized", won't load); the food
  mesh pack (mostly raw ingredients, poor café fit — kept the Retro pack).

### Added — 2026-07-19 — active café shift loop (idle → hands-on tycoon)
Turns unlimited automation into a finite, active-play loop where the owner is
the fastest way to keep the café healthy. (Built on the `codex` branch; dead
code cleaned, all gates + 51 TestEZ cases verified, runtime smoke-checked.)
- **Finite staff shift capacity** (`Config/Operations`, `CafeOperationsService`):
  Barista/Cook/Waiter/Cleaner each spend capacity while working and only
  recover while the owner is in-game; hands-on work restores a little. Offline
  automation drains capacity instead of running forever.
- **Persistent satisfaction + cleanliness**: a compact HUD health card (SAT /
  CLEAN / BARISTA / WAITER). Satisfaction decays while away; low cleanliness
  cuts patience and can make arrivals reject the café outright.
- **Visible dirt**: splats spawn on the floor (~18 s) with a "CLEAN ME" prompt;
  the owner can scrub for satisfaction, or Pia takes it after a grace window.
- **Angry emoji walkouts**: customers leave with a readable reason — long line,
  no empty chair, café too dirty, or order never came — each denting Buzz +
  satisfaction.
- **Physical order delivery** (`OrderService` rewrite): pick an order up at the
  kitchen pass, the plate visibly follows your hand, you can only carry one,
  and only the matching table completes the sale ("PERFECT DELIVERY!"); wrong
  table is corrected, not silently served.
- **Street approach**: customers spawn on the distant sidewalk and walk in
  along a real road network, not popping in at the door.
- **Sealed map**: a perimeter boundary plus a fall-watchdog that returns a
  strayed player to their own door instead of killing them; indoor jump cap.
- **Explicit economy** (`OperationsMath`, `OperationsController`, production
  menu): per-recipe batch time, production/min, waiter serve-capacity/min, the
  real bottleneck, and net coins/min after ingredients. Offline runs at 20×
  time for 1/20 earnings, shown clearly with an on-return summary.

### Added — 2026-07-19 — owner-approved graphics pack
- Replaced HUD letter badges with approved coin, reputation, level, Buzz,
  goals, cookbook, build, shop, and pantry images from the Simulator Icon Pack;
  the code-native glyphs remain available as fallbacks.
- Added tiled stone sidewalks, a modular two-lane road with straight/left/right
  modules, a warm wooden restaurant floor texture, and a bright cloud sky.
- The Retro Food Pack is loaded once, stripped of all five embedded scripts,
  and reduced to 14 explicitly selected recipe props for counters and plates.
- Rejected the American diner pack from the shipped build: it contains branded
  restaurant logos, 659 instances, and two embedded scripts, and is not a clean
  or original UI-icon source.
- Live-tested the approved graphics on desktop and iPhone 17 Pro landscape:
  all HUD/environment images loaded, 50 sanitised templates loaded with zero
  fallbacks, and the complete TestEZ suite passed 48/48 cases.

### Changed — 2026-07-19 — compact tycoon interface
- Rebuilt the runtime UI around a single resource capsule, a contextual order
  ticket, a small active-stock pill, and a collapsible edge action dock so the
  restaurant remains the visual focus.
- Landscape phones and short Studio windows now use narrow 41–44% side drawers
  instead of full-width mobile sheets. Desktop drawers leave at least 62% of
  the world visible in the tested laptop viewport.
- Pantry/production, shop, goals, cookbook, build, appliance picker, and visit
  panels now share one high-order modal layer, preventing tutorial and stock
  widgets from rendering over an open menu.
- Added an original Sunset Cafe theme with code-native icon fallbacks, 44px
  production controls, vibrant status colors, and blank approved-asset hooks.
  No third-party icon asset was inserted without owner approval.
- Live-tested in Studio on iPhone 16 Pro Max landscape and an average laptop.
  The iPhone stock pill used 226–344px depending on active menu count, open
  drawers left 55% of the world visible, and TestEZ passed 44/44 cases.

### Added — 2026-07-18 — continuous idle/tycoon production
- All 14 current products now have explicit batch time, yield, online shelf
  life, waiter cycle, appliance, and staff-role requirements.
- Placed coffee machines, stone ovens, and prep stations continuously produce
  enabled menu recipes toward player-controlled stock targets. Production
  pauses for missing appliances, missing staff, full targets, or ingredients.
- Inventory is now timestamped FIFO lots with atomic short reservations. A
  serving is removed before its payout, expired food is tracked as waste, and
  offline time is shifted out of expiry so absence never destroys stock.
- `PlayerData.staff` is authoritative. Mia produces drinks, Sam produces food,
  Noah limits automatic service to each recipe's cycle, and Pia remains the
  cleaner; staff levels improve role speed.
- Customer demand now scales from 1.2 to 2.8 visits/minute using Buzz, seating,
  and waiter capacity instead of overwhelming the kitchen every 3–10 seconds.
- Added an always-visible vibrant stock rail for every product plus a responsive
  Production Manager (four menu slots, target stock, P1–P3 priority), incoming
  batch/freshness timers, and a Business Pulse bottleneck message.
- Schema v2 migrates old numeric counter stock into fresh timestamped lots and
  seeds the four existing crew roles without losing old servings.
- Added deterministic FIFO/reservation/spoilage/balance tests and
  `docs/PRODUCTION_BALANCE.md`. Live TestEZ result: 44 passed, 0 failed.

### Fixed — 2026-07-18 — visible chair facing, vibrant café, human-scale walls
- Chairs now face the nearest table regardless of placement order, including
  saved layouts loaded from older builds.
- The imported wooden chair's native back is `-Z`, opposite the procedural
  chair convention. A measured 180° correction is now applied in the final
  placement transform, so the visible seat faces the table.
- The restaurant uses a brighter coral, honey-oak, cream, gold and teal palette.
- The front-right café corner is a real open kitchen with an L-shaped divider
  and dish pass. Customers queue on the dining side; Mia/Sam prepare inside;
  Noah collects plates outside; Pia's idle sweep stays out of the kitchen.
- Exterior walls are back to a human-scale 12 studs. Players use a 3-stud / 28
  power jump only while inside a café and regain the normal 7.2 / 50 outside;
  the private garden fence keeps its sealed collision boundary.
- Live MCP verification: four real chairs all faced inward, indoor/outdoor jump
  transitions passed, and a wall-directed jump from a 3.8-stud platform peaked
  at root Y 9.33 and remained inside the 12-stud wall.

### Added — 2026-07-17 — S2 CLOSED: feelings, regulars, combo + the Priorité 4 dressing haul
**The feelings layer (S2 finish, live-verified):**
- **Mood faces + patience bars** over every waiting customer (😊→😐→😠 with a
  draining colour bar), in the line AND at the window.
- **Storm-outs**: impatient customers flash red "−N 🔥", speed up and leave —
  line walkouts now also dent Buzz (they didn't before).
- **Regulars (persisted, max 8)**: diners are remembered by name; 35% of
  spawns are a returning regular ("💚 Zoe is back!") who orders their
  favourite dish — serving it pays +1 Buzz and a burst of hearts.
- **Personal-service COMBO**: chaining owner actions (serve orders, clean
  tables) within 45s pays escalating bonus coins ("COMBO ×4 +8 🪙") — an
  active owner visibly out-earns an idle one.
**The Priorité 4 graphics haul (20 assets adopted, live-verified):**
- 11 new buyable interior items (wall painting, menu board, hanging lamp,
  plant shelf, wall shelf, wall clock, curtains, diner booth, bar stool,
  coat rack, cake display) — wall pieces mount at height via liftY.
- **Gardens auto-dress**: hedges along the fences, flower patches, garden
  bench, lantern, real trees (the tree pack splits into 11 variants).
- **Street + plaza**: real lampposts (32), mailboxes, hydrants, trees, and
  the fancy plaza fountain — procedural fallback everywhere, redressed
  automatically when the async asset load lands.
- **Noah is the Butler** (R15, complete 15/15 skeleton, zero scripts). The
  maid kit was auto-rejected (13/15 joints — the limp gate works); Pia keeps
  her verified base until a complete maid rig is found. The 636-part
  trash-can joke asset was rejected for performance.

### Fixed — 2026-07-17 — LIVE-VERIFIED: the whole S2 stack, + 3 movement fixes it caught
Studio MCP reconnected; everything from the three S2 passes ran live. Confirmed
working: facade/door/garden/14-stud walls, 16/16 assets loaded, chair
auto-facing (deliberately wrong rotations corrected server-side), seated
customers' legs STILL, dish-icon bubbles, Barista/Cook role split ("🍳
Preparing…" → "🥪 Café Sandwich ✓"), waiter carry with real MealPlate, dirty
plate + owner Clean-up prompt + Pia's collect-carry-wash cycle, take-order
prompt present, cleaner idle sweeping. Movement was measured (max step per
0.4s across the crew) and three real bugs were caught and fixed:
- **NPCs no longer collide with NPCs or players** (collision groups in
  NpcNav): the waiter was body-blocked by queueing customers, timed out and
  teleported 23 studs. Verified after: everyone at walk speed, zero jumps.
- **Stuck-recovery hops to the blocked waypoint** and keeps walking instead
  of teleporting across the room to the final target.
- **Waiter walks to the stand-spot beside the station**, not to the plate on
  top of the collidable appliance (that unreachable target failed pathing
  into the teleport recovery), and the barista kit (139800912587260) turned
  out to have a 5/6-joint skeleton — it limped; the walk gate now requires a
  COMPLETE skeleton per rig type (R6=6, R15=15) and Mia moved to a verified
  walking base with her uniform apron. Final audit: max step ≤4.6 studs
  (= walk speed) for every staff member across service cycles.

### Added — 2026-07-16 — S2 third pass: work your own café + walk-verified rigs + taller walls
- **The owner can WORK the café** (the gameplay transformation): `E` on the
  ordering customer to **take the order** and serve it from stock (+2 Buzz
  "personal service"), `E` on a dirty plate to **clean the table** (+1 Buzz,
  races Pia — first one wins), tips collectible as before. All prompts are
  owner-validated server-side and reuse the existing grant paths (no dupes).
- **Rig walk policy**: AssetLibraryService now REJECTS any rig without a
  native HumanoidRootPart and a real Motor6D skeleton (the HRP-synthesis path
  is removed — it produced the sliding waiter). The broken waiter kit
  (154539270) is permanently rejected; **Noah and Pia now use walk-verified
  customer rig bases with role-coloured uniform aprons** (waiter navy,
  cleaner green) until dedicated rigs are shopped (list #63/#64).
- **Cleaner idle sweeping**: between wash-up jobs Pia walks to a spot and
  sweeps — every employee visibly does their job (docs/NPC_BEHAVIOR.md is the
  new per-NPC behaviour contract).
- **Walls raised 9 → 14 studs**: you can no longer hop out of the café even
  jumping from a countertop; the awning now hangs at door height instead of
  tracking the wall top.
- docs: NPC_BEHAVIOR.md (exact tasks/state machine per NPC + player actions),
  ASSET_SHOPPING_LIST.md "Priorité 4" (36 dressing objects: restaurant,
  garden, neighbourhood + walking-rig rules), parity map C6 row + progress.

### Added — 2026-07-16 — S2 service theater: defined staff roles + the full plate lifecycle
- **Every employee now has ONE defined job** (Café World parity C2/C3):
  **Mia · Barista** prepares drinks at the coffee machine, the new **Sam ·
  Cook** (the owner's chef rig, reassigned from cleaner) prepares food at the
  oven/prep station — both walk to their appliance and flash a bubble with the
  **dish icon** when it's ready; **Noah · Waiter** walks over, picks the plate
  up and carries it to the table (`StaffService.DeliverMeal` orchestration);
  **Pia · Cleaner** collects the emptied plate and carries it off to wash
  (+1 Buzz). Every stage degrades gracefully when staff are busy/missing, and
  the whole flow is post-payment theater — it can never touch the economy.
- **Visible meals**: the plate + real food prop sit ON the table in front of
  the diner (PlateFactory); after eating, food disappears and the EMPTY plate
  stays until washed. Customer want-bubbles show the dish icon + name
  (Config/Recipes gains per-recipe emoji icons).
- **Fixed — walls invisible from outside**: the camera now x-rays only the
  café your character is standing in; every other café keeps its full facade.
- **Fixed — furniture landing away from the click**: placement raycasts now
  hit ONLY your interior floor (walls/door/awning used to swallow clicks) and
  the GUI-inset coordinate mismatch on the click path is corrected
  (KNOWN_ISSUES "screen→grid raycast" resolved).
- **Chairs auto-face the nearest table** on placement (server-side, 1×1 seats).
- **Fixed — seated customers' legs kept moving**: NpcAnimator gains a seated
  mode (anchored roots never fire Running(0), so the walk cycle kept playing).
- **Fixed — the waiter teleported instead of walking**: all staff now use the
  same PathfindingService navigation as customers (shared NpcNav module);
  straight-line + teleport stays as the last-resort recovery only.
- NOT live-verified (Studio MCP still down; the adversarial review workflow
  also could not run — session limit); manual code-trace done, gates green —
  owner playtest checklist updated in KNOWN_ISSUES.md.

### Added — 2026-07-16 — S2 architecture: facade + auto-door, 3x interiors, private gardens
- **Every café is now a real building** (CafeService rework): a front facade
  with two windows and a centred **door that swings open automatically** for
  any approaching player/customer/staff and closes behind them (never
  collidable — nobody can ever be trapped; the wall gap is the navmesh route).
  The sign moved to the facade; walls are 9 studs (unjumpable) — the door is
  the way in AND out, which also fixes "I can't exit my own café".
- **Interiors are 3x bigger** (18×24 cells = 72×96 studs, was 12×12 = 48×48)
  and **tiered**: `PlayerData.expansionTier` (0–2) drives interior depth
  (24/28/32 cells). The shell (floors, side/back walls, garden) rebuilds per
  tier; `CafeService.RefreshTier` is the S4 buy-land hook, already functional.
- **Private garden** behind every café: fenced grass with a gate off the back
  wall (auto-door), stone path, tree and flower beds. Buying land (S4) will
  convert garden depth into interior depth, Café-World-style; ≥40 studs of
  garden always remain.
- **Proximity checks are rect-based** (`Grid.distanceToPlotRect`, unit-tested):
  distance-to-centre would have rejected cooking/serving at the front counters
  of the deep new plots. Serve/cook/compliment guards migrated.
- Queue moved INSIDE the café (through the front door); staff idle spots and
  trophy shelf repositioned (shelf now on the left wall — tier-independent);
  camera fades the new facade + shell walls and zooms out to 120; build
  preview + server placement clamp to the owner's tier (garden previews red).
- Seed kitchen moved off the doorway lane; new placement spec cases for
  per-tier bounds and rect distance.
- NOT yet live-verified: Studio MCP was disconnected this session — owner
  playtest checklist in KNOWN_ISSUES.md.

### Fixed — 2026-07-15 — S1 polish from playtest feedback (dimensions, walk, pathing)
- **Object dimensions**: switched furniture scaling from fit-to-footprint (which
  squashed long/tall pieces — the counter shrank to 23% and chairs to ~16%) to
  **target-height scaling with a footprint clamp + yaw fix**. Also multiply by
  the model's current scale (`ScaleTo(GetScale() * s)`) — imported Sketchfab
  models (e.g. the chair) carry a non-1 baked scale that made absolute ScaleTo
  shrink them. Verified live: counter 2.1×3.8×9.4, coffee 4.6×3.6×4.2, chair
  1.75×3.3×1.83 (was 0.4×0.7×0.4).
- **Natural NPC movement**: new `NpcAnimator` plays Roblox's default R6/R15
  walk+idle animations on real rigs (they had no Animator and slid); procedural
  chibis keep the hip waddle. Verified: customers now have a playing anim track.
- **No more walking through furniture**: customers navigate with
  **PathfindingService** (route around obstacles) instead of straight-line
  MoveTo, and walk-blocking furniture is now collidable so the navmesh sees it.
  Straight-line + teleport recovery kept as fallback. Verified: path test
  returns Success (12 waypoints); furniture 35–45 collidable parts.
- Waiter rig (154539270) now loads too via the HRP synthesis — **15/15 asset
  templates, 0 fallbacks**.

### Added — 2026-07-15 — Step S1: Creator Store asset pipeline (make it LOOK like a café)
- **AssetLibraryService + Config/AssetManifest**: loads owner-picked Creator
  Store models at boot, **strips every script** (BaseScript/ModuleScript/
  Remote/Bindable/Tool/Sound), rescales to grid footprints, caches templates
  in ServerStorage, and serves clones. Loads in the background; any asset that
  fails vetting or load simply falls back to the existing procedural greybox —
  the game never breaks.
- **Furniture** now renders real models when available (espresso machine, pizza
  oven scaled to footprint, counter+register, wooden chair) via BuildService,
  procedural builders retained as fallback.
- **Customers** wear real clothed R6/R15 rigs (4 appearance donors) with our
  name tag + order bubble + walk/queue/seat logic on top; waddle now bobs
  around each rig's own hip height. Procedural chibi kept as fallback.
- **Staff** (Mia/Noah/Pia) use real barista/waiter/cleaner rigs; fallback intact.
- **Food props**: counters and diner plates show real croissant/cake/sandwich/
  cup meshes by recipe category (coloured cylinders as fallback).
- 15 assets adopted, 7 rejected during live Studio vetting (IP-named, ripped,
  unauthorised, or duplicate/ragdoll rigs) — all logged in docs/ASSET_LICENSES.md.
  Parity map updated (D1, C4 advanced).
- **Live-verified in Studio** (playtest): real furniture renders (coffee machine
  45 parts/2 meshes, counter+register 35 parts), barista (Mia) + cleaner (Pia)
  as real rigs, four clothed customer rigs walking/queuing. Waiter (Noah)
  real-rig loading fixed by construction (HRP synthesis, gate-clean); its live
  confirmation is pending a clean Studio session — the start-page quirk (§5.3)
  blocked further playtests this session (even a `-task EditFile` CLI launch
  landed on Studio's home page). Owner: open the place from Studio's **Recent**
  list, press Play, confirm all three staff are real rigs.

### Changed — 2026-07-15 — Café World parity roadmap + Creator Store policy
- **docs/CAFE_WORLD_PARITY.md (new)**: complete feature map of the original
  Facebook game (Café World by Zynga) — 49 features across cooking, service/
  Buzz, staff, customisation, economy and social, each marked have/partial/
  missing/rejected and assigned to a roadmap step. Owner's top request.
- **docs/ASSET_SHOPPING_LIST.md (new)**: curated Creator Store shopping list
  (3 priorities, EN search terms, French Studio click paths, vetting
  checklist) + the AssetLibrary pipeline contract (manifest → InsertService
  load → script-strip → grid rescale → procedural fallback).
- **ROADMAP.md**: new 5-step session roadmap "Café World parity push"
  (S1 look-like-a-café asset pipeline → S2 customer feelings → S3
  preparation/menu/appliances → S4 floors/walls/expansion → S5 social café);
  supersedes phase order until shipped. HANDOFF §6 repointed.
- **docs/ART_DIRECTION.md**: 2026-07-15 addendum — vetted Creator Store
  models allowed (scripts stripped, licences logged, procedural fallback,
  cohesive low-poly family); UI stays original.

### Added — 2026-07-14 — Day 5: a neighbourhood worth visiting
- **Golden-hour lighting pass**: warm Mediterranean evening (Atmosphere, bloom,
  sun rays, colour-shifted ambient), lamp posts with warm point lights, trees.
- **Central plaza**: cobblestone circle, three-tier fountain, four benches with
  planters, and a Neighbourhood Board — the social heart of the street (§19).
- **Café visits** (SocialService + InteractionController): "Visit Café" prompt
  on every neighbour's doormat pad teleports you to their door; a compliment
  panel offers three predefined reactions (whitelist only, no free text). A
  compliment gives the owner +2 reputation, once per visitor per owner per
  session, validated for physical presence. "🏠 Go home" returns you.
- **Persistent learn-by-doing tutorial** (ProgressionService + rewritten
  TutorialController): six strictly-ordered steps (place furniture → brew →
  serve → buy → decorate → reach the plaza) tracked server-side in
  stats.tutorialStep; +25 coin completion gift, exactly once per profile.
  Funnel analytics: tutorial_started / step_completed / completed,
  first_cafe_visit, compliment_sent.
- Plot models now expose `plotIndex`; workspace exposes `PlazaCenter`.

### Added — 2026-07-14 — Day 3: customers you can see, coffee you can brew
- **Visible customer NPCs** (CustomerService rewrite): greybox walk-in customers
  spawn on the street, walk to the service spot, order with a recipe bubble,
  wait, react (😊 +coins / 😠 timeout), walk out. Teleport recovery for stuck
  NPCs; 120s patience cancels the order server-side (OrderService.CancelOrder).
- **Manual coffee-brew minigame**: ProximityPrompt on your own coffee machine
  opens a timing bar (Space/tap to stop). Shared constants in Config/Cooking.
- **Security hardening**: the client's `manualCook` claim argument is now
  IGNORED — the server judges the brew timing from its own clock
  (RecipeService sessions) and arms a one-shot bonus flag consumed at claim
  time. New remotes: FinishCooking. New CafeService.IsNearOwnPlot guard;
  plot models carry an `ownerUserId` attribute for client-side lookup.
- Verified live (NPC lifecycle, serve payout +tip/rep/xp exactly once,
  cancel path, customer cycling). Brew minigame verified by unit-level gates;
  live playtest pending the next Studio session.

### Fixed — 2026-07-13 — Day 1 live verification
- **Client boot**: `Main.client.luau` waited on `script:WaitForChild("Controllers")`, but `Controllers` is a sibling folder — no controllers or UI ever loaded. Now `script.Parent:WaitForChild("Controllers")`. Found in the first live playtest via MCP console read.
- StyLua formatting drift in test specs; repo now passes `stylua --check .`.
- Selene reported 55 `undefined_variable` errors for TestEZ globals in `tests/*.spec.luau`; added `testez.yml` standard library and switched `selene.toml` to `std = "roblox+testez"` (0 errors).
- `.gitignore`: ignore Studio `*.rbxlx.lock`/`*.rbxl.lock` files and local `.mcp.json`.

### Verified — 2026-07-13
- 21/21 unit specs pass inside Studio (MCP harness, live DataModel).
- Clean server boot (6 plots, 12 services) and client boot (6 controllers).
- E2E serve loop through real remotes: payout matches config, duplicate claim pays nothing.

### Added — 2026-07-13 — Day 1 scaffold
- Rojo project in strict Luau: toolchain manifests, CI, project mapping.
- Shared layer: type definitions, data-driven config (economy, 5 recipes, 7 furniture items, 3 customers, progression, staff), remotes registry, pure utilities (Grid, RateLimiter, RewardMath, Log).
- Server: service framework + DataService (persistence w/ in-memory fallback, autosave, migration hook), EconomyService, CafeService (greybox 6-plot street), BuildService (server-validated placement), OrderService (serve/claim with anti-double-claim + distance guard), CustomerService (order generator), RecipeService, ProgressionService, AnalyticsService, and Staff/Social/Monetization placeholders.
- Client: HUD (stats, order, serve, shop, toasts), grid-based BuildController with live preview, learn-by-doing TutorialController, placeholder controllers.
- Tests: TestEZ specs for economy payout, grid placement, and progression.
- Documentation set (design, architecture, security, tests, release, economy, analytics, licences).

### Published — 2026-07-14 — Social Cafe DEV is live (private)
- Experience published: universe 10501568035, place 85898641225605, Access: Private.
- Studio API Services enabled → real DataStore (`DEV_PlayerProfiles_v1`).
- **Persistence verified end-to-end**: furniture placed in session A loaded
  from DataStore in session B. MVP criterion #12 passed.
- Max players set to 30 via Creator Dashboard (Access Settings).

### Added — 2026-07-14 — Phase 1: the cook-ahead loop pivot
- **KitchenService**: stove batches on wall-clock time (overnight cooking
  works), counter stock, fresh-collect bonus (never spoilage — §35), Buzz
  0–105 driving customer arrival rate, sign scoreboard.
- Customers eat from counter stock automatically; waiting order-customers
  get auto-fed the moment a matching batch is collected.
- Stone Oven + Prep Station appliances (all 5 recipes now cookable),
  stove timers + steam visuals, cook/collect prompts + recipe picker,
  HUD Buzz meter, kitchen toasts.
- Verified live: batch cost/servings/fresh-bonus math exact, busy/early
  rejections, 7 customers fed from one batch, Buzz feedback loop spinning.

### Added — 2026-07-14 — Phase 2: the alive café
- **Seated dining**: fed customers leave the queue (line advances), walk to a
  free placed chair, sit facing it, eat from a plate of food with a happy
  bob, then head out — verified sitting exactly on the chair's grid cell.
- **Collectible tips**: seated diners can leave a tip coin (owner-only
  ProximityPrompt, server-validated) — the reward for owning chairs.
- **Juice**: coin bursts + floating text on batch collect and tip pickup;
  chibi waddle (hip-bounce) while NPCs walk.
- **Visible stock**: food stacks render on the counter as batches land and
  customers eat them down.
- **Charm pass**: striped awnings over every café front + warm interior
  glow at golden hour.

### Added — 2026-07-14 — Phase 3a: progression that grips
- **Recipe mastery**: every collected batch teaches the recipe; stars at
  5/15/40/100 cooks grant -5% cook time & batch cost per star, +1 serving
  at ★★, and a 1.5× fresh bonus at ★★★★ (pure Mastery module, 8-assertion
  spec). Star-up float text at the stove + toast.
- **Cookbook**: card list of all recipes — unlocked cards show live
  mastery-adjusted numbers, stars, and "next ★ at N"; locked cards tease
  as silhouettes with their unlock level. Gold names when mastered.
- **9 new original recipes** (14 total) laddered to Lv 9, including the
  8-hour Overnight Roast Blend (40 servings — start it before bed).
- **Level-up celebration**: full-screen star moment on level gain.
- Cook picker rows show mastery-adjusted costs.

### Added — 2026-07-15 — Phase 3b: daily goals, streak trophies, full crew
- **Daily goals** (GoalService): three goals roll each UTC day from a pool
  (serve customers / collect batches / earn coins / pick up tips / visit a
  neighbour); each pays coins instantly on completion, all three pay a
  bonus and advance the streak. Progress reported by Kitchen/Order/Economy/
  Customer/Social services via GoalService:Bump.
- **Streak trophy shelf**: milestones at 3/7/14/30 days mint PERMANENT
  trophies (bronze→diamond) rendered on a shelf in your café + coin bonus.
  A missed day restarts the counter only — the shelf never empties (§35).
- **Goals panel** (📋 button): progress bars, streak, trophy count, with
  goal/streak/trophy toasts.
- **Staff v2**: full crew of three per café — Mia (barista, rescues overdue
  orders), Noah (waiter, carries a tray to seated diners), Pia (cleaner,
  clears the dirty plates diners leave and earns +1 Buzz each).
- Diners now leave dirty plates behind; the waiter delivery and cleaner
  loops both use the same waddle-walk + teleport recovery as customers.

Live playtest of 3b happens via the owner's session (test-instance launch
hit a local Studio start-page quirk); all CI gates green.
