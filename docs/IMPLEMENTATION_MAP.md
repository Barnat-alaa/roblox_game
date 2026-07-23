# Implementation map — the precise code hooks for the direction build

_Created 2026-07-23. Companion to `docs/GAMEPLAY_DIRECTION.md`: that doc says
**what** to build and **why**; this one says **exactly where** each feature
attaches in the code, with file + symbol + line references verified by a
full read of the services. Line numbers are as of this date — re-grep the symbol
if the file has since moved. Read this before starting any phase._

**Legend:** every hook below preserves the house style — `--!strict`, plain-table
modules with `Init`/`Start`, server-authoritative remotes validated up front,
data-driven config in `src/shared/Config`, and self-healing save shapes.

---

## Cross-cutting decisions (settle these once)

- **Pantry lives at `PlayerData.pantry: { [string]: number }` (top-level).**
  `reconcile` (`DataService.luau:177`) shallow-fills missing **top-level** keys
  from `defaultProfile`, so a top-level map self-heals onto old saves **with no
  schema bump** — mirroring `inventory`. A nested `kitchen.pantry` would need
  `kitchenOf` + `migrate` healing; avoid it. A defensive `migrate` coercion
  block is still added (non-table → `{}`, floor/drop bad values).
- **Everything is a config row, never a branch.** Ingredients, the staff roster,
  VIP scoring weights, gift/neighbour reward tables, bulk tiers, and Robux SKUs
  are typed tables in `src/shared/Config`. Adding content = adding a row.
- **Every currency mutation goes through `EconomyService`** (`TrySpendCoins` /
  `AddCoins` / `AddReputation`); never touch `data.coins` directly. Persist with
  `DataService:Push(player)` after every mutation. Surface feedback through the
  existing `Notify` event (`{ kind, reason }`), not new remotes.
- **New remotes** = one string appended to the `EVENTS` array in
  `Remotes.luau:14` (the folder loop auto-creates them). Validate every field
  server-side; compute costs server-side; rate-limit with `RateLimiter`.

---

## Feature 2 — Ingredients (Phase A, build first)

### Data model
| What | File · symbol · line | Change |
| --- | --- | --- |
| Pantry field | `Types/init.luau` · `PlayerData` · 148 | add `pantry: { [string]: number }` near `inventory` (158) |
| Recipe ingredients | `Types/init.luau` · `RecipeDefinition` · 171 | add `ingredients: { [string]: number }?` (optional → old recipes typecheck) |
| Seed | `DataService.luau` · `defaultProfile` · 117 | add `pantry = { … }` (generous starter so old saves inherit it via `reconcile`) |
| Heal | `DataService.luau` · `migrate` · ~246 | add unconditional coercion block (non-table→`{}`, `math.floor`, drop `<0`); **no `SCHEMA_VERSION` bump needed** for a top-level map |
| Palette config | **new** `Config/Ingredients.luau` | `{ [id] = { displayName, icon, rarity, unlockLevel, unitPrice } }` |
| Recipe tables | `Config/Recipes.luau` · each recipe · 7+ | add `ingredients = { flour = 2, … }` per recipe (data-driven; amounts are a tuning pass) |
| Bulk tiers | `Config/Economy.luau` · 5 | add `bulkTiers = { 25, 50, 100, 250 }` (+ "Max" computed client-side) |

### Consumption (gate behind `Kitchen.enforceIngredients` so it ships dormant)
| Path | File · symbol · line | Change |
| --- | --- | --- |
| Manual cook | `KitchenService.luau` · `handleStartCook` · 715 | **check** pantry after `too_far` (743) and **before** the coin spend (745); **decrement after** `TrySpendCoins` succeeds; new reason `out_of_ingredients` |
| Helpers | `KitchenService.luau` (new locals) | `hasIngredients(recipe, pantry)` + `consumeIngredients(recipe, pantry)`; gate all on `recipe.ingredients ~= nil` |
| Auto job | `ProductionService.luau` · `startJob` · 92 | same check/decrement after `CanUseCapacity` (113); on shortfall show the **`resting` appliance visual** (106-112), not a Notify (this ticks every 1s) |
| Scheduler | `ProductionService.luau` · `chooseRecipe` · 56 | add `and hasIngredients(recipe, pantry)` to the eligibility clause (65-70) so it skips out-of-stock recipes instead of stalling the appliance |
| Emergency serve | `KitchenService.luau` · `AddEmergencyServing` · 253 | **product decision:** this paid convenience should probably NOT consume pantry; leave as coins-only, documented |

