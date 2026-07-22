# What the game actually is right now — and where to take it

_Written 2026-07-22, from reading the services rather than the design docs. The
owner asked two questions: "explain the current gameplay where the players need
to have actions and play", and "where do players get ingredients to cook". The
second answer is the interesting one._

---

## 1. There are no ingredients

**The word is painted over a coin cost.** `recipe.ingredientCost` is used in
exactly one place that matters:

```lua
-- KitchenService, AddEmergencyServing
if not hasAppliance or not EconomyService:TrySpendCoins(player, recipe.ingredientCost) then
```

There is no ingredient item, no pantry stock of beans or flour, nothing to buy,
hold, or run out of. The only other appearances of the word are the error string
*"Not enough coins for ingredients"* and a profit calculation in
`OperationsMath`. `Types.PlayerData` has no ingredient field.

So a player reading the UI is told the game has a system it does not have. Fix
it by building the system or by dropping the word — but not by leaving both.

## 2. What a player physically does

Nine things can be walked up to and interacted with:

| Where | Action | Implemented in |
| --- | --- | --- |
| An appliance | **Cook** / **Collect** | `KitchenController`, `KitchenService` |
| Coffee machine | **Brew** — the timing minigame | `CookingController`, `RecipeService` |
| Kitchen pass | **Pick up** a plate for a waiting customer | `OrderService` |
| A table | **Deliver** that plate | `OrderService` |
| A table, after they leave | **Take tip** | `CustomerService` |
| Floor / mess | **Clean up**, **Scrub clean** | `CafeOperationsService` |
| A neighbour's plot | **Visit Café** | `InteractionController` |

Plus the menu work: buy furniture, place it on the grid, choose which four
recipes are on the menu, set target stock per dish, set production priority.

**The shape of a session.** Appliances produce dishes automatically toward the
stock targets you set. Customers arrive at a rate driven by Buzz — `1.2/min` at
Buzz 10 rising to `2.8/min` at Buzz 105 (`Config/Kitchen`). They sit, order, and
a ticket appears. You jog to the pass, take the plate, jog to their table, hand
it over, collect coins and XP. Later you pick up their tip. Meanwhile dirt
spawns every ~55s and drags cleanliness down, which shortens customer patience
and eventually makes them refuse to come in at all.

Underneath: XP to **level 10** (3200 XP), reputation to **5 café stars** (4000
rep), 14 recipes unlocking by level, 3-star mastery per recipe, 3 daily goals
from a pool of 5, streak trophies at 3/7/14/30 days.

## 3. The problem: the game automates away its own gameplay

The moment you have staff, the physical loop disappears. Noah the waiter serves,
so you stop fetching plates. Pia cleans, so you stop scrubbing. Mia and Sam run
production, so you stop cooking. **Every hour of progress removes a reason to
touch the game.** The most engaged a player will ever be is their first twenty
minutes.

There is already a counterweight that players cannot feel: staff have a **shift
capacity** that drains as they work and only refills while the owner is in-game
(`Config/Operations`), and a hand-delivered serve restores capacity and gives
nearly double the satisfaction of a staff serve (`1.4` vs `0.8`). The design
already says *being present is better*. It is communicated as four small
percentage bars.

Second problem: **the interesting decisions are buried in menus.** Which four
dishes are on the menu, what stock level to hold, what to prioritise — that is
the actual strategy game, and it happens in a drawer. The 3D world, where the
player is looking, offers fetch-and-carry.

This is also why the tutorial dead-ended (see `CHANGELOG`, 2026-07-22): step 2
asked the player to cook, and automatic production holds a job on the only
appliance, so a manual `StartCook` answers `stove_busy`.

## 4. Ranked ideas, inside the ethics rails

The rails from `HANDOFF.md` are not negotiable: spoilage stays transparent and
pauses offline, **no missed-day punishment**, no loot boxes, no pay-to-win, no
fake urgency, whitelisted communication only. They are an asset — they are why
this can be a game parents do not mind.

| # | Mechanic | What the player does | Size |
| --- | --- | --- | --- |
| 1 | **Ingredients as a delivery** | A supply van pulls up; you walk out, unload crates, pantry shelves visibly fill. Cooking drains them; running dry stops production. | M |
| 2 | **Rush hours** | Twice a session Buzz spikes for ~90s and staff capacity cannot cover it, so you work the floor by hand. An *opportunity*, never a penalty. | S |
| 3 | **Regulars** | A named customer returns daily, has a favourite dish, and warms to you the more you serve them personally. Milestones give better tips or passive draw. | M |
| 4 | **Menu decisions in the world** | The menu board becomes a physical object you walk to; the counter visibly empties as stock sells. | M |
| 5 | **Serve streaks** | Consecutive fast, correct deliveries build a visible multiplier that resets on a walk-out. | S |
| 6 | **Café inspections** | The 5 star tiers already compute from reputation but nothing happens. A critic visits, judges cleanliness/variety/speed, awards the star, unlocks a new zone (terrace, upstairs). | M |
| 7 | **Street events** | A plaza festival where all 10 cafés on the server contribute to a shared goal. Makes the neighbours matter. | L |

**Suggested order:** 1 and 2 first — together they fix the two things the owner
actually felt (a system that does not exist, and a game that plays itself). Then
3, which is the emotional hook that brings someone back on day three.

**Do not build yet:**

- **Staff wages.** `baseSalary` sits unused in `Config/Staff`. Charging for staff
  before staff are fun only adds friction.
- **More levels.** Past level 10 on an empty loop is just a longer empty loop.
  Give level 10 something to do first.
