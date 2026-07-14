# Current status

_Last updated: 2026-07-14 (evening) — Days 1–5 shipped; Day 6 in progress._

## Shipped and pushed (CI green on every commit)

- **Day 1** — scaffold verified live: 21/21 specs in Studio, clean boot, e2e
  serve loop, duplicate claim pays nothing, client boot bug fixed.
- **Day 3** — visible customer NPCs (verified live: walk in → order bubble →
  serve reaction → walk out → next customer; patience timeout cancels the
  order server-side). Manual brew minigame with server-judged timing.
- **Day 5** — golden-hour lighting, plaza (fountain/benches/board — screenshot
  verified), café visits + whitelisted compliments, persistent 6-step
  tutorial (strict ordering verified live: serving before brewing does NOT
  skip the brew step; step 1 auto-completed through the real controller).
- **Day 6 (so far)** — real TestEZ runner (`rojo build test.project.json`,
  RunTests bootstrap, wally dev-deps, CI builds both places). Security audit
  of all 9 remotes documented in docs/SECURITY.md; RemoveFurniture rate
  limit added. NPC pathing fix: customers order at a service window in
  front of the plot, so walks never collide with placed furniture.

## Verified live this session

- Fresh-session boot: zero errors, all 12 services + 6 controllers.
- Tutorial: step 1 fired through TutorialController → ProgressionService;
  strict order held with 3 serves banked before the brew step.
- Order economics: serve paid +7/+8 matching config exactly (tips observed).
- Patience-cancel path ran in production repeatedly (order ids advanced
  past 9 while unattended — cancellation cycling works).
- Owner playtest happened in parallel (real serves from the HUD ✔).

## Not yet verified / remaining Day 6

- Brew payout bonus assertion + zero-gap duplicate-claim race (needs one
  clean scripted pass in Studio).
- Mobile/touch pass with the device simulator; two-client visit +
  compliment test (Studio multi-client mode — needs a human click).
- Save persistence — **blocked on publishing the place** (see below).

## What YOU need to do next

1. **Publish** (unblocks persistence testing): open the place in Studio →
   Alt+P → name `Social Cafe DEV` → Create → Game Settings → Security →
   **Enable Studio Access to API Services** → Save → tell Claude "published".
2. Optional but recommended: install the **Rojo plugin** (Toolbox → Plugins →
   search "Rojo" by evaera) and click **Connect** so code syncs into Studio
   automatically.

## Exact command to continue

Open Claude Code in `C:\Users\barna\Desktop\roblox` and say "continue".
Claude can reopen Studio itself (shell-launches the .rbxlx) when needed.
