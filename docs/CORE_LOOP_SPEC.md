# Core loop spec — recipes, ingredients, machines, production & monetisation

_Created 2026-07-24 at the owner's request. This is the **design + balance
document to review before building.** Every number here is a **proposed choice**
you can approve or change — the point is that you see exactly what I picked and
whether it's balanced, *before* it ships. §1–§4 are now **built and LIVE**
(`Kitchen.useProductionPlan` + `enforceIngredients` ON); §1 was balanced
2026-07-25 (this pass) and the numbers below reflect that._

**How to read it**
- **Status** on each system: ✅ exists · 🟡 partly exists · 🔴 new/redesign.
- **Choice:** a decision + number I'm proposing. Change any of them.
- All numbers live in `src/shared/Config/*` — never hardcoded in logic.

---

## 1. Every recipe carries four facts ✅ (balanced 2026-07-25)

Each recipe defines **(1) required level, (2) the machine, (3) the staff, (4) the
ingredients** — all in data, and the Cookbook shows the required-level pill.

**How a serving earns.** Auto-production (the plan model, §4) makes recipes **one
serving at a time**, drawing that recipe's `ingredients` table from the pantry —
so **ingredient amounts are PER SERVING**. Each serving sells for
`floor(basePrice × Kitchen.servingPayoutFraction)` (= half the menu price today),
and the ingredients were pre-paid at the market. The real margin is therefore
**serving pay − ingredient cost**, and the 2026-07-25 balance pass retuned every
recipe to a healthy **42–58%** (50–65% once you bulk-buy). *(Before the pass the
tables were authored per-batch but consumed per-serving, so the cheapest recipes
sat at a 0-coin margin — the bug this pass fixed.)*

| Recipe | Lvl | Machine | Staff | Ingredients (per serving) | Menu | Serving | Cost | Margin |
| --- | ---: | --- | --- | --- | ---: | ---: | ---: | ---: |
| Espresso | 1 | Coffee Machine | Barista | Coffee Beans ×1, Sugar ×1 | 12 | 6 | 3 | 3 (50%) |
| House Tea | 1 | Coffee Machine | Barista | Tea Leaves ×1, Sugar ×1 | 12 | 6 | 3 | 3 (50%) |
| Cappuccino | 2 | Coffee Machine | Barista | Coffee Beans ×1, Milk ×1, Sugar ×1 | 20 | 10 | 5 | 5 (50%) |
| Café Sandwich | 2 | Prep Station | Cook | Bread ×1, Cheese ×1, Tomato ×1, Ham ×1 | 28 | 14 | 8 | 6 (43%) |
| Croissant | 3 | Stone Oven | Cook | Flour ×1, Butter ×1, Eggs ×1 | 24 | 12 | 7 | 5 (42%) |
| Silky Latte | 4 | Coffee Machine | Barista | Coffee Beans ×1, Milk ×2, Sugar ×1 | 24 | 12 | 7 | 5 (42%) |
| Berry Muffin | 4 | Stone Oven | Cook | Flour ×1, Eggs ×1, Berries ×1 | 26 | 13 | 7 | 6 (46%) |
| Garden Iced Tea | 5 | Coffee Machine | Barista | Tea Leaves ×1, Lemon ×1 | 18 | 9 | 5 | 4 (44%) |
| Sunrise Fruit Bowl | 5 | Prep Station | Cook | Berries ×1, Lemon ×1, Tomato ×1 | 30 | 15 | 8 | 7 (47%) |
| Velvet Mocha | 6 | Coffee Machine | Barista | Coffee Beans ×1, Milk ×1, Chocolate ×1, Sugar ×1 | 32 | 16 | 9 | 7 (44%) |
| Cinnamon Swirl | 6 | Stone Oven | Cook | Flour ×1, Butter ×1, Chocolate ×1, Sugar ×1 | 36 | 18 | 10 | 8 (44%) |
| Terrace Club | 7 | Prep Station | Cook | Bread ×2, Cheese ×1, Tomato ×1, Ham ×2 | 42 | 21 | 12 | 9 (43%) |
| Overnight Roast † | 8 | Coffee Machine | Barista | Coffee Beans ×8, Sugar ×2 | 50 | 25 | 18 | ~24 |
| Morning Quiche | 9 | Stone Oven | Cook | Flour ×1, Eggs ×2, Cheese ×1, Ham ×1 | 48 | 24 | 10 | 14 (58%) |

