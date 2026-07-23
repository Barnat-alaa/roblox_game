# Gameplay direction — the next build phase

_Owner-chosen feature set, refreshed 2026-07-23 to capture the **complete**
vision (this supersedes the trimmed same-day draft). This is no longer a menu of
options: it is what to build, in what order, and how to build it so it never
needs a rewrite. Written from reading the services, so every feature names the
code it hooks into — the precise, line-level hooks live in
`docs/IMPLEMENTATION_MAP.md`. The ethics rails in `HANDOFF.md` §1 are absolute;
every design below respects them (the one exception is flagged in §4b)._

**The prime directive, everywhere below:** the goal is not just to add features —
it is to make the game **significantly more engaging, social, replayable and
monetizable** while preserving the nostalgic Café-World feeling. Every mechanic
must give the player a **short-term**, a **medium-term**, and a **long-term**
goal, plus a reason to **visit neighbours**, **upgrade**, **spend Robux**, and
**come back tomorrow**. If a proposed change reinforces none of those, it does
not ship.

**And it must all be data-driven (§9).** New staff, ingredients, recipes, VIPs,
rewards, cosmetics and cities are added by editing a config table, never by
touching logic. We are building for years of live updates, not one release.

---

## 0. Why these features exist — the two problems they fix

Keep these in mind, because they are the point of everything below.

1. **There are no ingredients today.** `recipe.ingredientCost` is a coin
   deduction (`EconomyService:TrySpendCoins`) with no item, no stock, no
   supplier and no field in the player's save. The UI promises a system that
   does not exist. **Feature 2 makes it real.**

2. **The game automates away its own gameplay.** Every staff member you hire
   removes an action you used to perform — the waiter ends fetching plates, the
   cleaner ends scrubbing, the cook and barista end cooking. A player is most
   engaged in their first twenty minutes. **Features 1, 3 and 4 give the player
   things only they can do — buy and grow their crew, chase VIPs, and cooperate
   with or steal from the neighbours.**

The nine things a player can physically do today, and the services behind them,
are catalogued in the git history of this file (the 2026-07-22 version). Short
version: cook/collect at an appliance, brew, pick up and deliver plates, take
tips, clean, visit a neighbour — plus the menu decisions buried in a drawer.

---

## 1. Feature — Staff you start small, hire, and upgrade

**The pitch:** your café opens with just a barista and a waiter, both working at
a deliberately limited capacity. The Staff button is where you hire the rest of
the crew and pour money into each of them to make them work harder — a core
progression mechanic that must feel rewarding every single time.

### What the player sees and does

- **The café spawns with two staff: Barista and Waiter**, both at limited
  efficiency. Everyone else starts **locked**.
- The **Staff** dock button (slot 3) opens a panel with **one card per staff
  role, including every future role the player has not unlocked yet.** The full
  roster shown from day one:

  | Role | Ships in | What they do |
  | --- | --- | --- |
  | **Barista** | Now (starter) | brews drinks |
  | **Waiter** | Now (starter) | fetches & serves plates |
  | **Cleaner** | Phase A (locked→hire) | clears dirt / dirty plates |
  | **Chef** | Phase A (locked→hire) | cooks food recipes |
  | **Cashier** | Later | speeds tips / checkout, reduces walkouts |
  | **Manager** | Later | small buff to the whole crew |
  | **Delivery Worker** | Later | auto-restocks ingredients / offline deliveries |
  | **Entertainer** | Later | raises satisfaction / draws customers |

  > Today's code names the food cook `Cook`; the design name is **Chef**. Keep
  > the role key `Cook` internally (the recipes reference it) and show "Chef" in
  > the UI, or rename consistently — decide once in the roster config, §9.

- **Locked cards use the staff member's FINAL portrait, heavily blurred, with a
  lock overlay and the unlock requirement printed on them** (e.g. "Reach Lv 4"
  or "Hire — 1,200 🪙"). This is the exact locked treatment the shop/cookbook
  already use (`Components.ItemThumbnail`). Seeing the future crew you can't
  afford yet is the anticipation that creates long-term goals.
