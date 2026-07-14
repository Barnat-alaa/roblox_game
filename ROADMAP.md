# Roadmap — to a top-hit café sim

_Rewritten 2026-07-14 after the MVP shipped. New working mode: Claude codes
and pushes; the owner playtests and reports by screenshot/feel._

**Where we are:** MVP complete and published privately (`Social Cafe DEV`,
place 85898641225605): full loop (build → brew → serve → earn → shop),
customer queues with 8 styles, barista automation, persistent tutorial,
café visits + compliments, 30-plot two-row city with closed-café shutters,
golden-hour art pass, licensed audio, real DataStore persistence, camera +
mobile controls, security-audited remotes, CI-green repo.

**North star:** the *feel* of the classic Facebook café sims, rebuilt as
original mechanics (never copied assets — see docs/ART_DIRECTION.md):
cook-ahead planning, counters full of food, a café that visibly hums, a
street of real neighbours, and decor as status. Ethical twist (§35): no
spoilage punishment, no fake urgency — *fresh bonuses* instead of rot.

---

## Phase 1 — THE LOOP PIVOT: cook-ahead kitchens (Week 2) ⭐ the big one

The classic magic wasn't serve-on-demand — it was **preparation**: start
dishes on stoves, come back to collect, keep counters stocked while a
stream of customers eats. This is the single biggest "feels like the
original" lever, and it's pure mechanics (not copyrightable).

- **Stoves cook in stages**: pick recipe → ingredients cost coins → timer
  (espresso 30s … feast recipes 10+ min) → COLLECT to a counter.
- **Counters hold servings** (e.g. espresso = 12 servings). Customers stream
  in, sit or queue, and consume from counter stock. No stock → grumpy exits
  and Buzz drops.
- **Buzz rating** (0–105): rises with fed customers, falls with walkouts.
  High Buzz = more/faster customers = more coins. THE score players chase.
- **Fresh bonus, never spoilage**: collecting within 2× cook time pays a
  bonus. Late food never rots (§35 — no punishment for sleeping).
- Brew minigame stays as the *quality* layer on collection (bonus coins).
- Existing OrderService/serve flow becomes the "counter service" path for
  drinks; plates flow through the new KitchenService.

Deliverables: `KitchenService`, stove/counter composite models with
**visible food** (pots steam while cooking, plates stack on counters),
`Config/Recipes` gains cookTime/servings/collectBonus, HUD stove timers,
Buzz meter on the HUD + above every café sign.

## Phase 2 — A café that looks ALIVE (Week 2–3, runs parallel)

- **Seated dining**: customers take chairs at tables, food plate appears in
  front of them, eat animation (bob + particles), tip left on table to tap.
- **NPC walk cycles**: leg-swing + bob animation on our chibi rigs; door
  chime + walk-in path through the actual front.
- **Juice everywhere**: coin burst on collect, steam on stoves, sparkle on
  mastery, star pop on Buzz-up, floating +XP text.
- **Interior décor value**: every placed item adds Décor points → shown on
  the sign; higher Décor = slightly higher tips (visible, understandable).
- **Aesthetic upgrade**: generated textures (gingham tabletops, wood grain,
  menu boards), awnings + terrace strip per café, string lights at dusk,
  window glow at night, curtains; second wall/floor palette per player
  (first customisation!).

## Phase 3 — Progression that grips (Week 3–4)

- **Recipe mastery stars** (cook N times → faster/cheaper/prettier + gold
  frame in the cookbook) — collection psychology, fully original art.
- **Cookbook UI**: page-flip book with dish cards, locked silhouettes tease
  the next unlock (the "one more level" pull).
- **20+ recipes** across coffee/tea/pastry/breakfast/lunch with real
  cook-time spread (30s → 8h overnight roast for the morning login).
- **Level-up moments**: full-screen tasteful celebration, +unlock reveal.
- **Daily goals** (3 rotating, e.g. "collect 4 dishes / greet 2 neighbours")
  + a 7-day streak shelf of trophies. No loss on a missed day — the shelf
  just waits (§35).
- **Staff v2**: hire waiter (auto-serves seated tables) and cleaner (clears
  plates, +Buzz); wages balance the automation; outfits per café theme.

## Phase 4 — The social city (Week 4–5)

- **Neighbour actions that matter**: visiting lets you do ONE helpful tap
  per café per day (stir a pot = +2 min cook progress for them, +coins for
  you) — the classic help-loop, rebuilt originally, fully whitelisted.
- **Street Buzz board**: plaza board ranks the lobby's cafés by Buzz — the
  status race that makes decor and uptime matter.
- **Gifting**: send a daily free ingredient crate to another player
  (predefined, no trading economy yet — no dupe risk).
- **Photo spot** + café sign customisation (name from a curated word list —
  moderation-safe, e.g. "Golden Bean Corner").
- **Weekly street goal**: lobby-wide "serve 500 dishes together" → street
  decoration unlock for everyone present.

## Phase 5 — Retention & LiveOps scaffolding (Week 5–6)

- **Appointment rhythm** (ethical): overnight recipes, morning fresh-bonus
  window, daily goals reset — reasons to return, never punishment.
- **Collections**: seasonal dish sets (complete the Autumn Menu → café
  trophy + unique furniture).
- **First event**: weekend Food Festival at the plaza (stalls, one special
  recipe, event currency → cosmetics only).
- **Analytics-driven tuning**: funnels (join→first collect→D1 return),
  Buzz distribution, drop-off steps; rebalance from data.

## Phase 6 — Monetisation + hardening (Week 6, only once the loop is fun)

- Cosmetics only at first: furniture collections, café themes (Parisian /
  Tropical / Retro Diner), staff uniforms, sign styles. Then one honest
  convenience pass (extra saved layout + double daily-goal slots). NO
  loot boxes, NO paid Buzz, NO pay-to-skip-timers at launch (§24/§35).
- ProfileStore session locking; migration tests; Open Cloud CI publishing
  (push-button staging/production); MicroProfiler pass at 30 players;
  low-end mobile test matrix.

## Phase 7 — Closed alpha → soft launch (Week 7–8)

- 10–20 testers; watch full sessions; fix top-3 drop-offs; economy
  rebalance; game-page assets (icon/thumbnail/trailer GIF); the NAME
  decision (distinctive, legally clear); production experience + staging;
  release checklist + rollback; limited public launch; daily triage.

---

## The 5 "top hit" levers we optimise for (in order)

1. **First 10 minutes** — from spawn to "my café is running and I get it".
2. **D1 return reason** — overnight recipe + fresh bonus + streak shelf.
3. **Visible status** — Buzz on every sign, street board, decor that shows.
4. **Session juice** — every tap pays sound + motion + number.
5. **Thumbnail truth** — the game page shows exactly the cosy street
   fantasy the first minute delivers.

## Explicitly deferred

Apartments · helpers-as-pets depth · multi-floor building · blueprint
sharing · delivery · second café branches · trading/free-market economy ·
UGC integration.