_**Menu** = `basePrice` (what the cookbook shows). **Serving** =
`floor(basePrice × 0.5)`, the coins one served serving pays (before tips + the
manual-cook bonus). **Cost** = market value of the per-serving ingredient table
at base unit price (`ingredientCost` mirrors it). **Margin** = Serving − Cost.
Every recipe is profitable; bulk-buying widens each margin further._

_† **Overnight Roast** is the 8-hour appointment: cooked as ONE 40-serving batch
(never in the per-hour plan), so its table is **per batch** — the Cost/Margin
above are per batch (≈0.45 coins of ingredients per serving)._

- **Choice — "croissant needs dough":** you named *dough + butter*. I kept the
  base palette (Flour + Butter + Eggs) rather than adding a separate "Dough"
  ingredient, because Flour already feeds all four pastries and a small shared
  palette keeps the market readable. **If you'd rather have "Croissant Dough" as
  its own item, it's a one-row change** — say the word.
- **Balance pass (2026-07-25):** tables are now per-serving; House Tea 10→12,
  Garden Iced Tea 16→18 and Croissant 22→24 got small menu-price nudges; Cheese
  and Ham (tagged *common*) dropped 3→2 to match the other commons. Guarded by
  `tests/Recipes.spec.luau`. See §4e for the income this produces.

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
| Cheese | common | 2 | 2 | sandwiches, quiche |
| Tomato | common | 2 | 2 | sandwiches, fruit bowl |
| Ham | common | 2 | 2 | sandwiches, quiche |
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

Espresso after the 2026-07-25 pass: a serving pays `floor(12 × 0.5) = 6` and
costs **3** coins of ingredients (2.5 with bulk) → **~3–4 net per serving**.

| Scenario | Plan | Output/hr | Net coins/hr |
| --- | --- | --- | ---: |
| Barista **Lv 1** (15 min) online | 15 espresso | 15 | **~50** |
| Barista **Lv 5** (35 min) online | 35 espresso | 35 | ~120 |
| Barista **Lv 10** (60 min) online | 60 espresso | 60 | ~210 |
| Barista **Lv 1** offline 8 h (÷20) | 15 espresso | 15×8÷20 = **6 in 8 h** | ~18 / 8 h |

- **Reading it:** a fresh café earns **~120 coins/hr** of hands-off barista output
  at Lv 1, rising to ~210/hr at Lv 10 — a **~4× reward** for maxing a staffer, which
  keeps the upgrade track meaningful. Idle over a full night nets a small **~18
  coin** "welcome back," so it's a nudge to return, never a replacement for playing
  (respects `ECONOMY_BALANCE.md`: "automation must not trivialise the economy").
  Espresso is the cheapest recipe; a mixed, upgraded kitchen out-earns this floor
  by a wide margin (Quiche nets ~14/serving).
- **Balance decisions — CONFIRMED by owner 2026-07-24:**
  1. **÷20 offline** — kept as-is (idle stays a small welcome-back nudge).
  2. **60 min/hr at Lv 10** — kept (a maxed staffer works the full hour; 15→60 curve).
  3. **One Cook, one budget** across Oven + Prep (split into Chef/Cook later).
  4. **Keep Flour** (shared palette) — no separate "Dough" ingredient; croissant =
     Flour + Butter + Eggs.
  5. **Contained income (2026-07-25)** — a serving stays at ½ the menu price; the
     balance pass fixed thin margins by retuning per-serving ingredient tables to
     42–58%, **not** by raising payout, so shop / upgrade / monetisation prices
     stay valid. Lifting serving pay to the full menu price (≈2× income) was
     considered and deferred — it needs a full economy rebalance.

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
| 2 | Show the **required level** on Cookbook cards | ✅ done (#22) |
| 3 | Machine↔product↔staff map consistent | ✅ verified |
| 4 | Ingredient palette + unlock levels + bulk market | ✅ have (#18–20) |
| 5 | Live **Owned** count in inventory | ✅ have |
| 6 | **Zero/low critical warning** (row + HUD) | ✅ done (#22) |
| 7 | Ingredient **monetisation** (bundles / instant-unlock, idempotent) | ✅ done (#28) |
| 8 | **New auto-production** (min/hr per level, allocate plan) | ✅ LIVE (#24/#25) |
| 9 | **Offline ÷20** simulation on the new model | ✅ LIVE |
| 10 | Chef/Cook capacity defined | ✅ defined (§5) |
| 11 | Turn ingredient **enforcement** on (`Kitchen.enforceIngredients`) | ✅ ON |
| 12 | **Per-serving margin balance** — every recipe 42–58% | ✅ done (2026-07-25) |

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