- Each hired staff has an **upgrade track shown as a percentage that starts at
  10% and rises in 10-point steps** — 10 → 20 → 30 → … → 100%. Each upgrade
  **visibly fills a progression bar** on the card. Every upgrade must land with
  **immediate, celebratory feedback**: a glow/sparkle burst and a "level up"
  pop on the NPC, a **rising sparkle/stars** animation on the card, a **sound
  stinger**, and a **celebration popup** — the player should feel rewarded, not
  just see a number change (reuse the `Fx` coin-burst/float-text style; a full
  banner for hitting 100%).
- The card also shows that staff member's **live capacity bar** — the same
  `staffCapacity` the café-health card already tracks — so the player can see
  who is tiring and decide who to upgrade next.

### Upgrades must improve real gameplay — per role

Every upgrade tier must produce a **noticeable** in-world change, not a hidden
stat. Target effects (exact curves are a build-time tuning pass, all in config):

- **Barista** — prepares drinks faster · fewer mistakes · queues more drinks at
  once · begins to multitask across orders.
- **Waiter** — walks faster · carries more plates per trip · smarter
  pathfinding · shorter service cycle.
- **Cleaner** — cleans faster · larger cleaning radius (clears more dirt per
  pass).
- **Chef** — cooks faster · larger batch yield · fewer failed batches.
- **Cashier / Manager / Entertainer / Delivery** (later) — each maps to a lever
  that already exists (walkout rate, crew-wide multiplier, satisfaction gain,
  offline restock).

The rule: **every employee becomes noticeably stronger** as you invest, and the
café visibly runs better.

### How it hooks into the code (the plumbing already fits)

- `Types.StaffMember` **already has `level` and `experience`.** Use `level` as
  the upgrade track (level 1 = 10%, level 10 = 100%) and add a `hired: boolean`
  so locked roles can exist in the save without being active.
- `DataService.starterStaff()` currently seeds all four roles at level 1 —
  change it to seed **Barista + Waiter as hired**, and Cleaner/Chef as
  **present-but-unhired** (or absent and created on hire). The full future
  roster lives in **config**, not in the save.
- `Operations.staffCapacityMax` (100) and `Operations.onlineRecoveryPerMinute`
  (per role) are the levers. Scale both by the staff's upgrade fraction so a
  higher level means a **bigger tank and a faster refill**:
  `capacity(role) = staffCapacityMax * (0.4 + 0.6 * level/10)` (tune later).
  `CafeOperationsService` already reads `staffCapacity[role]` per role — it just
  needs the max and recovery to come from the staff's level instead of the flat
  constant. Per-role work-rate multipliers (cook/serve/clean speed) come from
  the same fraction.
- Staff **photos already render** — rig thumbnails were verified loading
  (`staff:Barista/Cook/Waiter/Cleaner` in `AssetManifest`). Feed the rig
  `assetId` to `ItemThumbnail`. New future roles need new portraits — **owner
  supplies** those when their phase arrives.

### Robux (see §5)

Players may **instantly hire a locked role, instantly max an upgrade track, or
buy an upgrade pack** — but every one of those is also fully earnable with coins.
Robux buys *time*, never *power that can't be ground*.

### Art: **have the four current roles.** Rig thumbnails render; the locked-blur
treatment exists. Future-role portraits: **owner supplies** at their phase.

---

## 2. Feature — Ingredients you buy at the market

**The pitch:** every recipe needs real ingredients kept as stock in your pantry.
You travel to the city market, buy them in bulk on a proper shopping trip, watch
them run down as the kitchen cooks, and restock before you run dry — because
running dry **stops production**. This turns a silent coin cost into a visible,
planned supply loop.

### What the player sees and does

- Every recipe **consumes ingredients from a shared pantry**, not just coins.
  Manual cooking and automatic production both **draw** from stock; when an
  ingredient hits zero, the recipes that need it **cannot be made** — a real,
  visible stop (a clear "Out of milk!" state), never a silent coin failure.
