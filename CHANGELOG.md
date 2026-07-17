# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
