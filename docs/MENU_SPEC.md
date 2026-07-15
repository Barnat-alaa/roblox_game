# Menu rework spec — Café World parity (Step S3)

_Created 2026-07-15 at the owner's request: "I want the exact same menu as the
original Facebook game." This specs the **structure and mechanics** of Café
World's two menus so we rebuild them faithfully — with **100% original dish
names, item art, and icons** (recipe names and art are copyrightable; the
structure/mechanics are not — see docs/ART_DIRECTION.md & docs/ASSET_LICENSES.md).
Source: [Café World Cookbook wiki](https://cafeworld.fandom.com/wiki/Cookbook),
[Neighbors](https://cafeworld.fandom.com/wiki/Neighbors), Gamezebo walkthrough._

Café World actually has **two "menus" plus a toolbar** — this doc covers all three.

---

## 1. The bottom toolbar (always visible)

Café World's spade/hammer toolbar. Ours today: Build · Shop · Goals · Cookbook.
Target set (chunky rounded icons, bottom-centre per ART_DIRECTION):

| Button | Opens | Have? |
|---|---|---|
| 🍳 Cook | Cookbook / dish picker at a stove | 🟡 (Cookbook exists) |
| 🛒 Market | the buy-menu (tabs below) | 🟡 (flat Shop) |
| 🔨 Build | move/rotate/store placed items | ✅ |
| 🎨 Decorate | floors / walls / doors / windows | ❌ (S4) |
| 🏆 Goals | daily goals + trophies | ✅ |
| 👥 Social | visit neighbours / gifts | 🟡 |
| ⚙️ Settings | audio, reduced FX | ✅ |

**Work:** replace the flat "Shop" with a **tabbed Market**, split **Build** vs
**Decorate**, add **Cook** and **Social** as first-class toolbar buttons.

---

## 2. The MARKET (buy-menu) — the big one

Café World's Market is a **tabbed catalogue**; each tab is a grid of item cards
(icon, name, coin/cash price, level lock). Our current Shop is one flat list —
this is what "rework the menu" most concretely means.

### Tabs to build (mirror Café World's categories)

| Tab | Sells | Ours today | Work (S3/S4) |
|---|---|---|---|
| **Appliances** | Coffee Machine, Stove(s), Drink Bar, Pastry Station, Deep Fryer, Pizza Oven, Ice-Cream Cart, BBQ… (each unlocks a recipe family + more cook slots) | coffee/oven/prep | add Drink Bar + Pastry Station first; card shows "unlocks X recipes" |
| **Counters** | serving counters (hold more servings) | 1 counter | tiers: bigger counters = more stock |
| **Tables & Chairs** | seating sets (more seats = more diners) | table+chairs | more styles; sets |
| **Decorations** | plants, lamps, rugs, wall art, dividers | 3 decor | breadth (25+), Décor score |
| **Floors** | floor styles applied to the whole café | ❌ | S4 Decorate |
| **Wallpaper / Walls** | wall styles | ❌ | S4 Decorate |
| **Doors & Windows** | swappable styles | ❌ | S4 + facade (S2) |
| **Outdoor** | awnings, terrace sets, signage, planters | 🟡 awnings | S4 |
| **Expansions** | grow the café floor (coins + level, Café-World-style) | ❌ | S4 |

Each card = **icon + name + price (coins) + level lock + "Buy"** (grey when
locked/too poor). Some premium items were Café Cash — **we keep those to
cosmetics only, no pay-to-win** (§24/§35). Card tap → buy → item goes to the
**Build/Decorate inventory** to place (never lost).

**Card states to implement:** affordable / too-expensive / level-locked /
already-owned-unique. Search + "sort by newest/level/price" like the original.

---

## 3. The COOKBOOK (cook-menu) — dish catalogue

Café World's Cookbook is the heart of the menu: **every dish is a card** with a
fixed data shape. We already have a Cookbook UI and 14 recipes; the rework is
**data breadth + the exact field set + recipe sources + appliance families**.

### Per-dish fields (mirror the wiki table exactly)

`level` · `ingredientCost` (coins to start) · `servings` (counter stock per
batch) · `pricePerServing` · `totalPrice` · `cookTime` (**5 min → 2 days**
spread) · `cafePoints` (XP) · `appliance` (which family) · `masteryThresholds`
(3★) · `source` (see below). Our `Config/Recipes` already has most; add
`pricePerServing`/`cafePoints`/`appliance` where missing and widen the spread.

### Recipe SOURCES (Café World's cookbook sections — all "keep forever")

1. **Level-unlocked** — the main ladder (Café World: ~120 levels; ours to Lv 9
   → extend). Each level unlocks 1–2 dishes.
2. **Mastery-unlocked** — master a dish to reveal a variant (we have mastery;
   add a few mastery-gated recipes).
3. **Goal-reward** — finish a goal chain → unlock a dish (ties to S3 goal chains).
4. **Catering-reward** — from the catering minigame (Phase 5).
5. **VIP** — premium/loyalty dishes (cosmetic-tier only for us).
6. **Seasonal / Limited** — event dishes that, once earned, stay (S5/Phase 5;
   **no FOMO** — earning window is generous, never punished — §35).

### Appliance families (each appliance gates a dish family — Café World-exact)

| Appliance | Family | Have? |
|---|---|---|
| Coffee Machine | espresso/latte/mocha/coffee | ✅ |
| Drink Bar | iced tea, juice, smoothie, soda | ❌ (S3 — buy Drink Bar) |
| Stove | soups, mains, stir-fries | ✅ (oven/prep) |
| Pastry Station | croissants, cakes, donuts | ❌ (S3 — buy Pastry Station) |
| Pizza Oven | pizzas, flatbreads | ❌ (later) |
| Deep Fryer | fries, fish n chips, wings | ❌ (later) |
| Ice-Cream Cart | desserts, sundaes | ❌ (later) |
| BBQ Grill | ribs, skewers, roast | ❌ (later) |
| Bread/Toaster Oven | breakfast, toasts | ❌ (later) |

### Original dish catalogue (target ~40–60 dishes, ALL original names)

Mirror Café World's **cook-time economics** (short cheap dishes → long premium
dishes), never its names. Example ladder (original, illustrative — final list
in `Config/Recipes`):

- **Coffee bar:** Espresso (30s) · Flat White · Caramel Macchiato · Cold Brew (8h overnight).
- **Drink bar:** Garden Iced Tea · Berry Lemonade · Mango Smoothie · House Soda.
- **Pastry:** Butter Croissant (5m) · Berry Muffin · Cinnamon Swirl · Triple-Berry Cheesecake (12h).
- **Stove mains:** Café Sandwich (5m) · Onion Soup (4h) · Terrace Club (18h) · Slow Pot Roast (2 days).
- **Breakfast:** Sunrise Eggs · Buttermilk Stack · Morning Quiche.

Cook-time tiers to reproduce: **5 min · 15–45 min · 1–4 h · 6–12 h · 18–24 h ·
2 days** (the overnight/appointment rhythm — the D1-return lever, §35-ethical).

---

## 4. The COOK FLOW (walk up to a stove → pick a dish)

Café World: click a stove → cookbook opens filtered to that appliance → pick →
pay ingredients → cook. Ours: prompt on the appliance opens the picker. **Work:**
filter the picker to the appliance's family, show the full per-dish card
(cost/servings/time/CP/mastery ★), a **"today's menu" / daily special** marker
(S3), and the 2–3-tap prep gesture before the timer (S3).

---

## 5. Current state → gaps → work items

**Have:** Cookbook UI, 14 recipes with cost/time/servings/mastery, a flat Shop,
Build mode, coffee/stove appliances.

**Menu-rework work items (S3 unless noted):**
1. **Market tabs** — refactor Shop into a tabbed catalogue (Appliances,
   Counters, Tables&Chairs, Decorations, + Floors/Walls/Doors/Windows/Outdoor/
   Expansions stubbed for S4). Item-card component with lock/afford states.
2. **Appliance families** — add Drink Bar + Pastry Station appliances (models in
   docs/ASSET_SHOPPING_LIST.md P3), each unlocking its recipe family; filter the
   cook picker by appliance.
3. **Recipe data widen** — add `pricePerServing`/`cafePoints`/`appliance`/
   `source` to `Config/Recipes`; grow to ~40–60 original dishes across families
   with the full cook-time spread; extend the level ladder past Lv 9.
4. **Recipe sources** — wire mastery-unlock + goal-reward recipes (catering/VIP/
   seasonal are Phase 5).
5. **Cook flow** — appliance-filtered picker, full dish card, daily special +
   daily first-cook bonus, prep-tap gesture.
6. **Toolbar** — Cook / Market / Build / Decorate / Goals / Social / Settings.
7. **Decorate menu (S4)** — Floors/Walls/Doors/Windows tabs actually apply
   styles; Expansions tab grows the plot.

**Acceptance:** a player opens the Market and sees Café-World-style tabs of
buyable items; opens the Cookbook and sees a full dish catalogue with the exact
field set, unlocked by level/mastery/goals; walks to a stove and the picker is
filtered to that appliance's family with a daily special. All names/art original.

---

## 6. Legal guardrail (do not skip)

Mirror **structure, field set, economics, and flow** — never Café World's dish
names, descriptions, icons, or art. Every dish name and icon is ours (or vetted
Creator-Store/original per ASSET_LICENSES.md). When in doubt, rename further away.
