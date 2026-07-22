# Gameplay direction — the next build phase

_Owner-chosen feature set, 2026-07-23. This is no longer a menu of options: it is
what to build, and in what order. Written from reading the services, so every
feature names the code it hooks into. The ethics rails in `HANDOFF.md` §1 are
absolute and every design below respects them (the one exception is flagged)._

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
   things only they can do — buy and grow their crew, chase VIPs, and fight
   over customers with the neighbours.**

The nine things a player can physically do today, and the services behind them,
are catalogued in the git history of this file (the 2026-07-22 version). The
short version: cook/collect at an appliance, brew, pick up and deliver plates,
take tips, clean, visit a neighbour — plus the menu decisions buried in a drawer.

---

## 1. Feature — Staff you start small, hire, and upgrade

**The pitch:** your café opens with just a barista and a waiter, both working at
a limited capacity. The Staff button is where you hire the cook and cleaner,
and where you pour money into each of your crew to make them work harder.

### What the player sees and does

- **The café spawns with two staff: Barista and Waiter.** The **Cook** and
  **Cleaner** start **locked**.
- The **Staff** dock button (slot 3) opens a panel of four cards, one per crew
  member. Each card shows the staff member's **photo**; a locked one is shown
  **blurred**, exactly like the locked shop/cookbook art (reuse
  `Components.ItemThumbnail`). A locked card's action is **Hire**.
- Each hired staff has an **upgrade track shown as a percentage that starts at
  10% and rises 10% per upgrade** — 10 → 20 → … → 100%. Each upgrade:
  - costs coins (and can be bought with Robux — see §5),
  - plays a **special effect on the NPC** — a glow/sparkle burst and a "level
    up" pop (reuse the `Fx` coin-burst/float-text style), and
  - **raises their working capacity**: they produce, serve or clean more before
    their shift capacity runs out.
- The card also shows that staff member's **live capacity bar** — the same
  `staffCapacity` the café-health card already tracks — so the player can see who
  is tiring and decide who to upgrade.

### How it hooks into the code (the plumbing already fits)

- `Types.StaffMember` **already has `level` and `experience`**. Use `level` as
  the upgrade track (level 1 = 10%, level 10 = 100%), or add a `hired` boolean.
- `DataService.starterStaff()` currently seeds all four at level 1 — change it to
  seed only Barista and Waiter, and gate Cook/Cleaner behind a hire.
- `Operations.staffCapacityMax` (100) and `Operations.onlineRecoveryPerMinute`
  (per role) are the levers. Multiply both by the staff's upgrade fraction so a
  higher level means a bigger tank **and** faster refill: `capacity(role) =
  staffCapacityMax * (0.4 + 0.6 * level/10)` or similar. `CafeOperationsService`
  already reads `staffCapacity[role]` per role — it just needs the max and
  recovery to come from the staff's level instead of the flat constant.
- Staff **photos already render** — the rig thumbnails were verified loading
  earlier (`staff:Barista/Cook/Waiter/Cleaner` in `AssetManifest`). Feed the rig
  `assetId` to `ItemThumbnail`.

### Art: **have it.** Staff rig thumbnails render; the locked-blur treatment
already exists. Nothing to buy.

---

## 2. Feature — Ingredients you buy at the market

**The pitch:** every recipe needs real ingredients, kept as stock in your
pantry. You buy them in bulk at the market, watch them run down as the kitchen
cooks, and restock before you run dry — because running dry stops production.

### What the player sees and does

- Every recipe **consumes ingredients from a shared pantry**, not just coins.
  Cooking / automatic production **draws** from stock; when an ingredient hits
  zero, the recipes that need it **cannot be made** — a real, visible stop, not
  a silent coin failure.
- The **Market** (a tab in the Shop, or its own button) sells ingredients.
  **Buy in bulk** — crates of ×10 / ×50 / ×100, with a bulk discount so the big
  crate is cheaper per unit. This is the "buy in large quantities" the owner
  asked for.
- Each ingredient shows **its own photo**. Ingredients gated behind a level are
  shown **blurred** with the level requirement, exactly like locked shop items.
- The pantry drawer (already exists) shows current stock per ingredient with a
  low-stock warning, so the player can see what to restock.

### The ingredient palette (14, shared across the 14 recipes)

A small shared set keeps the market readable and makes bulk-buying matter (one
crate of flour feeds four pastries). Representative mapping — exact per-recipe
amounts are a build-time tuning pass:

| Ingredient | Feeds | Ingredient | Feeds |
| --- | --- | --- | --- |
| Coffee Beans | all 5 coffees | Bread | both sandwiches |
| Milk | cappuccino, latte, mocha | Cheese | sandwiches, quiche |
| Tea Leaves | tea, iced tea | Tomato | sandwiches, fruit bowl |
| Sugar | most drinks + pastries | Ham | sandwiches, quiche |
| Flour | all 4 pastries | Chocolate | mocha, cinnamon roll |
| Eggs | croissant, muffin, quiche | Lemon | iced tea, fruit bowl |
| Butter | pastries | Berries | muffin, fruit bowl |

### How it hooks into the code

- Keep `recipe.ingredientCost` as the **coin price of a restock**, but add a
  `recipe.ingredients = { flour = 2, egg = 1, … }` table.
- Add a `pantry: { [string]: number }` field to `Types.PlayerData`, healed on
  read like the other nested shapes.
- `KitchenService.handleStartCook` and `ProductionService`'s automatic tick
  **check pantry stock before starting a job** and **decrement on start** — a
  new failure reason `out_of_ingredients` alongside the existing `stove_busy`.
- The market purchase adds to `pantry` via a validated remote, same shape as
  `PurchaseItem`.

### Art: **have all 14.** 11 are direct **Kenney Food Kit** renders (CC0) — milk,
sugar, flour, eggs, berries, bread, cheese, tomato, ham, chocolate, lemon. 3 are
**recolours** of Food Kit renders (coffee beans, tea leaves, butter), which CC0
permits and which I have already proven works (the iced-tea dish icon is a
recolour). **Nothing needs buying.** A rendered proof sheet exists in the
session scratchpad; the slicing/recolour pipeline is `scripts/slice_icon_sheet.py`
plus the render recipe in `docs/ASSET_LICENSES.md`.

---

## 3. Feature — VIP customers and the lobby-wide draw

**The pitch:** VIPs walk the street and go to the busiest café on the server.
Keep your café humming and you win the VIP — who eats, tips big, and leaves a
gift box you open for a reward.

### What the player sees and does

- A **VIP spawns in the lobby** (the shared street / plaza), **not** per-café,
  and walks to the **most active café on the server** — a live contest, so being
  busy is what attracts them. "Most active" = highest recent throughput (serves
  in the last few minutes) or highest current Buzz; pick one and show it (a small
  "VIP heading to the busiest café!" street banner raises the stakes for
  everyone).
- The VIP sits, places a **premium order** (worth more, or a special dish),
  eats, and on leaving **drops a large gift box** at the table or the café
  entrance.
- The player **walks to the box and opens it** (proximity prompt, press E).
  **Reward: coins now**, built as a reward *table* so it can later hand out
  cosmetics, upgrade tokens or ingredient crates.

> **This is a gift box, not a loot box.** It is *earned by play*, never *paid to
> open at random*. Paid randomised boxes violate the ethics rails and Roblox
> policy — keep opening free and the odds irrelevant to money.

### How it hooks into the code

- `CustomerService` today spawns customers **per café** (each player's own
  queue). The VIP is a **new server-level spawner** that periodically measures
  every online café's activity, picks the leader, and routes one VIP model to
  it. Owner **supplies the VIP NPC model**.
- The gift box is a new interactable (like the tip prompt in `CustomerService`),
  granting via `EconomyService:AddCoins` from a weighted reward table.
- Reuse the regulars scaffolding already in `CustomerService` (`pickRegular`) for
  the "named, recurring" feel if desired.

### Art: VIP NPC model — **owner supplies.** Gift box + open VFX — I build
procedurally.

---

## 4. Feature — Neighbour help, and the smell bomb

Two mechanics that make other players matter — one cooperative, one competitive.

### 4a. Help a neighbour (co-op, positive-sum)

Walk into a neighbour's café and do something useful. Three options, one prompt
each, **once per neighbour per day** (anti-farm):

| You do | They get | You get |
| --- | --- | --- |
| **Bus a table** — clear a dirty plate | cleanliness back | small coin tip + "helped" token |
| **Stir a pot** — add cook progress to a batch | faster stock | coins + reputation |
| **Hand out flyers** at their door — pull one passing customer in | a customer | reputation |

Completing a help lands a **"Good Neighbour" daily bonus** and counts toward a
goal. **Rewards are coins + reputation**, capped per neighbour per day.

**Hooks:** `SocialService` already validates `VisitCafe` and enforces a
one-compliment-per-pair-per-session anti-farm — extend that same pattern to help
actions. This is the fully-whitelisted, rails-clean social layer.

### 4b. Smell bomb (competitive — steal customers)

A deployable that fills **your café with green vapour** for a short window,
boosting your draw. Inside the window you can **press E to manually pull a
nearby customer toward your café — especially a VIP.**