- The **Market** is a place you **travel to** (the city market), so buying feels
  like a real shopping trip — not a one-tap drawer. **Buy in bulk**, and do not
  force tiny purchases: offer **×25 / ×50 / ×100 / ×250 / Max**, with a bulk
  discount so the big crate is cheaper per unit.
- Each ingredient shows **its own icon, its current quantity, its rarity, and
  its unlock level.**
- **Locked ingredients appear exactly like locked staff:** the real icon
  **blurred**, a **lock overlay**, and the **unlock level** printed on the card.
  The player always sees the future palette.
- The **pantry inventory** (a drawer already exists) shows current stock per
  ingredient with a **low-stock warning**, so the player knows what to restock
  before a rush.

### The ingredient palette (14, shared across the 14 recipes)

A small shared set keeps the market readable and makes bulk-buying matter (one
crate of flour feeds four pastries). Each ingredient carries a **rarity** and an
**unlock level** in config. Representative mapping — exact per-recipe amounts are
a build-time tuning pass:

| Ingredient | Feeds | Ingredient | Feeds |
| --- | --- | --- | --- |
| Coffee Beans | all 5 coffees | Bread | both sandwiches |
| Milk | cappuccino, latte, mocha | Cheese | sandwiches, quiche |
| Tea Leaves | tea, iced tea | Tomato | sandwiches, fruit bowl |
| Sugar | most drinks + pastries | Ham | sandwiches, quiche |
| Flour | all 4 pastries | Chocolate | mocha, cinnamon roll |
| Eggs | croissant, muffin, quiche | Lemon | iced tea, fruit bowl |
| Butter | pastries | Berries | muffin, fruit bowl |

The palette is defined in `Config/Ingredients` and **grows by adding rows** —
Vanilla, Caramel, Ice, Matcha, Croissant Dough and the rest slot in with a name,
icon, rarity and unlock level, and are immediately available to reference from
any recipe.

### How it hooks into the code

- Keep `recipe.ingredientCost` as the **coin price of a restock** if useful, but
  add a data-driven `recipe.ingredients = { flour = 2, egg = 1, … }` table.
- Add a `pantry: { [string]: number }` field to `Types.PlayerData`, healed on
  read like the other nested shapes, with a `schemaVersion` bump + `migrate`
  branch.
- `KitchenService.handleStartCook` and `ProductionService`'s automatic tick
  **check pantry stock before starting a job** and **decrement on start** — a
  new failure reason `out_of_ingredients` alongside the existing `stove_busy`.
- The market purchase adds to `pantry` via a validated server remote, same guard
  shape as `PurchaseItem` (ownership, price, rate-limit — see
  `docs/IMPLEMENTATION_MAP.md`).

### Robux (see §5)

Instantly unlock an ingredient, buy an **ingredient bundle**, an **emergency
pack** when you run dry mid-rush, or a **premium crate** — all also buyable with
coins. Convenience, never pay-to-win.

### Art: **have all 14.** 11 are direct **Kenney Food Kit** renders (CC0); 3 are
CC0 recolours (coffee beans, tea leaves, butter), a pipeline already proven (the
iced-tea dish icon is a recolour). **Nothing needs buying.** Slicing/recolour
pipeline: `scripts/slice_icon_sheet.py` + the render recipe in
`docs/ASSET_LICENSES.md`. New ingredients beyond the 14 that aren't in the Food
Kit: **owner supplies** an icon (or asks for a recolour).

---

## 3. Feature — VIP customers and the lobby-wide draw

**The pitch:** rare VIPs walk the city and go to the **best café on the server**.
Keep your café attractive and busy and you win the VIP — who eats, tips big, and
leaves behind a **gift box** you walk over and open for a reward. VIPs create
exciting, talked-about moments and give every player a reason to improve.

### What the player sees and does

