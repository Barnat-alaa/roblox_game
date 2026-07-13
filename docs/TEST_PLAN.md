# Test plan

## Layers
1. **Unit (pure logic)** — TestEZ specs in `tests/`. No Roblox services touched
   beyond requiring config. Fast, deterministic.
2. **Studio integration** — client/server behaviour, multi-player, remote security,
   save/reload, mobile emulation.
3. **Smoke** — the end-to-end "does the core loop work" gate before publishing.

## Unit specs (present)
- `Economy.spec.luau` — payout, manual-cook bonus, non-negative floor, tip chance/scale.
- `Placement.spec.luau` — footprint rotation, bounds (incl. rotated edges), overlap, occupied cells.
- `Progression.spec.luau` — level thresholds (incl. cap), star thresholds.

Planned: `SaveMigration.spec.luau` (write before any schema change),
`Recipes.spec.luau` (config invariants: ingredientCost < basePrice, valid appliance ids).

## Running unit tests
The specs are TestEZ-format `return function() … end` modules. To run them:
1. Add `TestEZ` to `wally.toml` dev-dependencies and `wally install`.
2. Create a `test.project.json` mapping `ReplicatedStorage.Shared`, the `Packages`,
   and the `tests/` specs into a place.
3. Run via a runner script (`TestEZ.TestBootstrap:run({ ... })`) in Studio, or headless
   with `run-in-roblox` + Open Cloud in CI (Day-6 task).

CI today runs **format + lint + build**; the Roblox test runner is wired in Day 6.

## Studio integration checklist
- Two clients join; each gets a distinct plot; no cross-write.
- `ClaimOrder` cannot double-pay (spam the button / replay the id).
- `PlaceFurniture` rejects out-of-bounds, overlap, unowned, spammed requests.
- Save on leave + rejoin restores coins, inventory, and placed furniture
  (requires a published place with API access enabled).
- `BindToClose` saves on server shutdown.
- Mobile emulation (Studio device emulator): all core actions reachable by touch,
  large targets, no hover-only interactions.

## Smoke test (pre-publish gate)
1. Server starts, no red Output errors.
2. Player joins; profile loads; café renders.
3. An order appears; serving grants the reward **once**.
4. Furniture can be placed and persists.
5. A purchase debits coins and adds inventory.
6. Rejoin restores data.

## Tools
MicroProfiler + Scene Analysis for performance; Studio device emulator for mobile;
Output for error triage. Real Android device test before any public release.
