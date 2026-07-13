# Game design

## Fantasy
Start with a tiny forgotten café and turn it into the heart of a living
neighbourhood. Every café tells the story of its owner. Three pillars, always
available: **Manage** (cook, serve, hire, upgrade), **Create** (place, decorate,
theme), **Socialise** (visit, order, compliment, help, co-op events).

Not a "click-to-earn" simulator. The retention feeling is: *"I want to return
because my café is mine, I can improve it, and other people can see it."*

## Core loop
1. Customer enters → seat/counter → orders.
2. Player cooks (manual for quality/tips, or staff auto later).
3. Serve → customer evaluates speed, quality, atmosphere, cleanliness.
4. Earn coins, tips, mastery, reputation.
5. Spend on furniture, equipment, recipes, staff, expansion.
6. Better café → new customer types.
7. Visit neighbours / contribute to a shared goal → return with new goals.

Pacing targets: understandable action in 20s, first reward in 1 min, visible
café improvement in 3 min, an aspirational/social moment by 10 min.

## First ten minutes (learn by doing, no wall of text)
- **0–1:** arrive at a neglected café; a friendly neighbour greets; one clear goal.
- **1–3:** enter; place a table + two chairs (teaches build by doing).
- **3–5:** start the coffee machine; first customer; receive an order.
- **5–7:** prepare + serve; positive reaction; coins + reputation.
- **7–9:** buy one decoration; the improvement is obvious.
- **9–10:** see the neighbourhood; shown an attractive café; new medium-term goal.

## Systems (MVP → month one)
- **Building:** grid placement, 4 rotations, one floor, ≤100 objects, preview
  with green/red validity, server-authoritative commit. (Free placement & floors are later.)
- **Cooking:** short interactive minigames; manual = faster/better/more mastery/tips.
- **Recipes:** data-driven definitions; mastery levels per recipe. MVP: espresso,
  cappuccino, tea, croissant, sandwich → ~20 in month one.
- **Customers:** readable lifecycle + satisfaction from waiting/quality/cleanliness/
  décor/price. Icons, not chatty dialogue. MVP: 2–3 variants sharing one behaviour.
- **NPC navigation:** grid-aligned furniture, marked walkable cells, fixed
  interaction points, mandatory entrance route, stuck-NPC recovery. Hybrid: logical
  grid for validity + Roblox movement for motion.
- **Staff (Week 3):** barista/waiter/cleaner; speed/skill/energy/salary; automate tasks.
- **Progression:** player level (unlocks) · café reputation (fame) · 0–5 star rating
  (combination of reputation, value, mastery, satisfaction, staff, social — never buyable).
- **Neighbourhood:** one street, ~6 plots (inactive = NPC façades), plaza, shop,
  photo area, shared progress board. Safe predefined reactions only — **no open text**.
- **Helpers (later):** original collectible mascots with small passive bonuses.
- **Economy:** coins (earned/spent), reputation (progression gate), event tickets (post-MVP).

## Monetisation (Week 6, only after the loop is fun)
Sell expression/collection/convenience — never power. No pay-to-win, no loot boxes,
no manipulative timers, no purchase prompts before the player understands the game.
`ProcessReceipt` must be idempotent.

## Art direction
Warm, stylised, handcrafted miniature city; a fictional Mediterranean pedestrian
street (warm façades, balconies, plants, stone, terraces, golden evening light) via
**broad, unprotected ideas** — never a real branded place or another game's map.
Rounded forms, clean silhouettes, mobile-readable shapes, cohesive muted palette
(cream, terracotta, olive, soft blue, warm brown, muted red, golden light). Avoid
generic-simulator presentation (giant floating signs, confetti, neon, number spam).

## Anti-goals
Generic tapper feel · dark patterns (fake urgency, deceptive countdowns, punishing
missed days) · copying any existing game's assets, map, UI, names, or identity.