- A **VIP spawns in the shared city/plaza occasionally** (a server-level event,
  **not** per-café) and **evaluates every café**, then walks to the most
  attractive/active one. The evaluation is a weighted score built from levers
  the player controls:
  **decoration score · cleanliness · popularity/Buzz · reputation · number of
  active staff · current player activity.** Start with one or two factors
  (Buzz + recent throughput) and widen the formula over time — it lives in
  config so it can be tuned without code changes.
- A small street banner ("✨ A VIP is choosing a café!") raises the stakes for
  everyone and makes the contest legible.
- The VIP sits, places a **premium order** (worth more, or a special dish),
  eats, and **on leaving drops a large gift box** at the table or the café
  entrance — it does **not** just disappear.
- The player **walks to the box and presses E to open it** (proximity prompt).
  **Reward: coins + reputation now**, delivered from a **weighted reward table**
  built so it can later hand out **furniture, decorations, exclusive skins,
  ingredient bundles, cosmetics, staff skins, boost items and seasonal
  collectibles** — new reward types are added by appending a row.

> **This is a gift box, not a loot box.** It is *earned by play*, never *paid to
> open at random*. Paid randomised boxes violate the ethics rails and Roblox
> policy — opening stays free and the odds are irrelevant to money.

### How it hooks into the code

- `CustomerService` today spawns customers **per café**. The VIP is a **new
  server-level spawner** that periodically scores every online café, picks the
  leader, and routes one VIP model to it — reusing the existing NPC nav/anim.
- The gift box is a new interactable (modelled on the tip prompt in
  `CustomerService`), granting via `EconomyService` from a weighted reward table.
- Reuse the regulars scaffolding (`pickRegular`) for a "named, recurring VIP"
  feel later (a regular who becomes a VIP after N visits — ties to
  `GAMEPLAY_UPGRADES.md` 5.4).

### Art: VIP NPC model — **owner supplies.** Gift box + open VFX — **built
procedurally.**

---

## 4. Feature — Neighbour help, and the mischief mechanics

Two mechanics that make other players matter — one cooperative, one competitive.
Both must stay **fun, never toxic**.

### 4a. Help a neighbour (co-op, positive-sum)

Walk into a neighbour's café and do something genuinely useful. Helping must
**always feel worthwhile** and feed a **friendship** relationship. Each action is
one prompt, **capped per neighbour per day** (anti-farm):

| You do | They get | You get |
| --- | --- | --- |
| **Water their plants** | décor stays lush | Coins · XP · **Friendship Points** |
| **Bus / clean a table** | cleanliness back | Reputation · Ingredient Pack · Friendship |
| **Restock supplies** — carry an ingredient crate | faster stock | Coins · a random ingredient · daily bonus |
| **Stir a pot** — add cook progress | faster stock | Coins · Reputation |
| **Hand out flyers** at their door — pull one passing customer in | a customer | Reputation |

Future co-op: **decorate together**, **repair a machine**, **deliver an order**,
**daily cooperative tasks**.

**Friendship rewards.** Helping raises a per-neighbour **friendship level** that
pays out **daily rewards, exclusive furniture/decorations, unique badges, and
special boosts** — the ladder that makes repeated social visits worthwhile.
Completing a help also lands a **"Good Neighbour" daily bonus** and counts toward
a goal.

**Hooks:** `SocialService` already validates `VisitCafe` and enforces a
one-compliment-per-pair-per-session anti-farm — extend that exact pattern to help
actions with a per-neighbour-per-day cap. This is the fully-whitelisted,
rails-clean social layer.

### 4b. Mischief — steal customers (competitive, light-hearted)

Light competitive mechanics that stay **playful, never griefing.**

- **Smell Bomb.** A deployable that fills your café with **green aromatic
  vapour** for a short window with strong VFX and a funny animation. Nearby
  customers become attracted; some may **leave a nearby café and come to yours.**
  Has a **cooldown** and a **balanced duration**.
- **Manual recruitment.** Walk up to a **wandering customer**, press **E**, and
  try to convince them to visit your café. **Higher reputation raises the success
  rate; VIPs are harder to convince.**

