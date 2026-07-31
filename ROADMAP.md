# Roadmap — to a top-hit café sim

_Rewritten 2026-07-14 after the MVP shipped. New working mode: Claude codes
and pushes; the owner playtests and reports by screenshot/feel._

**Where we are:** MVP complete and published privately (`Social Cafe DEV`,
place 85898641225605): full loop (build → brew → serve → earn → shop),
customer queues with 8 styles, barista automation, persistent tutorial,
café visits + compliments, 30-plot two-row city with closed-café shutters,
golden-hour art pass, licensed audio, real DataStore persistence, camera +
mobile controls, security-audited remotes, CI-green repo.

**North star:** the *feel* of the classic Facebook café sims, rebuilt as
original mechanics (never copied assets — see docs/ART_DIRECTION.md):
cook-ahead planning, counters full of food, a café that visibly hums, a
street of real neighbours, and decor as status. Ethical twist (§35): no
spoilage punishment, no fake urgency — *fresh bonuses* instead of rot.

---

## ⭐ ACTIVE BUILD — 2026-07-23 — Direction phases A–D

_This is the current build plan and it supersedes the S-steps and Phase order
below for day-to-day work. Full spec: **docs/GAMEPLAY_DIRECTION.md** (what/why);
exact code hooks: **docs/IMPLEMENTATION_MAP.md** (where); recipe/ingredient/
production **design + balance numbers**: **docs/CORE_LOOP_SPEC.md** (owner reviews
before the 🔴 steps ship). Owner-chosen feature set, built data-driven so it grows
for years without rewrites._

The four features that turn "serve coffee" into a management + collection +
social game, each giving the player short-, medium- and long-term goals:

| Phase | Ship | Fixes / adds |
| --- | --- | --- |
| **A** | **Ingredients** (real pantry, market, bulk buy) + **Staff** (start small, hire, upgrade 10→100%) | fixes the two diagnosed problems: ingredients don't exist, and the game automates away its own gameplay |
| **B** | **VIP customers** + earned **gift box** | something to chase every session; a reason to improve the café |
| **C** | **Neighbour help + friendships** + **mischief** (smell bomb / recruit) | other players become allies and rivals |
| **D** | **Monetisation** (cosmetics, membership, battle pass, accelerators) | only after A–C prove the loop is fun; every Robux SKU also earnable with coins |

