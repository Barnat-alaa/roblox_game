# Economy analysis — Social Café City

_2026-08-03. Simulation of the live server loop against `src/shared/Config`._

Method: the loop was re-derived from the code that actually runs
(`ProductionService.startPlanJob`, `KitchenService.GetDemandRate`,
`CustomerService`), then simulated hour-by-hour with a player who always makes
the economically best choice. Every number below is reproducible from config.

---

## 0. The one-paragraph answer

The economy is **too easy in the sense that it ends** — a player hits every
ceiling in the game (level 10, both staff maxed, 5 stars) in **about 18–20 hours
of active play**, after which coins pile up with nothing to buy. It is
**too hard in the sense that it never feels good** — demand is structurally
3–5× what the café can produce, so customers storm out angrily **every minute
from the first minute to the last**, and Buzz can never physically rise above
about **31 out of 105**. Meanwhile roughly **half of all lifetime income is
session gift boxes**, not the café. And the production menu the player plans
against **overstates output by 12–32×**, so their expectations are wrong before
they start.

---

## 1. How the loop actually works (and where the docs disagree)

`Kitchen.useProductionPlan = true`, so the live path is `startPlanJob`:

| | Live path (`startPlanJob`) | Legacy path (`startJob`, dead) | Menu forecast (`OperationsMath`) |
|---|---|---|---|
| Output per job | **1 serving** | `productionYield` (3–8) | `productionYield` |
| Duration | `productionMinutes` × 60s | `productionTime` | `productionTime` |
| Coin charge | **none** | `ingredientCost × 3` | — |
| Shift capacity | **never spent** | spent | ignored |
| Limit | role's work-minutes/hour | appliance count | appliance count |

**The menu models the dead path.** That is the root of the "stats look wrong"
feeling.

The real throughput rule is simple:

```
work-minutes per hour = 15 + (staffLevel - 1) × 5      -- 15 at L1, 60 at L10
servings per hour     = work-minutes / recipe.productionMinutes
```

Producers are Barista and Cook. **That formula is the entire supply side of the
game.**

---

## 2. Defects — things that are wrong, not merely unbalanced

### 2.1 The production menu overstates output by 12–32×

`OperationsMath.calculate` computes `machines × productionYield × 60 /
productionTime`. Nothing in the live path uses those fields.

| Recipe | Menu says | Real at L1 | Real at L10 | Overstated |
|---|---|---|---|---|
| Espresso | 180/h | 15.0/h | 60/h | **12×** |
| Cappuccino | 160/h | 10.0/h | 40/h | **16×** |
| Croissant | 150/h | 7.5/h | 30/h | **20×** |
| Muffin | 144/h | 6.0/h | 24/h | **24×** |
| Club Sandwich | 120/h | 5.0/h | 20/h | **24×** |
| Quiche | 120/h | 3.8/h | 15/h | **32×** |

It is also worse than the table shows: the menu figure is **per recipe**, while
in reality all of a role's recipes share **one** hourly budget.

### 2.2 The same menu understates ingredient cost by up to 62%

`ingredientPerServing = ingredientCost × batchCostMultiplier / productionYield`
— it multiplies by 3 *and* divides by yield, but `ingredientCost` is already
per-serving.

| Recipe | Menu shows | Real | Understated |
|---|---|---|---|
| Espresso | 3.00 | 3 | 0% (coincidence: yield 3 = multiplier 3) |
| Cappuccino | 3.75 | 5 | 25% |
| Croissant | 4.20 | 7 | 40% |
| Muffin | 3.50 | 7 | 50% |
| Club Sandwich | 6.00 | 12 | 50% |
| Quiche | 3.75 | 10 | **62%** |

Overstated output plus understated cost means the forecast profit is wrong by
roughly an **order of magnitude**, always in the optimistic direction.

### 2.3 Shift capacity is dead code for producers

`Operations.staffCapacityMax`, `productionCapacityPerWorkMinute` and
`onlineRecoveryPerMinute` are only consumed by the legacy path and by serving.
`startPlanJob` never calls `TryUseCapacity`. Any "shift" meter shown for a
Barista or Cook is not connected to anything.

### 2.4 Satisfaction gates nothing

`satisfaction` is written by a dozen call sites and read by none for any
decision. It cannot reject a customer, slow a spawn, or change a payout. It is a
number that moves and means nothing.

### 2.5 Buzz has a hard structural ceiling around 31/105

Buzz is `+1` per served customer and `−2` per walkout, so it stops rising when
`served = 2 × walkouts`, i.e. when the café serves **two-thirds of arrivals**.

| Production | Settles at Buzz | Arrivals/h | Angry walkouts/h |
|---|---|---|---|
| 15/h (start) | **0.0** | 77 | 62 |
| 30/h | **0.0** | 77 | 47 |
| 45/h | **0.0** | 77 | 32 |
| 70/h (**max build**) | **30.8** | 105 | 35 |
| 100/h (unreachable) | 80.1 | 150 | 50 |
| 140/h (unreachable) | 105.0 | 168 | 28 |