> ⚠️ **This is the one mechanic that brushes the rails.** "No fake urgency" and
> the whitelisted-only social stance were written for a gentle builder;
> customer-stealing is aggressive. It can be fun and fair, but it needs guard
> rails, and the owner should sign off on them:
> - **Earned or bought consumable with a cooldown** — not spammable.
> - **A visible telegraph** (the green vapour) so the neighbour *sees* it happen.
> - **Manual and limited** — press E to pull, **one customer at a time**, only
>   customers **not yet served**; **immunity periods** and a **max stolen** cap
>   so a rival café is never emptied.
> - **Partial resistance for VIPs**, so they can't be trivially yanked.
> - **No lasting harm** — a stolen customer is one sale, not a permanent loss;
>   nobody's progress is destroyed.
> With those it is a spicy booster, not a griefing tool. **Objective: playful
> competition, not frustration.**

**Hooks:** a new consumable in `PlayerData`, a placement + timed VFX (procedural
green particle volume via `Fx`), and a manual-pull remote that re-targets a
customer's active visit in `CustomerService` toward the caster's café — subject
to the cooldown/immunity/cap checks above.

### Art: green vapour VFX + gift box — **built procedurally.** Consumable/booster
icons — **built in the existing style** (or owner supplies).

---

## 5. Monetisation — the full slate (honest about the tension)

The rails say **cosmetics-only, no pay-to-win, no loot boxes, one honest pass.**
The owner wants Robux for staff, upgrades, ingredients and boosters — which edges
past cosmetics-only. **The safe rule that reconciles both: anything buyable with
Robux must also be buyable with coins. Robux only skips the grind; it never buys
power you cannot earn.** With that rule, here is the full slate.

### Clean cosmetics — zero tension

- **Cosmetic staff skins** — Italian Barista, French Chef, Japanese Café Uniform,
  Halloween, Christmas, Cyberpunk, Vintage Café.
- **Café decoration packs** — Paris, Tokyo, Beach, Luxury, Cottage, Industrial.
- **Café themes, signage, awnings** — pure cosmetic.
- **Premium gift boxes** — **cosmetic rewards only, no gameplay advantage** (and
  never a paid random box — see the loot-box rule).

### Recurring / membership

