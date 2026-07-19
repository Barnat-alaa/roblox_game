# Graphics coverage audit — every item & feature

_Created 2026-07-19 (owner request): for every sellable/menu item and every
game feature, does a real graphic (Creator Store model/mesh/texture) back it,
or is it still procedural greybox / a text placeholder? Legend: ✅ real asset ·
🟡 procedural placeholder (works, but greybox) · ❌ needs a graphic to buy._

Sources of truth: `Config/AssetManifest.luau` (furniture/world/props/food/
rigs), `Config/Graphics.luau` (HUD icons + surfaces), `Config/Furniture.luau`
(shop catalogue), `Config/Recipes.luau` (menu).

---

## A. MENU ITEMS (14 recipes) — food you cook & serve

All 14 map to a real mesh in the **Retro Food Pack** (`assetId 134670664555156`,
`AssetManifest.retroPropPack`), with the category props as a second fallback.
**Every dish has a graphic ✅** — but several are loose approximations you may
want to replace with an accurate mesh later (flagged 🔁).

| Dish | Current mesh (from the pack) | Status |
|---|---|---|
| Espresso | Starblox Coffee | ✅ |
| Cappuccino | Hot Chocolate w/ marshmallows | ✅ |
| House Tea | Teapot | ✅ |
| Croissant | 8-bit Donut | 🔁 (not a croissant) |
| Café Sandwich | Cheeseburger | 🔁 (burger ≠ sandwich) |
| Silky Latte | Chocolate Milk | ✅ |
| Berry Muffin | Muffin | ✅ |
| Garden Iced Tea | Bloxiade (soda) | ✅ |
| Sunrise Fruit Bowl | Fruit Bowl | ✅ |
| Velvet Mocha | Hot Chocolate | ✅ |
| Cinnamon Swirl | Pancakes | 🔁 |
| Terrace Club | Double Cheeseburger | 🔁 |
| Overnight Roast Blend | Pirate Cup | ✅ |
| Morning Quiche | Apple Pie | 🔁 |

_Optional buy: accurate meshes for the 5 🔁 dishes (croissant, sandwich,
cinnamon roll, club sandwich, quiche) — search terms in section E._

---

## B. SHOP / FURNITURE (the Build & Shop catalogue)

| Catalogue item | Real model? | Status |
|---|---|---|
| Coffee Machine | AssetManifest ✅ | ✅ |
| Stone Oven | AssetManifest ✅ | ✅ |
| Service Counter | AssetManifest ✅ | ✅ |
| Wooden Chair | AssetManifest ✅ | ✅ |
| Wall Painting | AssetManifest ✅ | ✅ |
| Menu Board | AssetManifest ✅ | ✅ |
| Hanging Lamp | AssetManifest ✅ | ✅ |
| Plant Shelf | AssetManifest ✅ | ✅ |
| Wall Shelf | AssetManifest ✅ | ✅ |
| Wall Clock | AssetManifest ✅ | ✅ |
| Window Curtains | AssetManifest ✅ | ✅ |
| Diner Booth | AssetManifest ✅ | ✅ |
| Bar Stool | AssetManifest ✅ | ✅ |
| Coat Rack | AssetManifest ✅ | ✅ |
| Cake Display | AssetManifest ✅ | ✅ |
| **Prep Station** | procedural greybox | ❌ **BUY** |
| **Round Table** | procedural greybox | ❌ **BUY** |
| **Potted Plant** | procedural greybox | ❌ **BUY** |
| **Floor Lamp** | procedural greybox | ❌ **BUY** |
| **Round Rug** | procedural greybox | ❌ **BUY** |

**5 shop items still greybox** → section E.

---

## C. CHARACTERS (staff + customers)

| Who | Asset | Status |
|---|---|---|
| Customers (4 looks) | walking rigs ✅ | ✅ |
| Cook (Sam) | Chef NPC rig ✅ | ✅ |
| Waiter (Noah) | Butler rig ✅ | ✅ |
| Barista (Mia) | walking base + apron | 🟡 (no dedicated barista rig) |
| Cleaner (Pia) | Mom base + apron | 🟡 (no dedicated maid rig) |

_Optional buy: a dedicated **barista** and **maid/cleaner** rig (must have a
HumanoidRootPart or the walk gate rejects it) — section E._

---

## D. WORLD & UI — all covered ✅

| Feature | Backing | Status |
|---|---|---|
| Garden dressing (flowers, hedges, bench, lantern, trees) | world assets | ✅ |
| Street (lampposts, mailbox, hydrant, trees) | world assets | ✅ |
| Plaza fountain | world asset | ✅ |
| Ground surfaces (sidewalk, road L/straight/R, wood floor) | Graphics textures | ✅ |
| Sky | cloud sky texture | ✅ |
| HUD icons (coin, rep, level, Buzz, goals, cookbook, build, shop, pantry) | Simulator Icon Pack | ✅ |
| Plated food on tables | procedural plate + real food mesh | ✅ |

---

## E. FEATURES — graphic status & what to buy

| Feature | Now | Status |
|---|---|---|
| **Dirt / mess** | procedural brown splat (the "DIRT! CLEAN ME" text was REMOVED 2026-07-19) | ❌ **BUY** a real mess model |
| Café building (facade, walls, door, awning, sign) | procedural greybox + wood-floor texture | 🟡 (themed, works) — optional building kit |
| Tip drop | procedural gold coin cylinder | 🟡 — optional coin mesh |
| Order pickup marker | neon pad + text | 🟡 (a marker, fine as-is) |
| Kitchen pass / divider | procedural counter | 🟡 (fine as-is) |
| Buzz sign / trophy shelf | procedural | 🟡 (fine as-is) |
| Mood faces / order bubbles | emoji text | ✅ (text is the right call) |

---

## 🛒 TO BUY — shopping list (paste links back to me, I integrate)

Same rule as before: **low-poly / cartoon**, from the Creator Store, prefer a
HumanoidRootPart on any rig. Search in English.

| # | For | Search terms (EN) |
|---|---|---|
| G1 | **Dirt / mess** (owner priority) | `dirt pile low poly` · `trash mess floor` · `spill puddle low poly` · `garbage low poly` |
| G2 | Prep Station | `kitchen prep table low poly` · `stainless prep station` |
| G3 | Round Table | `cafe round table low poly` · `bistro table` |
| G4 | Potted Plant | `potted plant low poly` · `indoor plant pack` |
| G5 | Floor Lamp | `floor lamp low poly` · `standing lamp` |
| G6 | Round Rug | `round rug low poly` · `carpet decal round` |
| G7 | Barista rig (Mia) | `barista character rigged` · `waitress npc r15 rigged` |
| G8 | Maid/Cleaner rig (Pia) | `maid npc rigged` · `janitor character r15` |
| G9 (opt) | Accurate croissant | `croissant low poly` |
| G10 (opt) | Accurate sandwich/club | `club sandwich low poly` · `sandwich on plate` |
| G11 (opt) | Cinnamon roll | `cinnamon roll low poly` |
| G12 (opt) | Quiche / pie | `quiche low poly` · `savory pie low poly` |
| G13 (opt) | Coin/tip mesh | `coin low poly` · `gold coin 3d` |
| G14 (opt) | Café building kit | `cafe building kit low poly` · `shop facade modular` |

**Summary:** menus ✅ (14/14, 5 approximate) · shop 15/20 real, **5 to buy** ·
world + UI ✅ · the one feature that genuinely needs art is **dirt (G1)**, which
is also the one you flagged — its floating text is now deleted.
