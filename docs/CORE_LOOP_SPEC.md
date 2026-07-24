# Core loop spec — recipes, ingredients, machines, production & monetisation

_Created 2026-07-24 at the owner's request. This is the **design + balance
document to review before building.** Every number here is a **proposed choice**
you can approve or change — the point is that you see exactly what I picked and
whether it's balanced, *before* it ships. Nothing in §4 (the new auto-production
model) is built yet; §1–§3 are partly built and flagged._

**How to read it**
- **Status** on each system: ✅ exists · 🟡 partly exists · 🔴 new/redesign.
- **Choice:** a decision + number I'm proposing. Change any of them.
- All numbers live in `src/shared/Config/*` — never hardcoded in logic.

---

## 1. Every recipe carries four facts 🟡

You asked each recipe to define: **(1) required level, (2) the machine, (3) the
staff, (4) the ingredients** (a recipe can need several — e.g. a croissant needs
more than one). All four already exist in data; the only gap is **showing the
required level in the Cookbook** (today it shows machine + ingredients but the
level only appears on *locked* recipes).

| Recipe | Lvl | Machine | Staff | Ingredients (per batch) | Sells | Margin* |
| --- | ---: | --- | --- | --- | ---: | ---: |
| Espresso | 1 | Coffee Machine | Barista | Coffee Beans ×2, Sugar ×1 | 12 | 8 |
| House Tea | 1 | Coffee Machine | Barista | Tea Leaves ×2, Sugar ×1 | 10 | 7 |
| Cappuccino | 2 | Coffee Machine | Barista | Coffee Beans ×2, Milk ×1, Sugar ×1 | 20 | 13 |
| Café Sandwich | 2 | Prep Station | Cook | Bread ×2, Cheese ×1, Tomato ×1, Ham ×1 | 28 | 17 |
| Croissant | 3 | Stone Oven | Cook | Flour ×2, Butter ×1, Eggs ×1 | 22 | 14 |
| Silky Latte | 4 | Coffee Machine | Barista | Coffee Beans ×2, Milk ×2, Sugar ×1 | 24 | 15 |
| Berry Muffin | 4 | Stone Oven | Cook | Flour ×2, Eggs ×1, Berries ×1, Sugar ×1 | 26 | 16 |
| Garden Iced Tea | 5 | Coffee Machine | Barista | Tea Leaves ×2, Lemon ×1, Sugar ×1 | 16 | 10 |
| Sunrise Fruit Bowl | 5 | Prep Station | Cook | Berries ×1, Lemon ×1, Tomato ×1 | 30 | 18 |
| Velvet Mocha | 6 | Coffee Machine | Barista | Coffee Beans ×2, Milk ×1, Chocolate ×1, Sugar ×1 | 32 | 20 |
| Cinnamon Swirl | 6 | Stone Oven | Cook | Flour ×2, Butter ×1, Chocolate ×1, Sugar ×1 | 36 | 22 |
| Terrace Club | 7 | Prep Station | Cook | Bread ×3, Cheese ×1, Tomato ×1, Ham ×2 | 42 | 26 |
| Overnight Roast | 8 | Coffee Machine | Barista | Coffee Beans ×8, Sugar ×2 | 50 | 20 |
| Morning Quiche | 9 | Stone Oven | Cook | Flour ×2, Eggs ×2, Cheese ×1, Ham ×1 | 48 | 28 |

_*Margin = sell price − the ingredient coin cost (`ingredientCost`), before tips
and the manual-cook bonus. Every recipe is profitable._

- **Choice — "croissant needs dough":** you named *dough + butter*. I kept the
  base palette (Flour + Butter + Eggs) rather than adding a separate "Dough"
  ingredient, because Flour already feeds all four pastries and a small shared
  palette keeps the market readable. **If you'd rather have "Croissant Dough" as
  its own item, it's a one-row change** — say the word.
- **Choice — show all four facts in the Cookbook:** add the required level to
  each recipe card (currently only machine + ingredients show). Small change.

---

## 2. Machine ↔ product ↔ staff map ✅ (verified consistent)

Every recipe points at exactly one machine, and every machine has products.
Verified against `Config/Recipes` — no orphans.

| Machine | Made by | Products |
| --- | --- | --- |
| **Coffee Machine** | Barista | Espresso, House Tea, Cappuccino, Silky Latte, Garden Iced Tea, Velvet Mocha, Overnight Roast |
| **Stone Oven** | Cook | Croissant, Berry Muffin, Cinnamon Swirl, Morning Quiche |
| **Prep Station** | Cook | Café Sandwich, Sunrise Fruit Bowl, Terrace Club |

- The cook picker already **filters to the machine you walk up to**, and auto-
  production already **requires the right machine placed + the right staff hired**.
- **Note — Overnight Roast** is an 8-hour "appointment" batch. It monopolises the
  Coffee Machine for 8h, so in the new production model (§4) it is handled as a
  **separate appointment cook**, not part of the per-hour minute budget.
- **Choice — one machine per product is enforced in data**; adding a product =
  give it an `applianceId` that exists. A future "each machine can be **upgraded**"
  (faster/bigger) slots on top without changing this map.

