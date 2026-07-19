# Café World feature parity map

_Created 2026-07-15 at the owner's request: the complete feature list of the
original Facebook game ("social café" = **Café World** by Zynga, 2009–2014,
shut down 2014-07-22 — the classic the owner remembers; our Buzz 0–105 rating
already mirrors its Buzz Rating). Every feature below is mapped to our game
so the roadmap is parity-driven._

_Sources: [Wikipedia](https://en.wikipedia.org/wiki/Caf%C3%A9_World),
[Café World Wiki (Fandom)](https://cafeworld.fandom.com/wiki/Cafe_World_Wiki)
incl. [Cooking Mastery](https://cafeworld.fandom.com/wiki/Cooking_Mastery),
[Neighbors](https://cafeworld.fandom.com/wiki/Neighbors),
[Spice All](https://cafeworld.fandom.com/wiki/Spice_All),
[Gamezebo walkthrough](https://www.gamezebo.com/walkthroughs/cafe-world-walkthrough/),
[GamesBeat making-of](https://venturebeat.com/games/the-making-of-zyngas-cafe-world-the-fastest-growing-social-game-in-history/),
[Adam Nash's economics analyses](https://adamnash.blog/2009/10/26/cafe-world-economics-profit-cafe-points/)._

**Legal reminder (docs/ART_DIRECTION.md):** we copy *mechanics and feelings*
(not copyrightable), never assets, names, art, or text. Recipe names, item
art and characters stay 100% ours.

Legend: ✅ have · 🟡 partial · ❌ missing · 🚫 rejected by design (ethics
rails / Roblox-native reasons) · **[S1..S5]** = step in the 2026-07-15
session roadmap (ROADMAP.md).

> **Progress — S1 shipped 2026-07-15:** the Creator Store asset pipeline is
> live (`AssetLibraryService` + `AssetManifest`): real espresso machine, oven,
> counter, chair, food/drink props, four clothed customer rigs, and barista/
> waiter/cleaner rigs — all script-stripped, grid-scaled, procedural fallback
> intact. This moves **D1** and **C4** forward (see rows).
>
> **Progress — S2 architecture + service theater shipped 2026-07-16:** cafés
> are real buildings (facade + auto-door + private garden + expansion tiers,
> see ROADMAP S2), and the original game's FULL service choreography now runs:
> defined staff roles (Barista Mia = drinks · Cook Sam = food · Waiter Noah =
> carries plates · Cleaner Pia = washes up), dish-icon bubbles on order and on
> "ready!", the waiter walks the plate to the table, the emptied plate stays
> until it's collected and washed. Rows B2–B4, C2–C3 updated below.
>
> **S2 third pass (2026-07-16): the owner WORKS the café** — take a customer's
> order with `E` (+2 Buzz personal service), clean tables with `E` (+1 Buzz),
> collect tips — staff remain the automation layer (full spec per NPC in
> `docs/NPC_BEHAVIOR.md`). Rig policy: only verified-walking rigs (Motor6D
> gate in AssetLibraryService); the broken waiter kit is permanently rejected.
> Walls raised to 14 studs (can't hop out even from countertops). Still open
> in S2: mood faces/patience meters, storm-outs, regulars.

## A. Cooking (the core)

| # | Café World feature | Ours | Notes / plan |
|---|---|---|---|
| A1 | Stoves cook dishes ahead of time (start now, collect later) | ✅ | KitchenService — our Phase 1 pivot |
| A2 | Pick recipe per stove from a cookbook | ✅ | Cook picker + Cookbook UI |
| A3 | Ingredient cost (coins) paid at cook start | ✅ | −12 batch etc. |
| A4 | Multi-click prep animation (chop → stir → cook) | ❌ **[S3]** | 2–3 tap prep gestures before the timer starts; makes "preparing" feel manual |
| A5 | Cook timers from minutes to 2 days; overnight dishes | ✅ | 30s → 8h Overnight Roast, wall-clock |
| A6 | Collect → counter holds N servings | ✅ | Counter stock, visible food stacks |
| A7 | Food **spoils** if overproduced | ✅ | Timestamped FIFO lots age only while online; the permanent HUD warns players and target-stock controls prevent waste |
| A8 | Spices: boost servings (+5/10%), skip time (1h/6h/instant), rescue spoiled | ❌ **[S3]** | Original "Pantry Boosters", earnable only (goals/gifts) — never sold for real money at this stage |
| A9 | Appliance families gate dish families (Coffee Machine → coffees, Drink Bar → drinks, Pastry Station, Pizza Oven, Deep Fryer, Ice Cream Cart, BBQ, Bread Oven, Toaster) | 🟡 **[S3]** | We have coffee machine / stone oven / prep station; add **Drink Bar** + **Pastry Display** first (store models — S1), each unlocking its recipe family |
| A10 | Upgraded stoves (Super/Lightning: one-click, −10–50% time) | ❌ | Later (Phase 6 economy) — upgrade tiers per appliance |
| A11 | Daily Cooking Bonus (first cook of the day) | ❌ **[S3]** | Cheap, strong D1 hook |
| A12 | **Dish mastery** (cook N× → 3 stars → +servings/+CP/−time) | ✅ | Ours: 4 tiers 5/15/40/100 → −time/−cost/+serving/fresh boost |
| A13 | Cookbook with mastery progress + locked teasers | ✅ | Phase 3a |
| A14 | Café Points (XP) per cook & serve → levels unlock recipes/stoves/counters | ✅ | 14-recipe ladder to Lv 9; extend to Lv 20+ later |

## B. Serving, customers & the Buzz

| # | Café World feature | Ours | Notes / plan |
|---|---|---|---|
| B1 | Counters between kitchen and floor hold the food | ✅ | |
| B2 | Customers enter, queue, take a seat at table+chair | ✅ | Phase 2 seated dining |
| B3 | Waiter carries plate from counter to table | ✅ | S2 theater: Noah walks (pathfinding) to the kitchen, picks up the REAL finished plate and sets it in front of the diner |
| B4 | Customers eat, pay, leave; dirty plates cleared | ✅ | Visible meal on the table; the EMPTY plate remains after eating until Pia collects it and carries it off to wash (+1 Buzz) |
| B5 | **Buzz Rating 5→105**, rises on service, falls on walkouts, drives traffic | ✅ | Buzz 0–105 on café sign drives spawn cadence |
| B6 | Impatient customers **walk out visibly angry** | ✅ | S2: storm-out with red "−N 🔥" floater + speed-up; line walkouts dent Buzz too |
| B7 | **Mood/feeling display** per customer (thought bubbles, reactions) | ✅ | S2: mood faces 😊😐😠 + draining patience bar over every waiting head; dish-icon want-bubbles; hearts on personal service & favourites |
| B8 | Named customers; recurring **regulars** | ✅ | S2: persisted regulars (max 8) return by name ("💚 Zoe is back!") and order their favourite; serving it pays +1 Buzz + hearts |
| B9 | Tips: visitors fill a **tip jar** you claim (2×/day cap) | 🟡 **[S5]** | NPC table tips exist; add a visitor tip jar (players who visit can tip once/day) |
| B10 | Satisfaction scales payout | 🟡 **[S2]** | Wire tips/coins to mood at serve time |
| B11 | VIP / celebrity customers, food critic events | ❌ | Phase 5 events (original characters only) |

## C. Staff

| # | Café World feature | Ours | Notes / plan |
|---|---|---|---|
| C1 | Hire **friends** as waiters/chefs (avatar cameo) | 🚫→🟡 | Roblox-native twist later (Phase 4+): friend cameo NPCs when you're neighbours; core staff stays NPC |
| C2 | NPC helper (sous-chef Remmy) | ✅ | S2 role split — every employee has ONE job: **Mia · Barista** prepares drinks at the coffee machine, **Sam · Cook** (chef rig) prepares food at the oven/prep station; both flash the dish icon when it's ready |
| C3 | Waiter + cleaner staff | ✅ | **Noah · Waiter** carries plates kitchen→table; **Pia · Cleaner** collects empty plates and washes them |
| C4 | Staff outfits per café theme | 🟡 **[S1→]** | Real barista/waiter/cleaner rigs adopted (Mia/Noah/Pia). Per-theme uniform variants stay Phase 6 cosmetics |
| C5 | Wages balancing automation | ❌ | Deliberate debt — when economy matures |
| C6 | Player performs the service personally (the original's click-to-run-your-café feel) | ✅ | S2: owner takes orders (`E`, +2 Buzz), cleans tables (`E`, +1 Buzz), collects tips, cooks/brews — staff are the automation net (docs/NPC_BEHAVIOR.md) |

## D. Customisation & decoration (decor-as-status)

| # | Café World feature | Ours | Notes / plan |
|---|---|---|---|
| D1 | Hundreds of decor items (tables, chairs, plants, art, lamps…) | 🟡 **[S1→]** | Asset pipeline live; real machine/oven/counter/chair + food props adopted. Breadth (plants/art/lamps, 25+ items) continues in the S4 Decorate tab |
| D2 | **Floors & wallpaper** you buy and apply | ❌ **[S4]** | Owner's #3 complaint — floor/wall styles per café, applied from a Decorate tab |
| D3 | Doors & windows swappable | ❌ **[S4]** | Style variants |
| D4 | Exterior decoration (façade, awning, outside seating) | 🟡 **[S4]** | Awnings exist; make colour/style pickable; outdoor bistro set |
| D5 | Café **expansions** (6×9 → 18×19; coins + neighbour count) | ❌ **[S4]** | Owner's #3 complaint — plot interior grows in tiers (e.g. 8×8 → 10×12 → 12×16), coins + level gated |
| D6 | Item inventory / store items you own | 🟡 | Build palette exists; add "stored items" so bought decor isn't lost when re-planning **[S4]** |
| D7 | Decor items as status (visible value) | 🟡 | Décor-points-on-sign planned (Phase 2 leftover) — fold into **[S4]** |
| D8 | Name your café | ❌ **[S5]** | Curated word-list names (moderation-safe), already in Phase 4 plan |
| D9 | Avatar (chef) customisation | 🚫 | Roblox players already are their avatar — our native advantage; staff uniforms cover the fantasy |
| D10 | Themes / collections (bistro, beach, retro) | ❌ | Phase 6 cosmetic packs |

## E. Economy & progression

| # | Café World feature | Ours | Notes / plan |
|---|---|---|---|
| E1 | Coins (earned) | ✅ | |
| E2 | Café Cash (premium currency) | 🚫 for now | Phase 6: cosmetics-only monetisation, no paid Buzz, no pay-to-skip |
| E3 | Levels gate recipes, stoves, counters, expansions | ✅/🟡 | Extend gates to appliances **[S3]** and expansions **[S4]** |
| E4 | More stoves/counters as strategy (3→15 stoves, 3→5 counters) | 🟡 | Caps exist via shop; revisit balance after expansions **[S4]** |
| E5 | Goal chains (multi-step quests: Super Stove, Spice It Up…) | 🟡 | Daily goals exist; add 2–3 step **story chains** gating new appliances **[S3]** |
| E6 | Medals / achievements | 🟡 | Streak trophy shelf exists; general medals Phase 5 |
| E7 | Daily bonus / Prize Machine gacha | 🚫 | No loot boxes ever; deterministic daily cooking bonus instead **[S3]** |
| E8 | Energy system | 🚫 | No fake scarcity — ethics rail |
| E9 | Limited-time-only items / FOMO | 🚫 | Seasonal *additive* collections instead (Phase 5), nothing punishes absence |

## F. Social (the "social" in social café)

| # | Café World feature | Ours | Notes / plan |
|---|---|---|---|
| F1 | Neighbours list (up to 100) | ✅ | 30-plot live boulevard — ours are real-time neighbours |
| F2 | Daily visit reward (20c + 5 CP per neighbour) | 🟡 **[S5]** | Visits + compliments (+2 rep) exist; add daily per-café visit coins |
| F3 | Help actions at a neighbour's café (spice/stir their dishes) | ❌ **[S5]** | "Stir the pot": +cook progress for them, coins for you, 1×/café/day |
| F4 | Sample the daily special at neighbours' | ❌ **[S5]** | Eat one dish at a neighbour's → small XP, once/day |
| F5 | Tip jar filled by visiting friends | ❌ **[S5]** | See B9 |
| F6 | Gifts (spices/ingredients/decor, daily, free) | ❌ **[S5]** | Daily ingredient crate (predefined, no trading) — Phase 4 plan |
| F7 | Borrow ingredients / part-requests to unlock builds | ❌ | Later — "neighbour signatures" to open expansions, Roblox-native |
| F8 | Eat Missions (eat at N neighbours) | ❌ **[S5]** | Becomes daily-goal variants |
| F9 | News-feed viral bonuses | 🚫 | Platform doesn't exist; server-wide drop moments instead (Phase 5 events) |
| F10 | Catering Business (team jobs with friends, star ratings) | ❌ | **Phase 5 flagship**: co-op catering orders — the best Café World idea for Roblox multiplayer |
| F11 | Leaderboards (top cafés) | ❌ **[S5]** | Street Buzz board on the plaza (Phase 4 plan) |
| F12 | Events (weekly/seasonal) | ❌ | Phase 5 Food Festival |

## Summary counts

- ✅ already ours: **17** (the whole cook-ahead core — the hard part is done)
- 🟡 partial: **15** — most gaps are *presentation* (moods, decor breadth) not systems
- ❌ missing: **17** — concentrated in customisation (S4), preparation rituals (S3), social economy (S5)
- 🚫 rejected on purpose: **8** (spoilage, gacha, energy, FOMO, premium cash-for-power, friend-staff-as-was, avatar wardrobe, feed spam) — each replaced by an ethical or Roblox-native equivalent

**The through-line:** Café World's magic = prepare ahead → full counters →
busy room → decorate to show off → check on neighbours daily. We have the
first three *mechanically*; this session's roadmap buys the look (S1), the
feelings (S2), the rituals (S3), the self-expression (S4), and the
neighbourhood economy (S5).
