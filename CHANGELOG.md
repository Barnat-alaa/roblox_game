# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added — 2026-07-13 — Day 1 scaffold
- Rojo project in strict Luau: toolchain manifests, CI, project mapping.
- Shared layer: type definitions, data-driven config (economy, 5 recipes, 7 furniture items, 3 customers, progression, staff), remotes registry, pure utilities (Grid, RateLimiter, RewardMath, Log).
- Server: service framework + DataService (persistence w/ in-memory fallback, autosave, migration hook), EconomyService, CafeService (greybox 6-plot street), BuildService (server-validated placement), OrderService (serve/claim with anti-double-claim + distance guard), CustomerService (order generator), RecipeService, ProgressionService, AnalyticsService, and Staff/Social/Monetization placeholders.
- Client: HUD (stats, order, serve, shop, toasts), grid-based BuildController with live preview, learn-by-doing TutorialController, placeholder controllers.
- Tests: TestEZ specs for economy payout, grid placement, and progression.
- Documentation set (design, architecture, security, tests, release, economy, analytics, licences).