> ⚠️ **This is the one mechanic that brushes the rails.** "No fake urgency" and
> the whitelisted-only social stance were written for a gentle builder;
> customer-stealing is aggressive and PvP-flavoured. It can absolutely be fun and
> fair, but it needs guard rails, and the owner should sign off on them:
> - **Earned or bought consumable** with a **cooldown** — not spammable.
> - **A visible telegraph** (the green vapour) so the neighbour *sees* it happen.
> - **Manual and limited** — you press E to pull, one customer at a time, and
>   only customers **not yet served**, so it is a skill grab, not an automatic
>   drain that empties a rival café.
> - **No lasting harm** — the stolen customer is one sale, not a permanent loss;
>   nobody's progress is destroyed.
> With those, it is a spicy booster rather than a griefing tool. Without them it
> risks making the game feel unfair, which is exactly what the rails guard
> against.

**Hooks:** a new consumable in `PlayerData`, a placement + timed VFX (procedural
green particle volume), and a manual-pull remote that re-targets a customer's
`runActiveVisit` in `CustomerService` toward the caster's café.

### Art: green vapour VFX — I build procedurally. Consumable icon — I can make one
in the existing style.

---

## 5. Monetisation — suggestions (honest about the tension)

The rails say **cosmetics-only, one honest pass, no pay-to-win, no loot boxes.**
The owner wants Robux for **staff, upgrades, ingredients and boosters**, which
edges past cosmetics-only. Here is what is clean, and where to be careful.

### Clean — recommended

- **Cosmetic skins**: café themes, staff uniforms, signage, decor packs. Pure
  cosmetic, zero tension.
- **Gamepasses**: an extra staff slot, auto-collect, a bigger offline cap, a
  one-time "Founder" pack.
- **The VIP gift box stays free to open, always.** Its contents may include
  cosmetics, but you never *pay to open a random box* — that is a loot box, and
  it is banned here and restricted by Roblox policy.

### The owner's asks — fine as *accelerators*, not power

The safe rule: **anything buyable with Robux must also be buyable with coins.**
Robux only skips the grind; it never buys power you cannot earn.

- **Buy staff / upgrades / ingredients with Robux** — acceptable when the same
  hire, upgrade or crate is fully earnable with coins. It becomes pay-to-win the
  moment a Robux-only staff or upgrade grants something you cannot grind. Keep
  every purchasable also grindable.
- **Smell bomb booster** — sell it, but keep it **cooldown- and skill-gated** so
  money buys *opportunity*, not guaranteed theft. If cash could buy an unlimited
  auto-steal, that is pay-to-win; the guard rails in §4b prevent it.

### Mandatory

`ProcessReceipt` **must be idempotent** (`docs/SECURITY.md`) — a dropped
callback must never double-grant or drop a purchase. `MonetizationService` is a
stub today; this is where it gets built, and only after the loop is proven fun.

---

## 6. Build order — and what each phase changes about how the game *feels*

| Phase | Ship | The game now feels… |
| --- | --- | --- |
| **A** | Ingredients (Feature 2) + Staff hire/upgrade panel (Feature 1) | like it has *substance* — you plan supply and grow a crew, and presence matters again |
| **B** | VIP + gift box (Feature 3) | like there is *something to chase* every session |
| **C** | Neighbour help + smell bomb (Feature 4) | like the *other players are real* — allies and rivals |
| **D** | Monetisation pass (Feature 5) | like a *finished product* — only after A–C prove the loop is fun |

Do A first: it fixes the two diagnosed problems at once (a system that did not
exist, and a game that plays itself).

---

## 7. What I have vs. what the owner supplies

| Asset | Status |
| --- | --- |
| Ingredient art (14) | **Have** — 11 direct Kenney Food Kit (CC0), 3 recolours; nothing to buy |
| Staff photos | **Have** — rig thumbnails render; locked-blur treatment already built |
| VIP NPC model | **Owner supplies** |
| Smell-bomb green vapour + gift box VFX | **I build procedurally** |
| Consumable / booster icons | **I make in the existing style** |
| Monetisation decision | **Owner** — sign off on "Robux buys accelerators, not power," and on the smell-bomb guard rails |

---

## 8. Do not build (still true)

- **Staff wages.** `Config/Staff.baseSalary` sits unused. Charging for staff
  before staff are fun only adds friction. (Hiring the *locked* cook/cleaner is
  different — that is a one-time unlock, not a recurring drain.)
- **More levels.** Past level 10 on an empty loop is just a longer empty loop.
  These features give level 10 something to do; add the levels after.
