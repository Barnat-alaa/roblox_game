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
4. 🔴 **Recipe/inventory polish** — show the **required level** on cookbook cards
   (the 4th recipe fact); **zero/low critical warning** on market rows + a HUD
   "out of X" alert (`CORE_LOOP_SPEC` §1, §3b).
5. 🔴 **Staff data model** — `hired` flag, level, per-role `workMinutesPerHour`
   curve (Lv1 = 15 min/hr); seed Barista + Waiter only; unify the 3 hardcoded role
   lists so new roles are pure config.
6. 🔴 **New auto-production** — replace the capacity meter with the **minutes-per-
   hour allocation** model: a `productionPlan` per staff, `productionMinutes` per
   recipe, online real-time + **offline ÷20** simulation (`CORE_LOOP_SPEC` §4–§5).
   Then flip `enforceIngredients` on.
7. 🔴 **Staff panel UI** — cards (blurred locks), hire, the min/hr upgrade track,
   the allocation-plan editor with a minute bar, upgrade celebration.
8. 🔴 **Ingredient monetisation** — idempotent `ProcessReceipt`, Robux bundles /
   instant-unlock, every SKU also coin/level-earnable (`CORE_LOOP_SPEC` §3c).

Non-negotiables carried from below: server-authoritative, data-driven, no loot
boxes, no pay-to-win, no fake-urgency, and **tested in Roblox Studio before every
merge**.

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
