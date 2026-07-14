# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