Maximum achievable production is Barista L10 + Cook L10 = 120 work-minutes/hour
≈ **70 servings/hour**. So a perfect café tops out at **Buzz 31**, and the bar,
the sign and the plaza leaderboard are all permanently below a third full. The
top ~70% of the Buzz range is unreachable by design accident.

### 2.6 The café is in visible failure from minute one

Because spawning ignores stock, a new player with 15 servings/hour faces 77
arrivals/hour: **62 angry storm-outs per hour, forever**. The player's first
experience is a room of furious customers, and no amount of correct play fixes
it — a maxed café still loses 35/hour.

---

## 3. Progression: the curve is short and flat

Simulated with optimal spending (session gifts included, which the game gives
automatically):

| Milestone | Reached at |
|---|---|
| Hire the Cook (600c) | hour 4 |
| Level 5 | hour 7 |
| Barista level 10 | hour 17 |
| **Level 10 (max)** | **hour 18** |
| Cook level 10 | hour 19 |
| 5 stars | hour 37 |
| Coins at hour 120 | **73,922 and climbing, nothing to buy** |

Total coin sinks in the entire game: appliances ~500, seating ~330, hiring
1,000, staff upgrades 9,000. **About 11,000 coins.** The player is producing
~700/hour by then.

### 3.1 Income barely grows

Whole-game income arc: **90 → 390 coins/hour, a 4× spread**, entirely from staff
levels. A tycoon player expects orders of magnitude.

### 3.2 Levelling up is usually a downgrade

Every job costs work-minutes, so the only figure that matters is **coins per
work-minute**:

| Recipe | Level | Coins / work-min |
|---|---|---|
| Tea | 1 | 2.00 |
| Muffin | 4 | 2.40 |
| Croissant | 3 | 2.50 |
| Silky Latte | 4 | 2.50 |
| Garden Iced Tea | 5 | 2.67 |
| Cinnamon Swirl | 6 | 2.67 |
| **Espresso** | **1** | **3.00** |
| Café Sandwich | 2 | 3.00 |
| Terrace Club | 7 | 3.00 |
| Cappuccino | 2 | 3.33 |
| Velvet Mocha | 6 | 3.50 |
| Morning Quiche | 9 | 3.50 |
| Sunrise Fruit Bowl | 5 | **4.67** |

The spread is **2.3×** across nine levels, and **the level-1 Espresso beats six
of the eight recipes unlocked after it**. Unlocking Croissant, Latte, Muffin,
Iced Tea, Cinnamon Swirl or Terrace Club is an economic *downgrade* — the
correct play is to ignore them. The level-9 Quiche is worth 17% more per minute
than the level-1 Espresso.

This is why levelling "feels odd": it is odd. The reward for nine levels of
progress is a 17% rate improvement and one genuinely good recipe (Fruit Bowl, at
level 5, which then stays optimal for the rest of the game).

### 3.3 Two purchases do nothing

- **Extra appliances.** A machine can do 60 work-minutes per hour and the role
  budget maxes at 60. One machine per role saturates it; the second is inert.
- **Seats.** `+0.04/min` per seat above 4 — twenty seats add 0.64/min to a
  demand that is *already* triple what you can serve, and it is capped by the
  waiter cap anyway. Seats only prevent "no empty chair" walkouts.

---

## 4. Session gifts are half the economy

`SessionRewards`: a gift every 15 minutes, expected value **84.5 coins**, i.e.
**338 coins/hour** for doing nothing.

| | Café income | Session gifts |
|---|---|---|
| Hour 1 | 0 | 338 |
| Hour 10 | 236 | 338 |
| Hour 60 (maxed) | 389 | 338 |
| **60-hour total** | **19,964** | **20,280 (50%)** |

For the first ten hours the café is a rounding error next to the gift timer. A
player who idles on the plaza earns nearly as much as one who runs a café well.

---

## 5. Monetisation

### 5.1 Every SKU is worth about the same, which removes the reason to buy up

| SKU | Robux | Coin-equivalent value | Coins per R$ |
|---|---|---|---|
| Stock Pack +5 | 29 | 160 | 5.5 |
| Stock Pack +10 | 59 | 320 | 5.4 |
| Stock Pack +20 | 99 | 640 | 6.5 |
| Double Coins 1h | 59 | ~389 | 6.6 |
| Hire Full Crew | 149 | 1,000 | 6.7 |

Everything lands in a **5.4–6.7 coins per Robux** band. Bulk tiers exist but
give no bulk advantage, so there is no reason to pick the 99 R$ pack over three
29 R$ ones. Standard practice is for the top tier to be **30–50% better per
Robux** — that is what makes players trade up.

