# Architecture

## Principles
- **Server-authoritative.** The client requests; the server decides every reward,
  currency change, unlock, and placement. See [SECURITY.md](SECURITY.md).
- **Data-driven.** Recipes, furniture, customers, economy, progression live in
  `src/shared/Config` as typed tables, not hardcoded in logic.
- **Strict Luau** (`--!strict`) with explicit types for player data, network
  payloads, and economy transactions.
- **Small, understandable modules** over heavy frameworks. Zero runtime third-party
  dependencies in the MVP.

## DataModel mapping (Rojo → `default.project.json`)
```
ReplicatedStorage/Shared      ← src/shared   (Types, Config, Network, Utilities)
ServerScriptService/Server    ← src/server   (Main.server + ServiceRegistry + Services)
StarterPlayerScripts/Client   ← src/client   (Main.client + Controllers)
```

## Boot sequence
**Server** (`Main.server.luau`): `Remotes.init()` → require every `Services/*`
module → register in `ServiceRegistry` → **Init** all (resolve dependencies) →
**Start** all (each in its own thread). **Client** mirrors this for `Controllers/*`.

Services/controllers are plain tables with optional `Init(self)` / `Start(self)`.
Cross-service references are resolved in `Init` via `ServiceRegistry.get(name)` to
avoid circular `require`s. On the client the dependency is inverted: gameplay
controllers depend on `UIController` (via `onBuildToggle` + `subscribeProfile`),
never the reverse.

## Server services
| Service | Responsibility |
| --- | --- |
| `DataService` | Load/reconcile/migrate profiles; autosave; save-on-leave; BindToClose; in-memory fallback when DataStore API is off. `GetProfile`/`IsLoaded`/`Push`. |
| `EconomyService` | Authoritative coins/reputation/xp mutations; `PurchaseItem` handler. |
| `ProgressionService` | Level-for-xp and stars-for-reputation lookups. |
| `RecipeService` | Recipe lookups, unlock checks, payout via `RewardMath`. |
| `OrderService` | Order lifecycle; `ClaimOrder` with type/ownership/double-claim/distance/rate-limit guards. |
| `CustomerService` | Generates orders per café (visible NPC routing = Day 3). |
| `CafeService` | Builds the greybox plot street; assigns/teleports; renders saved furniture; exposes plot origin. |
| `BuildService` | `PlaceFurniture`/`RemoveFurniture` with ownership/bounds/overlap/rotation/count/rate validation; renders parts. |
| `AnalyticsService` | Structured event logging; `TrackOnce` for first_* funnel events. |
| `StaffService`/`SocialService`/`MonetizationService` | Placeholders for Weeks 3/4/6. |

## Client controllers
`UIController` (HUD, order/serve, shop, toasts, profile fan-out) · `BuildController`
(grid preview + place/rotate) · `TutorialController` (learn-by-doing hints) ·
`Interaction`/`Camera`/`Cooking` (Day-3 placeholders).

## Data flow example — serving a customer
1. `CustomerService` picks an unlocked recipe → `OrderService:CreateOrder` → fires
   `OrderCreated` to the owner's client.
2. `UIController` shows the order + Serve button.
3. Player taps Serve → `ClaimOrder(orderId, manualCook)` to the server.
4. `OrderService` validates (exists, owned, not claimed, unlocked, near café, rate) →
   marks claimed **before** granting → `EconomyService:AddCoins/Reputation/Experience`
   → `DataService:Push` → `Notify` back to client.

## Persistence
Profiles are cached in memory and mutated there; writes happen on autosave
(`Economy.autosaveIntervalSeconds`), on `PlayerRemoving`, and on `BindToClose`.
Schema changes bump `PlayerData.schemaVersion` and add a branch in
`DataService.migrate`; `reconcile` fills newly-added keys on old saves.

**Production upgrade path:** replace `DataService.loadAsync`/`saveAsync` internals
with ProfileStore for session locking + safer autosave. The public API
(`GetProfile`/`IsLoaded`/`Push`) stays the same, so callers don't change. Add
`tests/SaveMigration.spec.luau` before any schema change ships.

## Environments
`DEV_` / `STAGING_` / `PROD_` DataStore prefixes keep data separate (`ENV_PREFIX`
in `DataService`). Publishing to staging/production is a manual, approved step —
never automatic. See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).
