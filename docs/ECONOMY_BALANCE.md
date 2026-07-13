# Economy balance

Single soft currency for the MVP: **coins**. **Reputation** is a progression gate,
not spendable. Event tickets come post-MVP. Keep it simple — avoid many currencies.

Source of truth: `src/shared/Config/Economy.luau` and `Recipes.luau`. Never hardcode
these numbers in logic.

## Starting state
- Coins: **150** · Reputation: 0 · Level 1 · 0 stars.
- Inventory: 2 round tables, 4 wooden chairs, 1 potted plant.
- Pre-placed: coffee machine + service counter.

## Recipes (margin = basePrice − ingredientCost)
| Recipe | Ingredient | Price | Margin | Lvl | Rep |
| --- | ---: | ---: | ---: | ---: | ---: |
| Espresso | 4 | 12 | **8** | 1 | 0 |
| House Tea | 3 | 10 | **7** | 1 | 0 |
| Cappuccino | 7 | 20 | **13** | 2 | 30 |
| Café Sandwich | 11 | 28 | **17** | 2 | 40 |
| Croissant | 8 | 22 | **14** | 3 | 80 |

Every serve is profitable. Manual cook adds `+floor(basePrice × 0.15)`. Tip: 25%
chance of `floor(basePrice × 0.20 × customerTipMultiplier)` (regular 1.0, student
0.7, tourist 1.5). Each serve also grants +2 reputation, +10 xp.

## Progression
- **XP per level:** 0, 60, 150, 300, 520, 820, 1220, 1750, 2400, 3200 (≈10 serves → L2).
- **Reputation per star:** 50, 200, 600, 1500, 4000. Stars are derived from
  reputation today; expand to a blend (value, mastery, satisfaction, staff, social)
  before soft launch. **Stars are never purchasable.**

## Shop prices (coins)
Chair 15 · Rug 20 · Plant 25 · Lamp 35 (Lvl 2) · Table 40 · Counter 80 · Coffee machine 120.

## Tuning intent & open questions
- First decoration affordable within the first few serves (plant 25 vs starting 150).
- Watch the coins/hour curve once staff automation lands (Week 3) — automation must
  not trivialise the early economy.
- Sink/faucet balance to revisit with real analytics; treat all targets as hypotheses
  and compare against Creator Dashboard genre benchmarks, not generic numbers.