- **VIP Membership** — extra daily rewards, an exclusive badge, larger ingredient
  storage, additional save slots, a unique name colour, faster walking, bonus
  reputation. (Convenience + cosmetic; the ingredient-storage cap must not gate
  power a free player can't reach through play.)
- **Gamepasses** — extra staff slot, auto-collect, bigger offline cap, a one-time
  "Founder" pack.
- **Seasonal Battle Pass** — decorations, furniture, skins, particles, titles,
  emotes. Generous and additive; no fake-urgency punishment for missing it.

### Accelerators — fine as *time-savers*, not power

Each of these is **also earnable with coins/gameplay**:

- **Instantly hire locked staff · instantly unlock ingredients · instantly max an
  upgrade · buy upgrade packs / ingredient bundles / emergency packs.**
- **Time savers** — Instant Ingredient Delivery, Staff Training Boost, Double
  Coins (temporary), Double Reputation, Construction Speed Boost.
- **Smell-bomb booster** — sellable, but kept **cooldown- and skill-gated** (§4b)
  so money buys *opportunity*, not guaranteed theft.

### Mandatory engineering

`ProcessReceipt` **must be idempotent** (`docs/SECURITY.md`): a dropped callback
must never double-grant or drop a purchase. `MonetizationService` is a stub
today; this is where it gets built — **and only after the core loop is proven
fun (Phase D).**

---

## 6. Build order — and what each phase changes about how the game *feels*

| Phase | Ship | The game now feels… |
| --- | --- | --- |
| **A** | Ingredients (§2) + Staff hire/upgrade panel (§1) | like it has *substance* — you plan supply and grow a crew, and presence matters again |
| **B** | VIP + gift box (§3) | like there is *something to chase* every session |
| **C** | Neighbour help + friendships + mischief (§4) | like the *other players are real* — allies and rivals |
| **D** | Monetisation pass (§5) | like a *finished product* — only after A–C prove the loop is fun |

Do **A first**: it fixes the two diagnosed problems at once (a system that did
not exist, and a game that plays itself). Each phase is split into small,
testable, independently-shippable steps — implement → **test in Roblox Studio**
→ fix → commit → PR → CI green → merge, never skipping the Studio test.

**Phase A is itself sequenced** (see `docs/IMPLEMENTATION_MAP.md` for the exact
hooks):
1. **Ingredients backbone** — `Config/Ingredients`, `recipe.ingredients`,
   `PlayerData.pantry` + schema migration, pantry check/decrement in
   Kitchen/Production, `out_of_ingredients`. _(data + server; no new art)_
2. **Market UI + buy remote** — travel-to-market, bulk tiers, locked-blur cards,
   pantry drawer with low-stock warning.
3. **Staff data model** — `hired` flag, level-as-upgrade-track, level-scaled
   capacity/recovery/work-rate; seed only Barista + Waiter.
4. **Staff panel UI** — 4 cards (blurred locks), hire, 10→100% upgrade bar, live
   capacity bar, upgrade celebration VFX.

---

## 7. What I have vs. what the owner supplies

| Asset | Status |
| --- | --- |
| Ingredient art (14) | **Have** — 11 direct Kenney Food Kit (CC0), 3 recolours; nothing to buy |
| Staff photos (4 current) | **Have** — rig thumbnails render; locked-blur treatment built |
| Future staff portraits (Chef beyond, Cashier, Manager, Delivery, Entertainer) | **Owner supplies** at their phase |
| VIP NPC model | **Owner supplies** |
| Green vapour + gift box + upgrade VFX | **Built procedurally** |
| Consumable / booster / ingredient-beyond-14 icons | **Owner supplies**, or built in-style |
| Cosmetic skins / decor packs / battle-pass art | **Owner supplies** at Phase D |
| Monetisation sign-off | **Owner** — confirm "Robux buys accelerators, not power," and the §4b smell-bomb guard rails |

---

## 8. Do not build (still true)

- **Staff wages.** `Config/Staff.baseSalary` sits unused. Charging for staff
  before staff are fun only adds friction. (Hiring the *locked* roles is
  different — that is a one-time unlock, not a recurring drain.)
- **More levels, yet.** Past level 10 on an empty loop is just a longer empty
  loop. These features give level 10 something to do; extend the ladder
  (`GAMEPLAY_UPGRADES.md` 2.1) *after*.
- **Paid random boxes / gacha, ever.** Banned by the rails and by Roblox policy.

---

## 9. Future-proofing & the data-driven mandate

Every system above is built so the owner can run it as a live game for years,
adding content by editing config, not logic. Concretely:

- **Config-first.** Staff roster, ingredient palette, recipe ingredient tables,
  VIP scoring weights, gift-box/neighbour reward tables, upgrade curves, market
  bulk tiers and prices, and monetisation SKUs all live as typed tables in
  `src/shared/Config`. Adding a staff role, an ingredient, a reward, or a city
  is a new row — no `if` chains, no hardcoded values in services.
- **Additive saves.** Every new persisted shape ships with a `schemaVersion`
  bump, a `migrate` branch, and `reconcile` defaults, so old saves upgrade
  cleanly (`tests/SaveMigration.spec.luau` before any schema change).
- **Reward tables, not reward code.** VIP gift boxes, friendship payouts and
  daily bonuses all read from weighted tables so new reward *types* (furniture,
  skins, boosts, seasonal collectibles) are appended, never special-cased.
- **Roles as levers.** Each future staff role maps to an existing tuning lever
  (walkout rate, crew multiplier, satisfaction, offline restock) so the panel
  scales without new subsystems.

Designed this way, the roadmap's later ambitions — **new staff, new ingredients,
new recipes, new cities, new VIPs, seasonal events, special customers, pets,
café chains, franchises, neighbourhood competitions, guilds, festivals** — are
content drops on top of these systems, not rewrites of them.
