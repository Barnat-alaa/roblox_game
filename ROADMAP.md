# Roadmap

Two horizons: a **7-day playable MVP** and a **6–8 week polished soft launch**.
Guiding principle: *a small polished game beats a large unreliable one.* Scope is
cut aggressively to protect that.

## Week 1 — Playable MVP (greybox)

| Day | Goal | Status |
| --- | --- | --- |
| 1 | Setup, toolchain, project skeleton, greybox café street, data schema, CI | ✅ scaffold generated (needs `rokit install` + Studio verify) |
| 2 | Grid furniture placement: preview, rotate, server validation, save/reload | ✅ implemented (needs in-Studio testing) |
| 3 | Coffee/customer loop: order → cook → serve → coin reward, no double-claim | 🟡 order+serve done; visible walking NPC + manual-cook minigame pending |
| 4 | Progression + purchasing: coins, reputation, level, shop, HUD | ✅ implemented (needs testing) |
| 5 | Onboarding + neighbourhood: 10-min tutorial, 6 plots, visit interaction, lighting | 🟡 hint-based tutorial + 6 plots done; visit interaction + lighting pass pending |
| 6 | Mobile, security, QA: mobile pass, rate limits, save-failure handling, profiling, 2-client test, audio, analytics | 🟡 rate limits + analytics logging done; mobile/audio/profiling pending |
| 7 | Publish limited MVP: icon/thumbnail, maturity, tester access, smoke test | ⬜ pending your Roblox account + publish |

## Weeks 2–8 — Soft launch

- **Week 2 — Core polish:** 5 recipes cooking interactions, better NPC reactions, 20–30 furniture items, audio pass, save reliability.
- **Week 3 — Staff & management:** barista/waiter/cleaner, assignment, satisfaction, upgrades, café level, daily quests.
- **Week 4 — Social identity:** 6-player neighbourhood visits, predefined reactions, plaza, photo-mode prototype, sign customisation, friend joins.
- **Week 5 — Content & retention:** ~15–20 recipes, ~40–50 furniture, recipe mastery, customer variants, one special customer, weekly objectives, one helper prototype, one event.
- **Week 6 — Monetisation & hardening:** cosmetic bundle, optional pass, `ProcessReceipt` idempotency, analytics funnels, migration tests, anti-exploit review, low-end device testing, accessibility settings.
- **Week 7 — Closed alpha:** invite testers, watch onboarding, fix top drop-offs, rebalance economy, improve game page.
- **Week 8 — Limited beta / soft launch:** production RC, release checklist, backup + rollback, maturity verification, production API-key restrictions, final security review, monitor.

## Explicitly deferred (do NOT build early)

Free-placement & multi-floor building · deep staff collection · apartment ·
helper collection depth · large live-events engine · blueprint sharing ·
delivery · multiple café branches · monetisation before the loop is fun.

## Naming

Before public release: research and select a distinctive, memorable, **legally
clear** name (search Roblox + trademarks; avoid another game's identity). Track
candidates and clearance notes here when we start Week 6.