**Phase A is sequenced.** Numbers for the 🔴 steps live in `docs/CORE_LOOP_SPEC.md`.
1. ✅ **Ingredients backbone** (#18) — `Config/Ingredients`, `recipe.ingredients`,
   `PlayerData.pantry` + healing, consumption behind `Kitchen.enforceIngredients`.
2. ✅ **Market buy path** (#19) — `MarketBuyIngredient` remote + `MarketMath` pricing.
3. ✅ **Market UI + Cookbook trim** (#20) — dock button (owner's icon), bulk-buy +
   inventory panel, cookbook shows machine + ingredients. Studio-verified.
4. ✅ **Recipe/inventory polish** (#22) — required-level pill on cookbook cards;
   zero/low OUT warnings on the market rows + banner.
5. ✅ **Staff data model** (#23) — `hired` flag, level, per-role `workMinutesPerHour`
   curve (Lv1 = 15 min/hr), `productionPlan`, `productionMinutes`.
6. ✅ **New auto-production** (#24, #25) — the **minutes-per-hour allocation** model:
   `productionPlan` per staff, online real-time + **offline ÷20**, the plan editor in
   the Auto Production drawer; `useProductionPlan` + `enforceIngredients` now LIVE.
   Adversarial-reviewed + fixed. _(Per-serving ingredient margins balanced
   2026-07-25 — all recipes 42–58%, guarded by `tests/Recipes.spec`.)_
7. ✅ **Staff panel UI** (#27) — hire locked roles + min/hr upgrade track; café
   starts Barista+Waiter only, `CountRole` gates on `hired`.
8. ✅ **Monetisation** (#28) — `Config/Products` (real IDs), idempotent
   `MonetizationService.ProcessReceipt`, boosts (2× coins/rep), VIP offline cap,
   `RobuxShopController` Store (rail key **P**) with native purchase prompts.
   Prices/plan in `docs/MONETISATION.md`.

**Phase A is COMPLETE.** The production per-serving **balance** pass is DONE
(2026-07-25 — every recipe nets 42–58%, guarded by `tests/Recipes.spec`). Pending
polish (not blocking): the remaining **VIP** perks (walk-speed, daily bonus, name
colour, storage) + **Auto-Collect** effect on manual cooks; **real-purchase
testing** of A8 in the published place.

**Phase B (VIP customers + gift box) is DONE (2026-07-26).** A brainrot VIP
(owner-chosen asset) walks the boulevard to the busiest café by Buzz, pays the
owner a premium order, and drops an EARNED gift box opened for a weighted reward
(`VipService`, `Config/Vip`, `Config/Gifts`, `RewardMath.rollGift`; not a loot
box). Next: **Phase C** (neighbour help + friendships + mischief).

Non-negotiables carried from below: server-authoritative, data-driven, no loot
boxes, no pay-to-win, no fake-urgency, and **tested in Roblox Studio before every
merge**.

---

## ⭐ NEXT — owner priorities (2026-07-31): café customisation

_Owner ask: "allow the players to buy and customise more their restaurant."
Seven items; **four are done** (PRs #52, #53). The three below are outstanding,
in the owner's own order, with hooks. One deliverable per PR, Studio-tested._

✅ **B1 placement/rotation audit** — already correct, verified to the stud (PR #53).
✅ **B2 move already-placed items** — tap to carry, tap to set down (PR #53).
✅ **B6 onboarding step 2/6 dead-end** — fixed, all 6 steps verified (PR #52).

### B3 — Floor + wall customisation (buy 1×1 floor tiles and 1×length wall panels)
The biggest of the three. Needs a new **surfaces** layer that is NOT furniture:
- New `Config/Surfaces.luau` (tile + panel catalogue: id, price, colour/texture,
  `kind = "floor" | "wall"`).
- New persisted `PlayerData.surfaces` — top-level so `reconcile` heals old saves:
  `{ floor = { ["x,y"] = tileId }, wall = { [wallId .. ":" .. span] = panelId } }`.
- Rendering in `CafeService.rebuildShell` (the `Floor` / `GardenFloor` parts and
  the side/back walls are built there) — paint per-cell decals/parts rather than
  one flat colour.
- A placement mode in `BuildController` — reuse `raycastCell` for floor tiles;
  walls need a wall-face raycast, which build mode does not have yet.
- ⚠️ Floor tiles must NOT collide with the furniture grid (they are a separate
  layer); walls need a span model (1×length), so the panel is a run, not a cell.

### B4a — Façade picker UI (the remaining half of B4)
The B4 backend is done and verified (`Config/Facade`, `FacadeService`, `SetFacade`,
`PlayerData.facade`, rendering for all seven axes). **What is missing is the panel
that lets a player choose.** Hooks:
- Seven rows of swatch/label buttons, one per axis, each firing `SetFacade` with
  that axis's id — the remote already accepts any SUBSET of axes, so one button =
  one field.
- Natural home: a "Café front" tab in the Upgrades panel (`RobuxShopController`
  owns it), or the intro panel where a café-STYLE picker was already listed as
  owed.
- `Config/Facade.architectures[n].blurb` is written for use as card copy.
- Price is `Facade.changePrice` (250 🪙 per change), already enforced server-side.

### B4 — Door colour + exterior façade customisation ✅ BACKEND SHIPPED (PR #56)
_Superseded by B4a above for the UI half._
- `PlayerData.cafeStyle = { doorColor, facadeColor }` (top-level, reconcile-healed).
- Applied in `CafeService`: the door is `DoorLeaf` on the plot model, the façade is
  the `WallFront` parts + `AwningSlat`s (see `rebuildShell` / the facade builder).
- A `SetCafeStyle` remote validated against a **whitelist of colours** in config —
  do not accept an arbitrary Color3 from the client.
- Sits naturally as a section in the existing Upgrades panel or the intro panel
  (a café-STYLE picker was already listed as owed there).

### B5 — More buyable garden items
- The garden is currently **outside the buildable area**: `validatePlacement`
  clamps placement to `World.interiorDepthTiers[tier + 1]`, so nothing can be
  placed behind the back wall. This needs a garden placement zone (a second
  allowed rect between the interior depth and `TOTAL_DEPTH`), not just new rows.
- Then add garden-category items to `Config/Furniture` (+ `AssetManifest` entries
  if they use Creator Store models) and a "Garden" tab in the build catalogue.

---

## ⭐ NEXT — owner priorities (2026-07-28), build in THIS order

_Phases A · B · C · D are all shipped + merged (PRs #30–#43) and CI-green, but
**NOT PUBLISHED** — the owner runs `scripts/publish.ps1` (their Open Cloud key) to
make any of it live; that is still the gate. Below are the owner's next asks, in
priority order. Do them **one deliverable at a time**: build → Studio-test → PR →
wait CI green → merge. Where it says "own PR", ship that slice by itself so it can
be tested properly._

### P1 — BUG: green grass shows THROUGH / under the road
The grass island (`CafeService.buildGroundAndSea`, grass top ≈ y −0.2) sits at or
above the road/sidewalk surface (`buildRoadNetwork`, tiles centred ≈ −0.34, top
≈ −0.22), so grass pokes up through the road. Lower the grass plane (e.g. centre
≈ y −1.2 so its top is clearly below the road) or raise the road, so the road
reads solid with no green bleed. **The owner will paste a screenshot.**

### P2 — Rework the neighbour-café interaction into 3 REAL, VISIBLE actions
Today "visit a neighbour" is a card of abstract buttons (compliments +
`SocialService.HELP_ACTIONS` water-plants/bus-table/stir-pot/flyers + the
`Mischief` recruit/bomb buttons) — most are not real in-world actions. Replace it:
walk up to a neighbour café + press **E** → a small menu of the actions below; each
is a REAL thing you do in the world. **Remove** the abstract HELP_ACTIONS + the
compliment-only card. **Ship each of the three as its own PR** (build + Studio-test
each before the next one):

- **P2a — Steal an item (bad).** Choose "steal" → the client routes you to that
  item's WALL SHELF (`KitchenService:GetShelfPart`), press **E** at the shelf → you
  take one item. The victim café gets a **notification naming the thief**
  ("<player> stole from your café!"). **Limited** (per thief→victim cooldown + a
  per-victim cap — mirror `MischiefService`'s cooldown/cap). Server-authoritative;
  the stock leaves their café.
- **P2b — Smell bomb.** From the menu → a **green effect UNDER the caster's
  character** (`Fx.smellVapour` exists — reuse) and **all the neighbour's customers
  LEAVE** (drive them out via `CustomerService`; the `leaving`/`depart` machinery is
  the hook — here they just exit, they don't transfer to you). Consumable +
  cooldown + cap (reuse `Config/Mischief` + `MischiefService`).
- **P2c — Help by WORKING (good, earns money).** Helping is no longer a button —
  you **go INSIDE a neighbour's café and do the real actions**: clean a dirty
  plate, serve a waiting order, cook. Those actions (OrderService pickup/deliver,
  the dirty-plate `CleanUp` prompt, cooking) are today gated to the café OWNER —
  open them to a VISITOR standing in a neighbour's café and **pay the helper coins
  per action** (capped per-neighbour-per-day, like the old anti-farm). Replaces
  HELP_ACTIONS entirely.

### P3 — Brainrot VIP as a scheduled SPECIAL EVENT with a HUD timer
Make the VIP a **fixed 30-minute server event** (not the current random 4–8 min
`Vip.spawnInterval`), with a **HUD countdown** (reuse the SessionReward / Boost
pill pattern) that shows the **brainrot's picture** + time-to-next-VIP. Make the
brainrot NPC **bigger** (`Config/Vip.modelHeight`/`hipHeight` +
`AssetManifest.vip.height`; scaled in `CustomerService.spawnVipModel`). Keep it
flowing through `CustomerService:SpawnVip` (enter → sit → order rare → served →
gift). Hooks: `VipService` (scheduler), `Config/Vip`, `AssetManifest.vip`, a new
`VipEvent` remote for the countdown; the picture = an rbxthumb of the vip asset id.

### P4 — Monetisation: move into UPGRADES + add sell-multiplier SKUs
- **Move the whole Robux Store into the Upgrades button/panel** (drop the separate
  "Store" rail button **P**). Fold `RobuxShopController`'s cards into the Upgrades
  panel as a section/tab.
- **Add three products — ×5 / ×10 / ×20** on the **output / sell value of every
  item you sell** (a persisted multiplier on `PlayerData`, applied in
  `KitchenService`/`OrderService` payout or production yield). New rows in
  `Config/Products` + grants in `MonetizationService`.
- ⚠️ **Rails tension:** a permanent ×20 sell multiplier is pay-to-win, which the
  rails forbid. Handle it responsibly (as the café-name free-text tension was):
  make each multiplier **also coin-earnable** (a grindable upgrade tier) or frame
  it as a temporary boost, and surface the trade-off to the owner before shipping.

**P4 follow-up (2026-07-30): OWNER ACTION + an economy pass.**
1. **Create three Developer Products** on the Creator Dashboard (Batch Output ×5
   / ×10 / ×20, suggested R$99 / R$199 / R$349) and paste each Product ID into
   `Config/Products.yieldTiers[n].productId`. Until then the coin path works and
   the Robux buttons stay hidden — nothing is broken, just not yet purchasable.
2. **Rebalance the coin economy.** A permanent ×20 yield is a 20× income ceiling;
   `Kitchen.maxStockPerRecipe` (99) throttles it, but shop/upgrade prices were
   tuned before this existed. Re-check the 42–58% per-serving margins from PR #30
   against a maxed café before this goes live.

**P2c follow-up (deferred, 2026-07-30):** cooking as a visitor. Cleaning and
serving were opened to a helper via `SocialService:TryWork`, but starting a cook
spends the **owner's** coins and pantry, so the same gate would hand a visitor a
way to drain a neighbour — it needs its own guardrails (an owner-set permission,
or a per-visitor spend cap). With `Kitchen.autoCollectCooks` on there is also no
physical collect ritual left to open. Hooks: `KitchenService.handleStartCook`
(currently keyed to the caller's own profile + `CafeService:IsNearOwnPlot`).

Carry-over (still owed, lower priority): **publish**; a live Robux purchase test
(IDs are real); the 2-player mischief-lure + neighbour-help playtest; the owner's
eyeball on the new Clouds sky + sea; VIP name-colour; a café-**style** picker in
the intro panel; the pre-existing `Graphics.spec` test failure (Coin/Coins glyph).

---

## 🎮 Gameplay vision — see docs/GAMEPLAY_UPGRADES.md

_The full backlog of what makes the game addictive & interactive (juice,
appliance upgrade trees, offline earnings, daily calendar, rush events,
ethical prestige, collection walls, social loops) — distilled from Café World,
Roblox tycoons, and restaurant sims. Recommends an **"S3.5 — Tycoon hooks"**
mini-step (appliance upgrades + offline earnings + daily rewards) between S3
and S4. Read it before planning any post-S3 work._

## ⭐ SESSION ROADMAP — 2026-07-15 — "Café World parity push" (5 steps)

_Owner feedback (screenshot review): the game doesn't LOOK like a café yet,
customers have no feelings, no floor/wall/land customisation, preparation
is invisible (the HUD still teaches the old press-E loop), and the roadmap
must be driven by the original Facebook game's full feature list. That list
now exists — **docs/CAFE_WORLD_PARITY.md** (49 features mapped ✅🟡❌🚫,
every gap assigned to a step below). Graphics come from curated Creator
Store models chosen by the owner — **docs/ASSET_SHOPPING_LIST.md**._

This ordering supersedes the phase order below until the 5 steps ship.
Old Phase 4 content = step S5. Parity codes (A4, D2…) refer to the parity doc.

### S1 — LOOK like a café: the Creator Store asset pipeline ✅ DONE (2026-07-15)
_Parity: D1, C4 · replaces procedural greybox with owner-picked models_
_Live-verified: 15/15 assets load; real machine/counter/oven/chair at correct
dimensions, clothed animated customer rigs, barista/waiter/cleaner rigs, food
props. Polish pass (dimensions, walk animations, pathfinding) also shipped._
- Claude: `Config/AssetManifest.luau` + `AssetLibraryService` — loads bought
  assets by ID at boot (InsertService), **strips all scripts** (security),
  auto-scales to grid footprints, caches templates, and **falls back to the
  procedural model** whenever an asset is missing → the game never breaks.
- Claude: BuildService/shop consume library models; CustomerService dresses
  customers from bought **rigged NPC packs** (8–12 looks); staff (Mia/Noah/
  Pia) get real barista/waiter looks; counters display bought food props.
- Owner: shopping trip — Priority 1 of docs/ASSET_SHOPPING_LIST.md (11 items,
  exact search terms + French click paths inside; paste links in chat).
- Every asset logged in docs/ASSET_LICENSES.md. Exit: before/after screenshot
  where a stranger says "café" in 1 second. **Then publish to cloud (HANDOFF §6.2).**

### S2 — Customers you can FEEL + a café that reads as a building ✅ CLOSED (2026-07-17)
_All shipped and live-verified: facade/auto-door/3x interiors/private gardens/
14-stud walls · service theater with four defined staff roles on walk-verified
rigs · owner works the café (take orders/clean/tips + COMBO streaks) · mood
faces + patience bars, storm-outs, persisted REGULARS with favourite dishes ·
Priorité 4 dressing (11 buyable interior items, auto-dressed gardens, real
street furniture + plaza fountain). Next: S3 — THE MENU._
_Original bullets kept below for history:_
- **[DONE early, in the S1 polish pass]** Natural NPC movement: real R6/R15
  **walk/idle animations** (NpcAnimator) and **PathfindingService routing
  around collidable furniture** (customers no longer slide or clip through
  tables). Object **dimensions** corrected (proportion-preserving scaling).
- Patience meter + **mood faces** over every customer (😊 → 😐 → 😠), hearts
  burst on fresh/mastered dishes, angry storm-out with a visible **Buzz −3**
  floater when stock runs dry or waits run long.
- Tips scale with mood at serve time (satisfaction you can price).
- **Regulars**: named repeat customers with a favourite dish and a greeting
  bubble ("Zoe's back — she loves Croissants!"); serving the favourite pays
  a loyalty bonus. Mobile-size touch targets, sound stingers on reactions.
- **[DONE 2026-07-16 — awaiting owner playtest]** Café facade + front door:
  proper front wall with windows, sign over the door, and an **auto-door**
  that swings open for players/customers/staff and closes behind them —
  the café is a building and the door is the only way in/out (fixes being
  trapped inside). Customers path through the door to an inside queue.
- **[DONE 2026-07-16 — awaiting owner playtest]** Bigger cafés + private
  gardens (owner request, pulled forward from S4 groundwork): interiors are
  **3x the floor area** (18×24 cells), every plot has a **fenced private
  garden** with a gate, and the interior deepens by `expansionTier` (24/28/32
  cells) — the S4 "buy land" flow only needs the purchase UI + pricing; the
  geometry, persistence field, placement clamps and rebuild path all work.
- Exit: 2 minutes of watching the room tells a story with zero UI reading.

### S3 — THE MENU: exact Café World parity (market + cookbook + prep)
_Parity: A4, A8, A9, A11, E5, D2-partial · the owner's "exact same menu as the
original" — full spec in **docs/MENU_SPEC.md**_
- **Tabbed Market** (replaces the flat Shop): Appliances · Counters · Tables &
  Chairs · Decorations · Floors · Wallpaper · Doors & Windows · Outdoor ·
  Expansions — Café-World-style item cards (icon, price, level lock, buy).
- **Cookbook parity**: full per-dish field set (level, cost, servings, price/
  serving, total, cook time 5 min→2 days, café points, appliance, mastery ★,
  source); grow to ~40–60 **original** dishes across families; extend the
  level ladder; recipe **sources** (level / mastery / goal-reward).
- **Appliance families**: buy **Drink Bar** + **Pastry Station** (each unlocks
  its recipe family); the cook picker filters to the appliance you walked up to.
- **Cook flow**: appliance-filtered picker with the full dish card, **today's
  menu / daily special**, **daily first-cook bonus**, and a 2–3-tap prep
  gesture — the manual ritual, no energy system ever.
- **Tutorial rewrite** to the real loop: place stove → cook → collect →
  counter feeds customers (kills the stale "press E" step in the screenshot).
- **Toolbar**: Cook · Market · Build · Decorate · Goals · Social · Settings.
- Exit: the Market and Cookbook feel like Café World's menus; a new player
  understands cook-ahead in 60 seconds; menu choice matters.

### S4 — Make it YOURS: floors, walls, doors, LAND
_Parity: D2, D3, D4, D5, D6, D7 · the owner's "customise like Café World"_
- **Decorate tab** in the shop: floor styles + wall palettes (original
  generated textures — checker, wood, tile), door & window styles (bought
  models), awning colours. Applied per café, persisted, visible to visitors.
- **Café expansion tiers**: grow the interior grid (e.g. 8×8 → 10×12 →
  12×16) for coins + level, Café-World-style pricing curve — visibly bigger
  room, more furniture cap.
- **Item storage**: stored/owned decor inventory so re-planning never loses
  purchases; décor score shown on the café sign (status!).
- Exit: two neighbouring cafés look meaningfully different at a glance.

### S5 — The SOCIAL café (old Phase 4, upgraded)
_Parity: F2, F3, F4, F5, F6, F8, F11, B9, D8_
- Daily visit coins per neighbour café; **stir-the-pot help** (+cook progress
  for them, coins for you, 1×/café/day); **daily gift crate** (ingredients,
  predefined, no trading); **visitor tip jar** at your café; **eat-mission
  daily goals** ("taste a dish at 2 neighbours").
- **Street Buzz leaderboard** on the plaza board; café **name signs** from a
  curated word list; photo spot. Two-client + mobile passes ride this step
  (HANDOFF §6.3/6.4).
- Exit: a second player materially improves your session, and you theirs.

---

## Phase 1 — THE LOOP PIVOT: cook-ahead kitchens (Week 2) ⭐ the big one

The classic magic wasn't serve-on-demand — it was **preparation**: start
dishes on stoves, come back to collect, keep counters stocked while a
stream of customers eats. This is the single biggest "feels like the
original" lever, and it's pure mechanics (not copyrightable).

- **Stoves cook in stages**: pick recipe → ingredients cost coins → timer
  (espresso 30s … feast recipes 10+ min) → COLLECT to a counter.
- **Counters hold servings** (e.g. espresso = 12 servings). Customers stream
  in, sit or queue, and consume from counter stock. No stock → grumpy exits
  and Buzz drops.
- **Buzz rating** (0–105): rises with fed customers, falls with walkouts.
  High Buzz = more/faster customers = more coins. THE score players chase.
- **Fresh bonus, never spoilage**: collecting within 2× cook time pays a
  bonus. Late food never rots (§35 — no punishment for sleeping).
- Brew minigame stays as the *quality* layer on collection (bonus coins).
- Existing OrderService/serve flow becomes the "counter service" path for
  drinks; plates flow through the new KitchenService.

Deliverables: `KitchenService`, stove/counter composite models with
**visible food** (pots steam while cooking, plates stack on counters),
`Config/Recipes` gains cookTime/servings/collectBonus, HUD stove timers,
Buzz meter on the HUD + above every café sign.

## Phase 2 — A café that looks ALIVE (Week 2–3, runs parallel)

- **Seated dining**: customers take chairs at tables, food plate appears in
  front of them, eat animation (bob + particles), tip left on table to tap.
- **NPC walk cycles**: leg-swing + bob animation on our chibi rigs; door
  chime + walk-in path through the actual front.
- **Juice everywhere**: coin burst on collect, steam on stoves, sparkle on
  mastery, star pop on Buzz-up, floating +XP text.
- **Interior décor value**: every placed item adds Décor points → shown on
  the sign; higher Décor = slightly higher tips (visible, understandable).
- **Aesthetic upgrade**: generated textures (gingham tabletops, wood grain,
  menu boards), awnings + terrace strip per café, string lights at dusk,
  window glow at night, curtains; second wall/floor palette per player
  (first customisation!).

## Phase 3 — Progression that grips (Week 3–4)

- **Recipe mastery stars** (cook N times → faster/cheaper/prettier + gold
  frame in the cookbook) — collection psychology, fully original art.
- **Cookbook UI**: page-flip book with dish cards, locked silhouettes tease
  the next unlock (the "one more level" pull).
- **20+ recipes** across coffee/tea/pastry/breakfast/lunch with real
  cook-time spread (30s → 8h overnight roast for the morning login).
- **Level-up moments**: full-screen tasteful celebration, +unlock reveal.
- **Daily goals** (3 rotating, e.g. "collect 4 dishes / greet 2 neighbours")
  + a 7-day streak shelf of trophies. No loss on a missed day — the shelf
  just waits (§35).
- **Staff v2**: hire waiter (auto-serves seated tables) and cleaner (clears
  plates, +Buzz); wages balance the automation; outfits per café theme.

## Phase 4 — The social city (Week 4–5)

- **Neighbour actions that matter**: visiting lets you do ONE helpful tap
  per café per day (stir a pot = +2 min cook progress for them, +coins for
  you) — the classic help-loop, rebuilt originally, fully whitelisted.
- **Street Buzz board**: plaza board ranks the lobby's cafés by Buzz — the
  status race that makes decor and uptime matter.
- **Gifting**: send a daily free ingredient crate to another player
  (predefined, no trading economy yet — no dupe risk).
- **Photo spot** + café sign customisation (name from a curated word list —
  moderation-safe, e.g. "Golden Bean Corner").
- **Weekly street goal**: lobby-wide "serve 500 dishes together" → street
  decoration unlock for everyone present.

## Phase 5 — Retention & LiveOps scaffolding (Week 5–6)

- **Appointment rhythm** (ethical): overnight recipes, morning fresh-bonus
  window, daily goals reset — reasons to return, never punishment.
- **Collections**: seasonal dish sets (complete the Autumn Menu → café
  trophy + unique furniture).
- **First event**: weekend Food Festival at the plaza (stalls, one special
  recipe, event currency → cosmetics only).
- **Analytics-driven tuning**: funnels (join→first collect→D1 return),
  Buzz distribution, drop-off steps; rebalance from data.

## Phase 6 — Monetisation + hardening (Week 6, only once the loop is fun)

- Cosmetics only at first: furniture collections, café themes (Parisian /
  Tropical / Retro Diner), staff uniforms, sign styles. Then one honest
  convenience pass (extra saved layout + double daily-goal slots). NO
  loot boxes, NO paid Buzz, NO pay-to-skip-timers at launch (§24/§35).
- ProfileStore session locking; migration tests; Open Cloud CI publishing
  (push-button staging/production); MicroProfiler pass at 30 players;
  low-end mobile test matrix.

## Phase 7 — Closed alpha → soft launch (Week 7–8)

- 10–20 testers; watch full sessions; fix top-3 drop-offs; economy
  rebalance; game-page assets (icon/thumbnail/trailer GIF); the NAME
  decision (distinctive, legally clear); production experience + staging;
  release checklist + rollback; limited public launch; daily triage.

---

## The 5 "top hit" levers we optimise for (in order)

1. **First 10 minutes** — from spawn to "my café is running and I get it".
2. **D1 return reason** — overnight recipe + fresh bonus + streak shelf.
3. **Visible status** — Buzz on every sign, street board, decor that shows.
4. **Session juice** — every tap pays sound + motion + number.
5. **Thumbnail truth** — the game page shows exactly the cosy street
   fantasy the first minute delivers.

## Explicitly deferred

Apartments · helpers-as-pets depth · multi-floor building · blueprint
sharing · delivery · second café branches · trading/free-market economy ·
UGC integration.
