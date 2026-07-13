# Current status

_Last updated: 2026-07-14 — Day 3 complete in code; brew minigame awaiting live playtest._

## What was completed

- **Day 1 verified live** (2026-07-13): 21/21 unit specs in Studio, clean boot,
  e2e serve loop through real remotes, duplicate claim pays nothing, client
  boot-path bug found and fixed. Pushed; CI green.
- **Day 3 part 1 — visible customer NPCs** (verified live in play mode):
  street spawn → walk in → order bubble → serve reaction (😊 +N 🪙) → walk out
  → next customer cycles in. Patience timeout (120s) cancels the order
  server-side and the NPC leaves angry. Stuck-NPC teleport recovery.
- **Day 3 part 2 — manual brew minigame** (code complete, gates green):
  ProximityPrompt on your own coffee machine → oscillating timing bar →
  Space/tap to stop in the green zone. Server-authoritative: RecipeService
  starts its own clock on StartCooking and re-derives the bar position on
  FinishCooking from shared Config/Cooking constants; a hit arms a ONE-SHOT
  manual bonus consumed at claim. The client's `manualCook` argument is now
  ignored entirely.
- SocialCafe.rbxlx rebuilt from the repo — reopening it loads everything.

## What was tested

- All CI gates: StyLua ✓ · Selene 0 errors ✓ · Rojo build ✓ (21/21 specs from Day 1 unaffected).
- NPC lifecycle end-to-end in play mode, including the accidental-but-real
  patience-expiry test (order cancelled, banner cleared, NPC left).
- Serve economics: payouts match config exactly (espresso 8, tea 7 — the
  "7,7" mystery was random recipe selection, not a bug).

## What failed / is not done

- **Brew minigame not yet exercised in a live playtest** (Studio was closed
  mid-session for the language switch). Next session: verify prompt →
  bar → server verdict → bonus payout, plus the forged-claim negative test.
- Croissant/sandwich recipes reference `oven`/`prep_counter` appliances that
  have no interaction yet (machine-only brewing for now) — fine for MVP.
- Days 5–7 pending: onboarding, neighbourhood pass, mobile, publish.

## What YOU need to do next

1. Reopen `C:\Users\barna\Desktop\roblox\SocialCafe.rbxlx` in Studio.
2. Publish it: **Alt+P** → name `Social Cafe DEV` → Create, then
   Game Settings → Security → **Enable Studio Access to API Services** → Save.
3. Press Play and try the loop yourself: walk to the coffee machine, press
   **E** when a customer orders, stop the bar in the green, then **Serve ☕**.
   You should see a bigger payout than an unbrewed serve.

## Exact command to continue

Open a Claude Code session in `C:\Users\barna\Desktop\roblox` and say
"continue" — next up is the live brew verification, then Day 5 (onboarding +
neighbourhood + lighting).