---

## 3. Ingredients: market, inventory, warnings, monetisation

### 3a. Palette + unlock levels ✅
14 shared ingredients, each with a rarity and an **unlock level** (same locked-
blur logic as recipes/shop). Buy in bulk **×25 / ×50 / ×100 / ×250 / Max** with a
per-unit discount for bigger crates.

| Ingredient | Rarity | Unlock Lv | Unit price | Feeds |
| --- | --- | ---: | ---: | --- |
| Coffee Beans | common | 1 | 2 | all 7 coffees |
| Sugar | common | 1 | 1 | most drinks + pastries |
| Tea Leaves | common | 1 | 2 | teas |
| Milk | common | 2 | 2 | cappuccino, latte, mocha |
| Bread | common | 2 | 2 | sandwiches |
| Cheese | common | 2 | 3 | sandwiches, quiche |
| Tomato | common | 2 | 2 | sandwiches, fruit bowl |
| Ham | common | 2 | 3 | sandwiches, quiche |
| Flour | uncommon | 3 | 2 | all 4 pastries |
| Eggs | uncommon | 3 | 2 | croissant, muffin, quiche |
| Butter | uncommon | 3 | 3 | croissant, cinnamon roll |
| Berries | uncommon | 4 | 3 | muffin, fruit bowl |
| Lemon | rare | 5 | 3 | iced tea, fruit bowl |
| Chocolate | rare | 6 | 4 | mocha, cinnamon roll |

### 3b. Inventory evolution + a zero/critical warning 🟡→🔴
- The Market already shows **Owned: N** per ingredient, live. ✅
- **New:** a stock-state signal on every row and a HUD alert:
  - **Choice — thresholds:** `Owned = 0` → **red "OUT — buy now"** (critical);
    `1 ≤ Owned ≤ 5` → **amber "Low"**; else normal.
  - When a cooking recipe **can't run because an ingredient is at 0**, fire a HUD
    toast ("Out of Milk — 3 recipes stopped") so you know to restock. (This is
    what the `enforceIngredients` flag turns on — see §4/§6.)

### 3c. Monetisation of ingredients 🔴 (new — needs your sign-off)
Robux, kept rails-clean: **anything buyable with Robux is also earnable with
coins/level.** Robux only skips the grind.

| Product (Robux) | Also earnable? | What it does |
| --- | --- | --- |
| **Ingredient bundle** (e.g. Coffee Beans ×500) | Yes — market | one big top-up |
| **Emergency restock** (top every low ingredient to a floor) | Yes — market, tediously | one-tap convenience mid-rush |
| **Instant unlock** an ingredient below its level | Yes — by levelling | skip the level gate (convenience, not power) |

- **Engineering (mandatory):** `MonetizationService.ProcessReceipt` must be
  **idempotent** — key on `receiptInfo.PurchaseId`, store a `grantedReceipts` set
  on the save, grant once, return `PurchaseGranted` only after the grant persists,
  `NotProcessedYet` otherwise. Product→reward mapping is a config table; amounts
  are server-side, never client-sent. (`docs/SECURITY.md`.)
- **Choice — no random/paid loot boxes, ever** (banned by the rails + Roblox
  policy). Bundles are fixed contents.

---

## 4. Auto-production — the new model 🔴 (redesign; replaces the capacity meter)

**Today:** staff have an abstract "shift capacity" (0–100) that drains as they
auto-work and refills while you're online; you set a target stock + priority per
product. It works but it's opaque.

