# Session handoff — 2026-07-21

Paste the "Prompt for the next session" block below into a fresh session to
continue. Full project context is still in [HANDOFF.md](../HANDOFF.md).

## Where things stand

- **Branch:** `codex/active-cafe-shift-loop` — **PR #3**:
  <https://github.com/Barnat-alaa/roblox_game/pull/3>.
- This branch contains, all committed + CI-green:
  1. **The active café shift loop** (Codex's work, finished + verified):
     finite staff shift capacity, satisfaction + cleanliness pressure, visible
     dirt, angry emoji walkouts, physical order carry-to-table, street approach,
     sealed map + fall-watchdog, explicit 20× offline economy. 51/51 TestEZ pass.
  2. **Graphics haul**: the last 5 greybox shop items now use real models
     (prep station, glass table, potted plant, floor lamp, rug); pivot
     normalization fixed the lamp/rug orientation; dirt is a real spill mesh
     (no "CLEAN ME" text); warm plaster walls replace the orange; neon café
     sign on facades; new coffee-cup prop.
  3. **Owner polish (2026-07-20)**: espresso machine on the counter; counter
     widened via a non-uniform stretch; dirt made rarer (55s); cleaner reverted
     to the Mom base; cleaning is a **broom scrub in place** (Fx.scrub) for maid
     + owner; mug/food props normalized upright on a fixed worktop height.
  4. **Kitchen layout verified + fitted (2026-07-21)** — see below.

## ✅ RESOLVED — kitchen left/right layout (measured live in Studio)

The 2026-07-20 handoff flagged this as set-blind and unconfirmed, with advice to
"swap `doorCenterFrac` 0.7↔0.3 and seed `gridX` 4↔8". **Do not do that — the
layout was already correct.** It was measured in a live Play session against the
real placed assets:

**The axis convention (this is the fact that keeps getting re-derived wrong):**
the player enters facing **local +Z**, and with Up = +Y that puts their
**RIGHT at LOW local X** and their **LEFT at HIGH local X**. Plot is 18 cells ×
4 studs = 72 wide, so local X 36 is the centre.

| thing | local X | owner-facing side | wanted | ok |
|---|---|---|---|---|
| espresso machine | 18.0 (pivot) | RIGHT | right | ✓ |
| counter | 28.0 (pivot), spans 16–40 | right-of-centre | wide | ✓ |
| front door | 50.4 (`0.7 × 72`) | LEFT | left | ✓ |
| kitchen | cells 0–7 (X 0–32) | front-RIGHT corner | — | ✓ |

Beware: `Model:GetBoundingBox()` on these pieces is **misleading** — it returns
an oriented box and includes late-parented children (the counter's
`StockDisplay` reaches Y 5.28 and the food props shift the centre). The
2026-07-20 numbers came from that and pointed the wrong way. Measure a model's
**own BaseParts**, transformed into plot-local space via
`origin:PointToObjectSpace(corner)`.

Two real bugs that measurement exposed, both now fixed:

- **Counter under-filled its footprint** — `AssetManifest.counter.widen`
  2.1 → **2.56**. The normalised body is 9.38 studs before the multiplier and
  the 6-cell footprint is 24, so 2.1 gave only 19.7. Measured 24.02 after.
- **Machine floated 1.07 studs above the worktop** — seed `seed_coffee.liftY`
  3.5 → **2.43**. `liftY` is the model's BOTTOM height above the floor and the
  counter worktop measures **2.43** (confirmed: the Cash Register's underside
  sits exactly there). Verified live, flush gap −0.004.
- Consequence of the first: the machine sits at the footprint's right edge
  (X 15.7) but the short counter only began at 18.1, so it also hung off the
  end. Filling the footprint fixes that too.

## Other things worth a look next

- **Counter DEPTH under-fills the same way** (measured, not yet fixed): the
  counter body spans local Z 13.0–15.0 — only **2.0 studs of its 4-stud (1-cell)
  footprint** — while the espresso machine is 4.2 deep, so the machine overhangs
  ~1.1 studs front and back. `widen` only stretches the LONGER horizontal axis,
  so fixing this needs a companion `deepen` field in `AssetManifest` +
  `AssetLibraryService.normalizeModel` (mirror the existing widen loop).
- Verify the **broom scrub** looks good on a live dirt event (dirt is rare now;
  force one by lowering `Operations.dirtSpawnSeconds` temporarily, or set a
  profile's `operations.lastDirtAt` back).
- Rejected assets to re-shop: a **barista rig** with a HumanoidRootPart (the
  owner's 4646109032 had none), and a **wallpaper** texture that isn't
  "unauthorized" (13010827217 wouldn't load) — see docs/GRAPHICS_AUDIT.md.

## Workflow reminders (from HANDOFF.md)

Gates: `stylua --check src tests` (unpiped `selene src tests`) + `rojo build`
both `default.project.json` and `test.project.json`. Studio MCP is flaky and
sometimes opens its home page on relaunch (reopen from Recent). Never run two
agents on this repo at once.

`SocialCafe.rbxlx` is a gitignored build artifact — after pulling source
changes, rebuild it (`rojo build --output SocialCafe.rbxlx`) before opening
Studio, or Studio will still be running the old scripts.

**Screenshots during Play:** `screen_capture`'s `camera_position` argument is
ignored, and the game's own camera controller overwrites
`workspace.CurrentCamera` every frame, so a scripted camera pose will not hold.
Prefer numeric measurement via `execute_luau` for geometry questions.

---

## Prompt for the next session

> Continue the Social Café game (repo at C:\Users\barna\Desktop\roblox). Read
> HANDOFF.md, then docs/SESSION_HANDOFF.md. The kitchen left/right layout is
> DONE and verified — do not flip `doorCenterFrac` or the seed `gridX`; the
> convention is that the player's RIGHT is LOW local X. Good next tasks: the
> counter's depth under-fill (needs a `deepen` companion to `widen` in
> AssetManifest + AssetLibraryService), and a live check that the broom scrub
> reads well on a real dirt event. Keep StyLua+Selene+Rojo gates green, commit
> with conventional messages + CHANGELOG, and open a PR. Work in strict Luau,
> verify live via Roblox Studio MCP by MEASURING (screenshots can't be posed
> during Play), and never import copyrighted assets.
