# Gameplay upgrades — the road to addictive & interactive

_Created 2026-07-17 at the owner's request: a single backlog of the systems
that turn our working café sim into a game people can't put down. Every idea is
distilled from **Café World** (the original), **Roblox tycoons** (the platform's
#2 genre — automation + prestige loops), and **restaurant sims** (Restaurant
Tycoon 2/3, Idle Restaurant Tycoon: skill trees, offline income, recipe
collections). Each entry says WHAT, WHY it hooks, HOW (concrete tasks against
our real services), EFFORT, and PRIORITY._

**Read with:** [ROADMAP.md](../ROADMAP.md) (S3–S5), [CAFE_WORLD_PARITY.md](CAFE_WORLD_PARITY.md),
[MENU_SPEC.md](MENU_SPEC.md), [NPC_BEHAVIOR.md](NPC_BEHAVIOR.md).
Sources: [Endsights — Roblox tycoon loops](https://endsights.com/roblox-tycoon-games),
[BLOXG — retention](https://bloxg.com/guides/roblox-player-retention),
[Restaurant Tycoon 3 breakdown](https://earnaldo.com/blog/restaurant-tycoon-3-vs-restaurant-tycoon-2).

## The addiction formula (what we're actually building)

Great tycoon/sim retention = **five loops nested inside each other**, each with
a shorter or longer heartbeat. We already have the innermost two; the rest is
this backlog.

1. **Second-to-second** — juice: every tap pays sound + motion + a number. ✅ partly
2. **Minute-to-minute** — the service loop: cook → serve → clean → earn. ✅ done
3. **Session-to-session** — a goal always ~5 min from completing (unlocks, upgrades). 🔜 S3
4. **Day-to-day** — a reason to come back tomorrow (offline income, dailies, streaks). 🔜
5. **Week-to-week & social** — status, seasons, neighbours, events. 🔜 S5

**Our non-negotiable rails (keep these — they're our identity, §35):** no
spoilage/punishment, no loot boxes, no pay-to-win, no fake-urgency FOMO, no
free-text chat. Every tycoon pattern below is adapted to fit them.

---

## TIER 1 — Juice & feedback (cheap, massive feel, do FIRST)

The single highest return-on-effort work. Makes the game we already have *feel*
three times better before adding a single system.

| # | Feature | Why it hooks | How (tasks) | Effort |
|---|---|---|---|---|
| 1.1 | **Coin/number pop everywhere** | dopamine per action | We have Fx.floatText/coinBurst — extend to EVERY grant: serve, collect, tip, goal, combo. Add a "+X" that flies to the coin counter and makes it bounce | S |
| 1.2 | **Screen-shake + sfx on big moments** | weight | tiny camera nudge + a stinger on level-up, combo milestone, expansion, mastery star. New AudioController hooks | S |
| 1.3 | **Satisfying serve chain** | flow state | when the counter empties in a rush, chain the coin bursts + a rising pitch "ka-ching" ladder | S |
| 1.4 | **Buzz meter juice** | visible status | animate the café-sign Buzz number counting up, glow pulse when it hits a new tier (Quiet→Busy→Buzzing→Famous) | S |
| 1.5 | **Idle café ambience** | it feels alive | steam loops on stoves, chatter murmur when busy, door chime already exists — layer light SFX | S |
| 1.6 | **Toast celebrations** | reward clarity | full-width banner for milestones ("⭐ Croissant mastered!", "🏠 Café expanded!") | S |

---

## TIER 2 — Progression depth (the "one more" engine)

This is what tycoons live on. A player must ALWAYS see the next thing unlocking.

### 2.1 — Café Level & unlock ladder ✅ have, extend 🔜
- We have XP/levels to Lv 9. **Extend to Lv 30+** with a visible "next unlock"
  card on the HUD ("Lv 6 → unlocks the Drink Bar"). Tasks: widen
  `Config/Progression`, add a HUD "next unlock" pill, level-up reveal.
- **Priority: HIGH** (pairs with S3 menu).

### 2.2 — Upgrade tree per appliance/station 🔜 (Restaurant-Tycoon staple)
- **WHAT:** each appliance can be upgraded (Coffee Machine I→II→III): faster
  cook, more servings, better quality, auto-collect. A visible tree.
- **WHY:** the classic tycoon "build-pathing puzzle" — spend coins to compound
  income; every upgrade is a small dopamine hit and a visible change.
- **HOW:** `Config/Upgrades` (per applianceId: tiers, cost, effect); persist
  `data.upgrades[instanceId]`; KitchenService applies the multiplier at
  cook/collect; a swappable appliance mesh or a glowing tier badge; upgrade
  UI on the appliance prompt.
- **Effort: M · Priority: HIGH** (this is the core tycoon compulsion loop).

### 2.3 — Offline / "while you were away" earnings 🔜 (idle-tycoon core)
- **WHAT:** on rejoin, a friendly summary: "While you were away, your café
  served 40 customers → +320 🪙" (capped, scaled by Buzz + staff).
- **WHY:** the #1 day-to-day retention driver in idle tycoons; the reason to
  open the game tomorrow. Fits our rails: it's a *bonus*, never a punishment.
- **HOW:** persist `data.lastSeen`; on load compute elapsed × rate (cap ~8h);
  DataService already saves timestamps-friendly; present a claim popup with a
  big coin burst. Tune so active play still out-earns idle (~30–50%).
- **Effort: M · Priority: HIGH.**

### 2.4 — Recipe collection & mastery wall 🔜 (we have mastery, make it a COLLECTION)
- **WHAT:** the Cookbook becomes a collection board: locked silhouettes, a
  completion % ("18/48 recipes · 6 mastered"), gold frames for 3-star dishes,
  a reward for completing a category ("Complete the Pastry menu → Pastry
  Trophy + unique décor").
- **WHY:** collection psychology — the drive to fill the grid. Café World's
  mastery + our stars already exist; this makes them a *destination*.
- **HOW:** extend CookbookController UI; `Config/Collections` (category →
  reward); GoalService-style completion hooks. Ties into S3.
- **Effort: M · Priority: HIGH.**

### 2.5 — "New Season" prestige (ethical rebirth) 🔜 (tycoon prestige, our way)
- **WHAT:** once you hit café Lv max, opt into a **New Menu Season**: your
  décor and level reset to a fresh café BUT you keep a permanent **Prestige
  Star** that gives +% coins/Buzz forever, unlocks a season-exclusive recipe
  set and a badge on your sign. Nothing is lost that matters (trophies,
  recipes mastered, and cosmetics are kept — §35: the shelf never empties).
- **WHY:** the infinite-progression loop that makes tycoons long-tail; "come
  back stronger." Seasonal resets provably re-pull lapsed players.
- **HOW:** `data.prestige` (stars, keptRecipes); a confirm flow; multipliers
  in EconomyService/KitchenService; a Prestige board. DESIGN CAREFULLY so it's
  a choice players *want*, never feel forced into.
- **Effort: L · Priority: MEDIUM** (huge, but only worth it once the level
  ladder is long enough to reach a cap — after 2.1).

---

## TIER 3 — Day-to-day retention (reasons to return)

### 3.1 — Daily rewards calendar 🔜 (universal Roblox retention)
- 7-day escalating login calendar (coins → décor → a rare recipe on day 7).
  Streak shown; missing a day doesn't wipe rewards, just pauses (§35).
- `data.daily.loginStreak` + a calendar UI on join. **Effort: S · HIGH.**

### 3.2 — Daily goals & goal chains ✅ have, deepen 🔜
- We have 3 daily goals. Add **multi-step story chains** ("The Grand Opening":
  serve 20 → master a dish → decorate → reward: new appliance) that gate real
  content, à la Café World's goal series. **Effort: M · HIGH** (part of S3).

### 3.3 — Appointment cooking (already half-built) 🔜
- Overnight roast exists. Lean in: a few **long premium dishes** (6h/12h/1-day)
  with a big fresh-collect payoff, and a **daily first-cook bonus**. The
  morning-return ritual. **Effort: S · HIGH** (S3 menu).

### 3.4 — Weekly challenge 🔜
- One rotating weekly target ("Serve 500 dishes this week → exclusive café
  banner"). Server-persisted per player. **Effort: S · MEDIUM.**

---

## TIER 4 — Interactivity & minigames (active play that PAYS)

The owner asked for "interactive." Reward skill and presence so active players
feel the game responds to them (our combo system is the seed of this).

| # | Feature | Why | How | Effort |
|---|---|---|---|---|
| 4.1 | **Cook minigames per station** | skill = reward | brew-timing bar exists; add a chop/stir/flip mini-gesture per appliance family; nail it → quality bonus + juice | M |
| 4.2 | **Service combo, expanded** ✅ seed | flow-state chase | we have the combo; add an on-screen combo meter + escalating SFX/visuals, and a "perfect rush" bonus for clearing a full queue | S |
| 4.3 | **Rush-hour events** | tension + payoff | timed in-café surge ("☕ Morning Rush! 2× customers for 60s") with a leaderboard-worthy payout; telegraphed, never punishing | M |
| 4.4 | **Tip-jar & table taps** ✅ partly | tactile income | tips are tappable; add tappable "clean me" plates (done) and a satisfying wipe animation | S |
| 4.5 | **Photo mode / café selfie** | expression + sharing | a camera tool to frame your café → shareable image; drives social pull | M |

---

## TIER 5 — Social & competition (the "social" in Social Café)

Multi-plot servers are our superpower vs. the old Facebook game. (Most is S5 in
ROADMAP — collected here for the full picture.)

| # | Feature | Why | How |
|---|---|---|---|
| 5.1 | **Street Buzz leaderboard** | visible status race | plaza board ranks the server's cafés by Buzz; live |
| 5.2 | **Visit & help a neighbour** | reciprocity loop | one helpful tap/café/day (stir a pot: +progress for them, coins for you) — Café World's core social hook, whitelisted |
| 5.3 | **Daily gift crate** | gift economy | send a predefined ingredient crate to a neighbour (no trading, no dupe risk) |
| 5.4 | **Regulars → friendships** ✅ seed | attachment | our regulars persist; let a regular become a "VIP" after N visits with a special order + big tip |
| 5.5 | **Co-op catering orders** | team play | the best Café World idea for Roblox: a shared plaza order ("serve 500 together → street unlock") |
| 5.6 | **Café name + sign styles** | identity | curated word-list café names (moderation-safe) |

---

## TIER 6 — Collection & customization (status = long-term hook)

| # | Feature | Why | How |
|---|---|---|---|
| 6.1 | **Floors / walls / doors / windows** 🔜 S4 | self-expression | Decorate tab applies styles per café (generated textures + bought models) |
| 6.2 | **Buy land / expand** ✅ geometry done | visible growth | the tier geometry works — add the purchase UI + coin/level pricing |
| 6.3 | **Décor score on the sign** | decor-as-status | sum placed-item value → shown on sign → small tip bonus (visible, understandable) |
| 6.4 | **Café themes** (Parisian/Tropical/Retro) | collection + identity | cosmetic packs (Phase 6 monetisation, cosmetics-only) |
| 6.5 | **Staff outfits / customisation** ✅ aprons | identity | per-theme uniforms; name your staff |
| 6.6 | **Helper "café pet"** (ethical pet-collection) | Roblox collection meta | a cosmetic café cat/dog that wanders; later variants earned (never gacha) |

---

## Recommended build order (impact ÷ effort)

**Do next (right after S3 menu):**
1. **Tier 1 juice pass** (1.1–1.6) — a day of work, transforms feel.
2. **2.2 appliance upgrade tree** — the core tycoon compulsion loop.
3. **2.3 offline earnings + 3.1 daily calendar** — day-to-day return reasons.
4. **2.4 recipe collection wall** — folds into the S3 cookbook.

**Then:** 3.2 goal chains · 4.2/4.3 combo+rush · 2.1 longer level ladder →
**2.5 prestige** (once the ladder is long) · Tier 5 social · Tier 6 customization.

**The pattern to hit:** by the end of the next few sessions a player should,
in their first 10 minutes, (a) feel every tap pay off, (b) always see a next
unlock/upgrade ~5 min away, and (c) have a concrete reason to return tomorrow.

## How this maps to the existing 5-step roadmap

- **S3 (menu)** carries 2.1, 2.4, 3.2, 3.3 naturally — build juice (Tier 1) alongside it.
- **S4 (customise/land)** is Tier 6 (6.1–6.3).
- **S5 (social)** is Tier 5.
- **New, not yet in the roadmap:** the **appliance upgrade tree (2.2)**, **offline
  earnings (2.3)**, **daily calendar (3.1)**, **rush events (4.3)**, and the
  **New-Season prestige (2.5)** — these are the tycoon-genre additions that push
  it from "nice café sim" to "can't-put-it-down." Recommend inserting 2.2 + 2.3
  + 3.1 as a dedicated **"S3.5 — Tycoon hooks"** mini-step between S3 and S4.

## Guardrails (do not violate — this is our brand)

No spoilage. No loot boxes / gacha. No pay-to-win (cosmetics + honest speedups
only). No fake-urgency countdowns that punish absence — seasons and events are
generous and additive. No free-text between players. Every "prestige/reset"
keeps what players are emotionally attached to (recipes, trophies, cosmetics).
