# Session handoff — 2026-07-20

Paste the "Prompt for the next session" block below into a fresh session to
continue. Full project context is still in [HANDOFF.md](../HANDOFF.md).

## Where things stand

- **Branch:** `codex/active-cafe-shift-loop` — **PR #3** (open, CI green at
  commit `ac121c4`): <https://github.com/Barnat-alaa/roblox_game/pull/3>.
  Merge it to main once the layout below is visually confirmed.
- This branch contains, all committed + CI-green:
  1. **The active café shift loop** (Codex's work, finished + verified by me):
     finite staff shift capacity, satisfaction + cleanliness pressure, visible
     dirt, angry emoji walkouts, physical order carry-to-table, street approach,
     sealed map + fall-watchdog, explicit 20× offline economy. 51/51 TestEZ pass.
  2. **Graphics haul**: the last 5 greybox shop items now use real models
     (prep station, glass table, potted plant, floor lamp, rug); pivot
     normalization fixed the lamp/rug orientation; dirt is a real spill mesh
     (no "CLEAN ME" text); warm plaster walls replace the orange; neon café
     sign on facades; new coffee-cup prop.
  3. **Owner polish (2026-07-20)**: espresso machine sits ON the counter
     (rotated); counter widened via a non-uniform stretch; dirt made rarer
     (55s); cleaner reverted to the Mom base (maid rig looked worse); cleaning
     is now a **broom scrub in place** (Fx.scrub) for maid + owner, no carrying;
     mug/food props normalized upright + placed on a fixed worktop height.

## ⚠️ THE ONE OPEN ITEM — kitchen left/right layout (NOT visually confirmed)

The owner wants, from THEIR gameplay camera: **espresso machine more to the
right, front door more to the left, counter wider.** Left/right is mirrored
between my server-coordinate view and the owner's camera, so I flipped it blind
at the end and could not re-verify. Current values:

- `src/shared/Config/World.luau` → `doorCenterFrac = 0.7`
- `src/server/Services/DataService.luau` seed `seed_coffee` → `gridX = 4`
- Counter: `Furniture.luau` counter `width = 6`; `AssetManifest` counter
  `widen = 2.1`, `maxSpan = 24` (it's at seed `gridX = 4`, cells 4–9).

**To fix fast:** open `SocialCafe.rbxlx`, look at the starting café. If the door
is still on the wrong side, **swap `doorCenterFrac` between 0.7 and 0.3** and
**swap the seed machine `gridX` between 4 and 8** (they move together). Adjust
`widen` if the counter is too wide/narrow. Rebuild + relaunch to check.

## Other things worth a look next

- Verify the **broom scrub** looks good on a live dirt event (dirt is rare now;
  force one by lowering `Operations.dirtSpawnSeconds` temporarily, or set a
  profile's `operations.lastDirtAt` back).
- The **coffee machine on the counter** may need its `liftY` (3.5) nudged so it
  sits flush on the widened counter's worktop.
- Rejected assets to re-shop: a **barista rig** with a HumanoidRootPart (the
  owner's 4646109032 had none), and a **wallpaper** texture that isn't
  "unauthorized" (13010827217 wouldn't load) — see docs/GRAPHICS_AUDIT.md.

## Workflow reminders (from HANDOFF.md)

Gates: `stylua --check src tests` (unpiped `selene src tests`) + `rojo build`
both `default.project.json` and `test.project.json`. Studio MCP is flaky and
sometimes opens its home page on relaunch (reopen from Recent). Never run two
agents on this repo at once.

---

## Prompt for the next session

> Continue the Social Café game (repo at C:\Users\barna\Desktop\roblox). Read
> HANDOFF.md, then docs/SESSION_HANDOFF.md. You're on branch
> `codex/active-cafe-shift-loop` (PR #3, CI green). FIRST TASK: fix the kitchen
> left/right layout that wasn't visually confirmed — open SocialCafe.rbxlx in
> Studio, playtest, and make sure from the player's camera the espresso machine
> is on the right, the entry door is on the left, and the counter is wide. The
> knobs are `World.doorCenterFrac` (swap 0.7↔0.3), the seed `seed_coffee`
> `gridX` in DataService (swap 4↔8), and the counter `widen` in AssetManifest.
> Keep StyLua+Selene+Rojo gates green, commit with conventional messages +
> CHANGELOG, push to the branch, and keep PR #3 updated. Then, if the owner
> approves, merge PR #3 to main. Work in strict Luau, verify live via Roblox
> Studio MCP, and never import copyrighted assets.
