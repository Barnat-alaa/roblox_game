# Analytics events

Instrumented from the MVP. Today `AnalyticsService` logs structured events to
Output; wiring into Roblox `AnalyticsService` (LogCustomEvent + funnel steps) is a
Day-6 task. `TrackOnce` backs the `first_*` events (once per player per session).

## Core events
```
session_started            tutorial_started           tutorial_step_completed
tutorial_completed         first_furniture_placed     first_recipe_started
first_recipe_completed     first_customer_served      first_coins_collected
first_item_purchased       first_save_completed       first_cafe_visit
daily_quest_completed      staff_hired                build_mode_opened
build_mode_item_placed     session_ended
```

Emitted now: `first_customer_served`, `customer_served` (via OrderService). The rest
are added as their systems come online — keep the names above stable so funnels
don't fragment.

## Primary funnel
```
join → enter café → place furniture → prepare coffee → serve customer
     → buy decoration → view neighbourhood
```

## Metrics to watch
Tutorial completion · first-session duration · drop-off step · first-customer
completion · furniture-placement rate · neighbour-visit rate · D1/D7 retention ·
avg session length · error rate · mobile performance · payer conversion (after
monetisation).

## Conventions
- `snake_case` event names; stable once shipped.
- Params are small and typed (recipe id, coins, item id) — no PII, no free text.
- `first_*` = once per player; use `TrackOnce`.
- Treat early target numbers as hypotheses; compare to Creator Dashboard benchmarks.

## References
- <https://create.roblox.com/docs/production/analytics>
- <https://create.roblox.com/docs/production/analytics/funnel-events>