### Market (buy) — Phase A step 2
- Remote: append `MarketBuyIngredient` to `EVENTS` (`Remotes.luau:14`); payload
  `{ ingredientId: string, qty: number }`.
- Handler: model on `EconomyService.handlePurchase` (84): typeof guards → whitelist
  `qty` against `Economy.bulkTiers` → `buyLimiter:check` → `Ingredients[id]` exists
  → `GetProfile` → level/unlock gate → **compute cost server-side**
  (`unitPrice*qty`, bulk discount) → `TrySpendCoins` (single atomic debit) →
  `data.pantry[id] += qty` → `Push` → `Notify{kind="purchased"}`. Consider a
  dedicated `RateLimiter` so bulk clicks don't starve the shared 10/s budget.
- **Coin-spend sites that already deduct "ingredient cost":** `handleStartCook`
  (`:745`), `ProductionService.startJob` (`:119`), `AddEmergencyServing` (`:266`).
  Decide whether `ingredientCost` coins and the new pantry both apply (the
  `Recipes.luau:5` comment requires `ingredientCost < basePrice` for profit —
  don't double-charge). Current plan: keep `ingredientCost` as the coin sink and
  let pantry be the **stock gate**; revisit in balance pass.

### Client (Phase A step 2)
- Market tab: extend `UIController.buildShop`/`setShopCategory` (649/611) or a
  pantry drawer cloned from `InventoryController.buildDrawer` (583).
- Locked-blur cards: `Components.ItemThumbnail` (312) `setLocked(true, "LV n")` —
  reuse verbatim; blur constants live in `Theme.Thumbnail.Blur`.
- Lock/afford refresh: fold rows into `UIController.updateStats` (317), keeping
  the `setLocked` flip-guard (326) so 14-sample blur overlays rebuild only on
  state change.
- Friendly error: add `out_of_ingredients` to `FRIENDLY_ERROR` (`UIController:23`).

---

## Feature 1 — Staff hire + upgrade (Phase A)

### Data model
| What | File · symbol · line | Change |
| --- | --- | --- |
| Hired flag | `Types/init.luau` · `StaffMember` · 30 | add `hired: boolean` (after `experience`, 34). `level` already exists (33) and already scales speed in `StaffService.GetRoleSpeed` (85) |
| Seed | `DataService.luau` · `starterStaff` · 69 | `hired = true` for barista + waiter; `hired = false` for cook + cleaner (keep them in the seed so the hire UI can show them) |
| Heal | `DataService.luau` · `migrate` · ~258 | add a staff heal loop **outside** the `<2` branch: floor `level>=1`, clamp `experience>=0`, default missing `hired` to **true** (legacy staff were active). Bump `SCHEMA_VERSION 3→4`; `reconcile` can't reach array elements |

### Gating & effects
| What | File · symbol · line | Change |
| --- | --- | --- |
| Lock spawn | `StaffService.luau` · `CountRole` · 70 | add `and member.hired ~= false` to the predicate (74) → locked roles exist in data but `HasRole`=false so `ensureCrew` never builds the NPC. Treat `nil/true` as active |
| Upgrade → recovery | `CafeOperationsService.luau` · `recoverOnline` · 428 | multiply `rate` by a per-role level factor (new `StaffService:GetRoleLevelMultiplier`); **this is the lever that makes an upgrade *felt*** — level today only nudges `OperationsMath` speed (0.08/level), not the capacity meter |
| Upgrade → speed | `OperationsMath.luau` · `staffInfo` · 8 | already scales throughput off level; leave as the model |
| Curve config | `Config/Kitchen.luau` · `staffLevelSpeedPerLevel` · 18 | add sibling capacity/recovery-per-level constants (or a per-level curve); keep tuning in one block |

### Data-driven roster (do while touching the above, to avoid a later refactor)
- **Three hardcoded `{Barista,Cook,Waiter,Cleaner}` lists** — `CafeOperationsService.stateOf:54`,
  `DataService` heal `:235`, `Operations.onlineRecoveryPerMinute:15` — silently
  drop any new role. Unify into one `Staff.Roles()` source before adding
  Chef/Cashier/Manager/Delivery/Entertainer.
- `StaffDefinition` (`Config/Staff.luau:5`) is the home for the roster: add
  `locked`/`hireCost`/`maxCount`, `recoveryPerMinute`, and
  `appearance`/`spawnOffset` (move the inline look tables out of `ensureCrew`).
- `StaffService.Crew` struct + `ensureCrew` (59-64, 675-752) are hardcoded to
  four named slots — generalise to a `{ [role]: StaffNpc }` map driven by the
  roster so new roles need no code.

### Remotes & handlers
- Append `HireStaff` `{ typeId }` and `UpgradeStaff` `{ staffId }` to `EVENTS`.
- `HireStaff` (new handler, model on `handlePurchase`): validate typeId in config,
  `CountRole` cap, `TrySpendCoins(hireCost)`, `table.insert(data.staff, {…, hired=true})`,
  `Push`. `UpgradeStaff`: scan `data.staff` by `.id` (ownership), server-compute
  cost from `member.level`, enforce `maxLevel`, `member.level += 1`, `Push`.
- Client: new `StaffController` (one-panel-per-controller convention), subscribe
  via `UIController.subscribeProfile` (236), cards modelled on
  `InventoryController.makeProductionRow` (494), capacity bar copied from
  `OperationsController.makeRow` (55), celebration generalised from
  `UIController.celebrateLevel` (333). Delete the `comingSoon` field on the
  `HUD_BUTTONS` Staff row (`UIController:83`) and register its action.

---

## Feature 3 — VIP + gift box (Phase B)

- **New `Services/VipService.luau`** — a trimmed `PedestrianService`, NOT a branch
  in `CustomerService` (whose spawner at `:1162` is strictly per-owner-café).
  Register in `ServiceRegistry`; own `workspace.VipGuests` folder.
- Target selection: copy `PedestrianService.pickOpenCafe` (174) but replace the
  random pick (192) with a **most-active** score. Enumerate cafés via
  `CafeService:GetPlotInfo(index)` (1302) for `1..World.plotCount` (works for any
  owner, not just the local player). **Activity metric:** live `data.buzz` /
  `KitchenService:GetBuzz` is the pragmatic "most active" proxy (no persisted
  "recent serves" window exists); add `CafeService:GetPlotActivity(index)` if a
  rolling metric is wanted later.
- Movement: reuse `doorApproach`/`stepTo`/`visitCafe` + `NpcNav.walkTo` +
  `NpcNav.assignNpcGroup` + `NpcAnimator.setup` + `SetNetworkOwner(nil)`.
- Gift box: copy the `dropTip` prompt blueprint (`CustomerService:683`) —
  anchored part + billboard + `ProximityPrompt` + `claimed` guard + owner check +
  120s auto-despawn. Grant from a **weighted table** in new `Config/Gifts.luau`
  rolled by a new `RewardMath.rollGift` (mirrors `RewardMath.tipAmount` at 873).
  **Extract a shared prompt factory** — `dropTip` and the dirty-plate cleanup
  (836-858) already duplicate this; the gift box would be a third copy.
- Reward types today: coins + reputation; the table is built so
  furniture/skins/ingredient-crates/boosts append as rows.

---

## Feature 4 — Neighbour help + mischief (Phase C)

### 4a. Neighbour help (co-op)
- **New `NeighbourHelp` remote + handler in `SocialService`** — do NOT overload
  `VisitCafe`. Copy `handleVisit`'s guard ladder (61): table check →
  `visitLimiter:check` → integer `plotIndex` → `GetPlotInfo` → reject empty/self →
  resolve online owner.
- Actions are a data table: `HELP_ACTIONS = { [id] = { label, reputation, buzz,
  cooldownDaily, fxKind } }`, mirroring the `COMPLIMENTS` whitelist (31-35).
  Water plants / bus table / restock / stir pot / flyers become rows.
- Proximity: reuse `isNearPlot(player, origin, radius)` (51). There is **no**
  public "inside which neighbour café" API — build it from `GetPlotInfo.origin` +
  `Grid.distanceToPlotRect` (use rect distance for deep S2 plots).
- Anti-farm: `complimentGiven` (40) is **session-only** (cleared on leave, 165).
  For a **per-neighbour-per-day** cap add `helpGiven[visitor][owner] = { day, count }`
  with `day = math.floor(os.time()/86400)`; persist on `PlayerData` if it must
  survive rejoin. Friendship level is a new persisted per-pair counter feeding a
  reward ladder.
- Offline-owner reward: `EconomyService:AddReputation` takes a `Player` — decide a
  path for rewarding an offline neighbour.

### 4b. Smell bomb (competitive)
- VFX: **new `Fx.smellVapour(position, seconds)`** modelled on `Fx.scrub`
  (`Fx.luau:50`) — anchored invisible part + green `ParticleEmitter` + `task.spawn`
  timed disable + `Debris`. Keep Rate/Lifetime modest (it replicates to everyone).
- Placement: resolve target origin via `GetPlotInfo` (reject self/empty), gate on
  proximity, anchor vapour to `origin * CFrame.new(...)` (rotation-safe).
- Re-target a customer: ambient pedestrians are **set-dressing that never
  order/tip** (`PedestrianService` header). Add `forcedTarget` to the `Ped` type
  (37-47) + `PedestrianService:LureNearest(origin)` **only for the cosmetic pull**;
  to make a lure economically real, spawn a genuine `CustomerService` customer
  aimed at the caster instead. Server-authoritative, cooldown/immunity/cap-gated.

---

## Feature 5 — Monetisation (Phase D, after the loop proves fun)

- `MonetizationService` (`:8`) is a stub. Implement `Start` to set
  `MarketplaceService.ProcessReceipt`. **Idempotency (mandatory, `SECURITY.md`):**
  key on `receiptInfo.PurchaseId`, persist a `grantedReceipts: { [string]: boolean }`
  set on `PlayerData` (top-level → `reconcile` heals it), return
  `PurchaseGranted` **only after** the grant is saved; if profile not loaded or
  save fails, return `NotProcessedYet` so Roblox retries; if the PurchaseId is
  already recorded, return `PurchaseGranted` **without** re-granting.
- Product → reward mapping is a `Config` table; grant amounts are server-side,
  never client-sent.
- The rule that keeps it rails-clean: **every Robux SKU is also buyable with
  coins** (see `GAMEPLAY_DIRECTION.md` §5).

---

## Known risks the map surfaced (carry into every PR)

- `reconcile` is **shallow** — new persisted state must be **top-level** or it is
  healed in `migrate` (nested arrays like `staff` can't rely on `reconcile`).
- Three duplicated hardcoded role lists will silently drop new staff roles.
- Level currently only nudges `OperationsMath` speed, **not** the live capacity
  meter — an upgrade that skips `recoverOnline` will feel like it did nothing.
- Three coin-spend sites deduct "ingredient cost"; a pantry system must decide
  which consume stock or it leaks a loophole (emergency serve).
- Ordering: **check before spend, decrement after spend** — never leak
  ingredients on a failed coin debit.
- The prompt/interactable pattern (`dropTip`, dirty-plate, future gift box) is
  duplicated — extract a factory before adding the third copy.
- Smell bomb is a griefing vector — proximity + `ownerUserId ~= caster` + cap are
  mandatory, not optional.
