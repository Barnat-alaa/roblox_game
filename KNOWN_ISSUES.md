# Known issues

Tracked shortcomings of the current build. Each has an owner-facing note and a plan.

## S2 architecture build (2026-07-16) — NOT yet live-verified
The facade/auto-door/3x-interior/garden rework shipped gates-green but the
Studio MCP link was down, so it has not run once. **Owner playtest checklist**
(open `SocialCafe.rbxlx` — if Studio shows its home page, use the Recent list):
1. Spawn: you stand on the street facing your café's DOOR; sign + Buzz above it.
2. Walk at the door → it swings open, closes behind you. Same on the way OUT
   (the original "trapped inside" bug). You can never be stuck: the leaf never
   blocks movement even closed.
3. Interior: noticeably bigger room (3x); furniture renders; placement preview
   turns RED past the back wall (the garden is not buildable yet — that's the
   S4 land purchase).
4. Back wall gate → the private garden: fence, tree, flower beds, stone path.
5. Customers walk IN through the door, queue inside, sit, eat, leave through
   the door. Staff (Mia/Noah/Pia) idle deeper in the room.
6. Cooking at a front stove still works (the serve/cook distance check was
   rebuilt for deep plots — this is the regression to watch).
If anything is off, screenshot + tell Claude; the next session fixes before S2
moods work starts.

## Movement
- **Staff walk in straight lines** (timeout teleport recovery): with collidable
  furniture they can bump/pop. Customers already use PathfindingService;
  migrate staffWalk to it in the S2 polish pass.

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
