# Current status

_Last updated: 2026-07-13 — Day 1 scaffold._

## What was completed

- Full Rojo project scaffold in strict Luau that is intended to build and play as a greybox.
- Toolchain manifests: `rokit.toml`, `wally.toml`, `default.project.json`, `stylua.toml`, `selene.toml`, `.luaurc`.
- CI workflow (`.github/workflows/ci.yml`): StyLua check → Selene lint → Rojo build → artifact upload.
- **Shared:** typed `PlayerData`/recipe/furniture/customer/order types; data-driven Config (Economy, Recipes×5, Furniture×7, Customers×3, Progression, Staff); `Remotes` registry; pure `Grid`, `RateLimiter`, `RewardMath`, `Log` utilities.
- **Server:** service framework (`ServiceRegistry` + two-phase Init/Start loader) and services: `DataService` (load/reconcile/migrate/autosave/BindToClose + in-memory fallback), `EconomyService` (authoritative coins/rep/xp + purchase), `CafeService` (builds 6 greybox plots, assigns + teleports, renders furniture), `BuildService` (server-validated placement), `OrderService` (serve/claim with double-claim + distance guards), `CustomerService` (order generator), `RecipeService`, `ProgressionService`, `AnalyticsService`, plus Staff/Social/Monetization placeholders.
- **Client:** loader + `UIController` (HUD: coins/rep/level, order banner, Serve button, shop, toasts), `BuildController` (grid preview + place/rotate), `TutorialController` (learn-by-doing hints), and Interaction/Camera/Cooking placeholders.
- **Tests:** TestEZ specs for RewardMath, Grid placement, Progression.
- Docs set (this file + README, ROADMAP, ARCHITECTURE, SECURITY, TEST_PLAN, RELEASE_CHECKLIST, ECONOMY_BALANCE, ANALYTICS_EVENTS, ASSET_LICENSES, KNOWN_ISSUES, THIRD_PARTY_NOTICES).

## What was tested

- File/JSON authoring validated locally (see `NEXT_ACTIONS.md` for the JSON check).
- **Not yet run inside Studio** — Rojo/Studio are not installed on this machine yet, so a live build + playtest is the immediate next step.

## What failed / is not done

- No live Studio build has run (toolchain not installed here).
- Visible walking NPCs, manual-cook minigame, café-visit interaction, lighting/audio pass, and the mobile control polish are pending (Days 3/5/6).
- DataStore persistence is single-key with retries, **not** ProfileStore session-locking yet (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md)).

## What YOU need to do next

See [NEXT_ACTIONS.md](NEXT_ACTIONS.md). In short: install Rokit, run `rokit install`,
connect Studio↔Claude Code over MCP, then press Play and report what you see.

## Exact command to continue

```sh
cd C:\Users\barna\Desktop\roblox
rokit install && rojo build --output SocialCafe.rbxlx
```
