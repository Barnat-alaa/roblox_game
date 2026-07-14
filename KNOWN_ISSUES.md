# Known issues

Tracked shortcomings of the current build. Each has an owner-facing note and a plan.

## Data / persistence
- **No cross-server session locking.** `DataService` uses a single DataStore key
  with retries + autosave, not ProfileStore. Risk: item duplication / data loss
  if the same user is active on two servers, and no rollback tooling.
  **Plan:** swap the load/save internals for ProfileStore before soft launch
  (Week 6). Public API is designed so the swap is internal. → docs/ARCHITECTURE.md
- **In-Studio play does not persist** unless the place is published with
  "Studio Access to API Services" enabled. Expected; the in-memory fallback keeps
  local testing working.

## Gameplay (MVP prototypes)
- **No visible walking customer NPC yet.** Orders are generated and surfaced on the
  HUD; the physical NPC + seat/counter routing is the Day-3 task.
- **No manual-cook minigame yet.** `ClaimOrder` always passes `manualCook=false`,
  so the quality bonus path is untested end-to-end. Day-3.
- **Serve distance check is coarse** (within 60 studs of plot centre) rather than
  "at the counter." Tighten when the counter interaction point is wired.

## Build mode
- **Screen→grid raycast can be a few studs off** due to the GUI-inset offset in
  `GetMouseLocation`. The server still validates, so it's cosmetic; refine the
  offset handling during the mobile pass (Day-6).
- Placement is full-grid, single-floor, 100-object cap by design for the MVP.

## Client
- **Tutorial is client-only.** `tutorialCompleted` is not yet persisted via
  `CompleteTutorialStep`. Day-5.
- No audio, no lighting/atmosphere pass yet (greybox).

## Security
- ~~Zero-gap duplicate-claim race~~ **RESOLVED 2026-07-14**: three simultaneous
  claims of one order paid exactly once (live behavioural test). Manual-cook
  forgery also verified impossible — see docs/SECURITY.md.

## Tooling
- Toolchain verified working: rokit 1.2.0, rojo 7.4.4, stylua 2.0.2, selene 0.27.1.
- Selene needs `testez.yml` (committed) and the Roblox std (auto-generated in CI
  via `selene generate-roblox-std`).
- The MCP `execute_luau` context has its **own module cache** — it cannot reach the
  running game's module singletons. Drive live tests through DataModel objects
  (remotes, instances), not `require`.