**Your model (clearer, and what we'll build):** each staff **works a number of
minutes per hour that grows with their level**, can only make **their** products,
each product **costs minutes**, and **you allocate** the minutes into a plan.

### 4a. Work-minutes per hour, by staff level
- **Choice — curve:** `workMinutesPerHour(level) = 15 + (level − 1) × 5`.
  So **Barista Lv 1 = 15 min/hr** (your example) → Lv 10 = **60 min/hr** (a full
  hour). Same curve for the Cook; tunable per role in config.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Work min/hr** | 15 | 20 | 25 | 30 | 35 | 40 | 45 | 50 | 55 | 60 |

- The staff **upgrade track** (the 10→100% bar in the direction) becomes this
  min/hr number — clearer to show "Barista: 15 → 20 min/hr" than an abstract %.

### 4b. Minutes each product costs
- **Choice** (rounded to clean minutes; you said coffee 1 min, tea 1.5 min):

| Product | Min | Product | Min |
| --- | ---: | --- | ---: |
| Espresso | 1.0 | Café Sandwich | 2.0 |
| House Tea | 1.5 | Sunrise Fruit Bowl | 1.5 |
| Cappuccino | 1.5 | Terrace Club | 3.0 |
| Silky Latte | 2.0 | Croissant | 2.0 |
| Garden Iced Tea | 1.5 | Berry Muffin | 2.5 |
| Velvet Mocha | 2.0 | Cinnamon Swirl | 3.0 |
| Overnight Roast | *appointment (8h), outside the budget* | Morning Quiche | 4.0 |

### 4c. You allocate the minutes (the production plan)
The player sets **how many of each product per hour**, capped by the staff's
minute budget. Example, **Barista Lv 1 (15 min/hr)**:
- **All espresso:** 15 × 1.0 = 15 min → **15 espresso/hr, 0 tea** (your example).
- **Mixed:** 9 espresso (9 min) + 4 tea (6 min) = 15 min → **9 espresso + 4 tea**.
- The UI shows a **minute bar** filling as you add products, and blocks going over.
- Production also needs **ingredients in the pantry** and **counter space**; if an
  ingredient hits 0 the plan pauses that product (§3b warning).

### 4d. Online vs offline
- **Online:** the plan runs in real time — each product completes on its minute
  cost, draws ingredients, fills the counter, waiters serve it.
- **Offline:** **production capacity ÷ 20** (your rule; already the game's
  `offlineTimeMultiplier`). We simulate the plan at 1/20 rate over the time away
  (capped at 8 h), estimate sales, and show a **"while you were away: +$X"** on
  return. Active play always out-earns idle by design.

### 4e. Worked example — is it balanced?

| Scenario | Plan | Output/hr | Gross margin/hr |
| --- | --- | --- | ---: |
| Barista **Lv 1** (15 min) online | 15 espresso | 15 | **~120** |
| Barista **Lv 5** (35 min) online | 35 espresso | 35 | ~280 |
| Barista **Lv 10** (60 min) online | 60 espresso | 60 | ~480 |
| Barista **Lv 1** offline 8 h (÷20) | 15 espresso | 15×8÷20 = **6 in 8 h** | ~48 / 8 h |

- **Reading it:** a fresh café earns **~120 coins/hr** of hands-off barista output
  at Lv 1, rising to ~480/hr at Lv 10 — a **4× reward** for maxing a staffer, which
  makes the upgrade track meaningful. Idle over a full night nets a small **~48
  coin** "welcome back," so it's a nudge to return, never a replacement for playing
  (respects `ECONOMY_BALANCE.md`: "automation must not trivialise the economy").
- **Balance decisions — CONFIRMED by owner 2026-07-24:**
  1. **÷20 offline** — kept as-is (idle stays a small welcome-back nudge).
  2. **60 min/hr at Lv 10** — kept (a maxed staffer works the full hour; 15→60 curve).
  3. **One Cook, one budget** across Oven + Prep (split into Chef/Cook later).
  4. **Keep Flour** (shared palette) — no separate "Dough" ingredient; croissant =
     Flour + Butter + Eggs.

---

## 5. Chef / Cook production capacity 🔴

- **Choice — one Cook, one budget, both machines.** The Cook uses the **same
  min/hr curve** (Lv 1 = 15) and allocates across **oven pastries + prep-station
  food**. So a Lv 1 Cook doing all croissants (2 min) = ~7 croissants/hr; or 3
  croissants (6 min) + 4 sandwiches (8 min) ≈ 14 min.
- **Choice — split later:** the direction's roster has a **Chef**. When hiring
  deepens, split into **Chef → Oven** and **Cook → Prep**, each with its own
  budget (doubles kitchen throughput and gives two upgrade tracks). Flagged, not
  built now.
- Pantry draw is per §1's ingredient tables; the Cook's plan pauses a product when
  its ingredient is at 0, same as the Barista.

---

## 6. What exists vs. what's new (build checklist)

| # | Item | Status |
| --- | --- | --- |
| 1 | Recipe: level / machine / staff / ingredients in data | ✅ have |
| 2 | Show the **required level** on Cookbook cards | 🔴 small add |
| 3 | Machine↔product↔staff map consistent | ✅ verified |
| 4 | Ingredient palette + unlock levels + bulk market | ✅ have (#18–20) |
| 5 | Live **Owned** count in inventory | ✅ have |
| 6 | **Zero/low critical warning** (row + HUD) | 🔴 new |
| 7 | Ingredient **monetisation** (bundles / instant-unlock, idempotent) | 🔴 new |
| 8 | **New auto-production** (min/hr per level, allocate plan) | 🔴 redesign |
| 9 | **Offline ÷20** simulation on the new model | 🟡 divisor exists, rewire |
| 10 | Chef/Cook capacity defined | 🔴 new (this doc) |
| 11 | Turn ingredient **enforcement** on (`Kitchen.enforceIngredients`) | 🟡 flag off |

---

## 7. Config that will hold all of this (data-driven, no hardcoding)

- `Config/Recipes` — add `productionMinutes` per recipe (§4b); `requiredLevel`,
  `applianceId`, `staffRole`, `ingredients` already there.
- `Config/Ingredients` — add `lowStockThreshold`; palette already there.
- `Config/Staff` — `workMinutesBase = 15`, `workMinutesPerLevel = 5`, per-role
  overrides, plus `hireCost` / `maxLevel` for the hire+upgrade feature.
- `Config/Economy` — bulk tiers (have), plus the Robux product→reward table.
- `PlayerData` — `pantry` (have), `productionPlan: {[role]: {[recipeId]: number}}`,
  `grantedReceipts` (monetisation idempotency).

Approve or edit the numbers above and I'll build to them. The **build order** is
in `ROADMAP.md` (updated 2026-07-24).
