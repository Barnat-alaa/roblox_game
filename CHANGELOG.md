# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed — 2026-07-13 — Day 1 live verification
- **Client boot**: `Main.client.luau` waited on `script:WaitForChild("Controllers")`, but `Controllers` is a sibling folder — no controllers or UI ever loaded. Now `script.Parent:WaitForChild("Controllers")`. Found in the first live playtest via MCP console read.
- StyLua formatting drift in test specs; repo now passes `stylua --check .`.
- Selene reported 55 `undefined_variable` errors for TestEZ globals in `tests/*.spec.luau`; added `testez.yml` standard library and switched `selene.toml` to `std = "roblox+testez"` (0 errors).
- `.gitignore`: ignore Studio `*.rbxlx.lock`/`*.rbxl.lock` files and local `.mcp.json`.

### Verified — 2026-07-13
- 21/21 unit specs pass inside Studio (MCP harness, live DataModel).
- Clean server boot (6 plots, 12 services) and client boot (6 controllers).
- E2E serve loop through real remotes: payout matches config, duplicate claim pays nothing.

### Added — 2026-07-13 — Day 1 scaffold
- Rojo project in strict Luau: toolchain manifests, CI, project mapping.
- Shared layer: type definitions, data-driven config (economy, 5 recipes, 7 furniture items, 3 customers, progression, staff), remotes registry, pure utilities (Grid, RateLimiter, RewardMath, Log).
- Server: service framework + DataService (persistence w/ in-memory fallback, autosave, migration hook), EconomyService, CafeService (greybox 6-plot street), BuildService (server-validated placement), OrderService (serve/claim with anti-double-claim + distance guard), CustomerService (order generator), RecipeService, ProgressionService, AnalyticsService, and Staff/Social/Monetization placeholders.
- Client: HUD (stats, order, serve, shop, toasts), grid-based BuildController with live preview, learn-by-doing TutorialController, placeholder controllers.
- Tests: TestEZ specs for economy payout, grid placement, and progression.
- Documentation set (design, architecture, security, tests, release, economy, analytics, licences).