### 5.2 The coin prices on the packs are 5× their own value

Stock Pack +20 costs **3,000 coins** but contains **640 coins** of ingredients at
market prices. The coin path is a bad deal by a factor of five, which is the
correct *direction* (it should favour Robux) but the magnitude is so extreme
that a player who does the arithmetic feels cheated rather than tempted.

### 5.3 The packs solve a problem the player does not have

Production is capped by **work-minutes**, not by ingredients. A player is never
stopped by an empty pantry unless they forgot to shop; they are stopped by the
Barista's 15-minute shift. So the flagship consumable sells relief from a
bottleneck that is not the bottleneck.

### 5.4 What players would actually pay for

Ranked by how much real friction they remove, all of which stay inside the
rails (each must also be earnable with coins or levels):

1. **Extra work-minutes per hour** — a second Barista/Cook *slot*, or a "double
   shift" consumable. This is the actual bottleneck. Sell time, not power: the
   same ceiling is reachable by levelling, Robux just gets there sooner.
2. **A bigger café** — expansion tiers already exist in `World` but have no
   purchase flow at all. That is the single biggest missing coin sink *and* the
   most natural premium upsell.
3. **Cosmetics** — you already have 46,656 façade combinations, 8×5 floor/wall
   styles and door/window sets built. Almost none of it is monetised. This is
   free money that cannot possibly be pay-to-win.
4. **Offline hours** — VIP's 12h is the right shape.

---

## 6. Where to put the purchase prompts

The rails forbid fake urgency, so the rule is: **offer at the moment the player
feels the friction, and only then.**

| Moment | What the player feels | Offer |
|---|---|---|
| An appliance goes "shift empty — owner needed" | "My café stopped" | Double shift / extra staff slot |
| Pantry hits zero mid-plan | "I'm out" | Stock pack (this is its honest home) |
| Placing furniture with no room left | "I need space" | Expansion tier |
| Buzz bar stuck for N minutes | "I'm not growing" | Coin boost, honestly labelled |
| Returning after >2h away | "What did I miss?" | VIP offline hours, framed as what they *did* earn |
| Café-naming / façade screens | "I want it to look good" | Cosmetic packs |

**Do not** put a Robux button on the main HUD rail. The current placement inside
UPGRADES is right — it is where a player already goes to spend. What is missing
is the *contextual* offer at the six moments above.

---

## 7. Events worth adding

Existing: VIP every 30 min, daily goals, session gifts, neighbour mischief.

1. **Rush hour** (every ~20 min, 5 minutes long): demand ×2 and payouts ×2.
   Turns the always-losing walkout dynamic into a deliberate, bounded challenge —
   and it is the natural home for a coin-boost offer.
2. **Ingredient market swings**: a daily cheap ingredient and a daily expensive
   one. Gives the Market a reason to be visited and makes recipe choice matter.
3. **Weekly café rating**: a scored window that pays out on satisfaction — which
   would finally give satisfaction a purpose (§2.4).
4. **Neighbour co-op goal**: the street collectively serves N customers for a
   shared reward. You already have the social layer built.
5. **Recipe of the day**: one recipe pays ×1.5 — a cheap, honest way to make the
   flat recipe ladder (§3.2) temporarily interesting while it gets fixed.

---

## 8. Recommended fixes, in order

**Correctness first — these are bugs:**

1. Rewrite `OperationsMath` against the plan model, or delete the forecast. It is
   currently misinformation. (§2.1, §2.2)
2. Decide whether shift capacity is a mechanic. Either wire it into
   `startPlanJob` or remove it from the config and the UI. (§2.3)
3. Give satisfaction a consequence or remove it. (§2.4)

**Then the loop:**

4. **Gate spawning on stock**, or scale demand to production. Nothing else fixes
   the permanent-walkout problem, and it is the difference between a café that
   feels busy and one that feels broken. (§2.6)
5. **Rebalance Buzz** so a good café can reach 100 — e.g. `buzzPerWalkout = -1`
   with the demand fix, so `served = walkouts` is achievable. (§2.5)
6. **Re-tier recipes on coins-per-work-minute**, so each unlock is a genuine
   step up. Target roughly 3.0 at level 1 rising to ~9–10 at level 9. (§3.2)
7. **Add coin sinks past hour 20**: expansion tiers, café upgrades, cosmetics.
   Right now the game ends. (§3)
8. **Cut session gifts to ~30% of café income** rather than 100%, so playing
   beats idling. (§4)

**Then monetisation:**

9. Make the top Stock Pack ~40% better per Robux than the smallest. (§5.1)
10. Bring pack coin prices down from 5× to ~2–2.5× market value. (§5.2)
11. Sell work-minutes and expansion, not ingredients. (§5.3, §5.4)
12. Add the six contextual offer moments. (§6)

---

_Simulator: `scratchpad/sim.py`. Re-run after any config change to regenerate
these tables._
