# Session handoff — Social Café City — 2026-08-01

_Authoritative pick-up doc. Read this top to bottom, then the docs it points to._

---

## 0. You are

The lead developer of **Social Café City**, a social café-management sim at
`C:\Users\barna\Desktop\roblox` (git repo, `main`, CI-green). Strict-Luau / Rojo /
Rokit / Wally, **server-authoritative**, **data-driven** (all tuning in
`src/shared/Config`). Published privately as DEV place `85898641225605`,
universeId `10501568035`. You drive Roblox Studio via the **Studio MCP**.

## 1. Read first, in this order

1. **`HANDOFF.md` §1** — the ethics rails. They are ABSOLUTE: server-authoritative,
   no loot boxes, no pay-to-win (every Robux SKU is also coin-earnable), no fake
   urgency, no free-text between players. §2a covers publishing.
2. **`ROADMAP.md` → "⭐ NEXT — owner priorities (2026-08-01)"** — the ordered
   to-do (M1–M4, B5), plus a table of every bug fixed this session and why.
3. **`CHANGELOG.md` `[Unreleased]`** — every change with its verification notes.
4. `docs/GAMEPLAY_DIRECTION.md`, `docs/IMPLEMENTATION_MAP.md`,
   `docs/CORE_LOOP_SPEC.md`, `docs/MONETISATION.md`.

## 2. 📸 THE OWNER WILL SEND SCREENSHOTS — WAIT FOR THEM

**The current work is mobile HUD polish, and the owner drives it from photos of
their phone.** Every round so far has been: they play, they screenshot, they say
what is crowded or ugly, you fix and measure.

**So: if the task is about layout, ask for (or wait for) the screenshot before
changing anything.** Guessing at what "too big" means has already cost a round.
When they send one, read it carefully — the last three rounds were all solvable
purely from what was visible in the image.

## 3. State — everything below is MERGED to `main`, CI-green

**22 PRs merged this session (#45–#66).** Headlines:

| Area | What shipped |
| --- | --- |
| Bug fixes | grass-through-road, onboarding dead-end at step 2/6, the coin glyph rendering as `□`, panels centred on screen, headers under the Roblox topbar |
| Neighbours | steal from a shelf · smell bomb that clears a café · help by WORKING inside one (the abstract help card is gone) |
| VIP | scheduled 30-min event, HUD countdown with the brainrot's portrait, NPC nearly doubled |
| Building | move already-placed furniture · floor + wall painting (8 colours × 5 motifs) · façade personalisation (3 architectures × 8 colours × 6 motifs × 6 door styles × 6 woods × 3 window shapes × 3 glass tints) |
| Monetisation | Robux store folded into UPGRADES; **consumable Stock Packs** (+5/+10/+20 of every unlocked dish) wired to the owner's real Product IDs |
| Mobile | panels dock to edges · 44px touch floor · camera chevrons · tap-to-hide HUD tab · narrow vertical pantry · six buttons on the extreme bottom |

## 4. ⚠️ NOT PUBLISHED — this is the biggest gap

**None of the 22 PRs are live.** The DEV place still runs pre-session code. The
owner runs `./scripts/publish.ps1` with their own Open Cloud key — **never handle
that key yourself**. Until then:

- nothing has been tested on a real phone;
- the **vertical pantry** and the **flash-on-tap button names** cannot be verified
  at all, because both key off "touch device with no mouse" and Studio always
  reports a mouse.

## 5. Owner actions owed

1. **Publish** (above).
2. **Create an icon** for each of the three Stock Pack Developer Products
   (`3612636850`, `3612636928`, `3612637043` — already wired in `Config/Products`).
3. **MaxPlayers = 10** on the Creator Dashboard (boot warns it is 12 vs 10 plots).
4. **Eyeball** the Clouds sky, the VIP's width (~9.4 studs against a 6-stud door —
   it clips the frame but is never physically blocked), and the new mobile HUD.

## 6. Still owed (testing)

- **A 2-player playtest** of steal / smell-bomb / help-by-working. Every guard
  ladder and every solo half is verified; what is untested is the other party
  being a genuinely different player. Studio MCP **cannot** do this — it cannot
  attach to the child processes a multi-client test spawns.
- **A live Robux purchase test** (the product IDs are real).
- **`tests/Graphics.spec`** has one pre-existing failure (Coin/Coins key
  mismatch). CI only builds, it does not run TestEZ.

## 7. Working rules the owner expects

- **Senior-dev loop, every change:** understand → build cleanly → **TEST IN
  ROBLOX STUDIO** → commit (conventional message + CHANGELOG entry) → PR → wait
  for CI green → merge. **Never merge unverified core-loop code.**
- **Gates = the CI:** `stylua --check .` + `selene .` (**unpiped**) + `rojo build`
  of BOTH `default.project.json` and `test.project.json`. Co-author commits and
  PRs to `Claude <noreply@anthropic.com>`. Branch off `main`, one deliverable per
  PR.
- **Measure, don't eyeball.** Every layout claim in this session was verified by
  reading back real geometry. Two bugs were caught that way that no screenshot
  would have shown (the inverted `math.clamp`, the dock's off-by-one plate).
- Ship risky changes behind a `Config` flag first.

## 8. Studio workflow (hard-won)

- **Relaunch:** one `Stop-Process` of `RobloxStudioBeta`, `Start-Sleep 4`,
  `rojo build`, launch the exe with the absolute place path, wait ~32s, then
  `list_roblox_studios` + `set_active_studio`. Never rebuild the `.rbxlx` while
  Studio holds it open.
- **`execute_luau` runs in an ISOLATED VM** — you cannot `require` the running
  game's singletons. Drive tests through remotes
  (`RS.Remotes.RequestProfile:InvokeServer()`) and DataModel inspection. Client
  modules under `PlayerScripts` CAN be required (that is how the layout was
  measured).
- **To test a two-player mechanic solo:** patch out the self-target guard in
  Studio's **in-memory** DataModel (`ModuleScript.Source`, Edit mode only), test,
  then revert. **Never on disk** — always verify with `grep` afterwards. Use a
  plain `string.find(..., true)` + `string.sub` splice; `gsub` treats the needle
  as a PATTERN and has silently failed here before.
- **Same trick fast-forwards timers** (a Config's `.Source`), which is how the
  30-minute VIP event and the 900-coin prices were tested.
- **The intro overlay freezes player input**, so keyboard-driven ProximityPrompt
  tests silently do nothing until you dismiss it
  (`LocalPlayer.PlayerGui.IntroOverlay.Overlay.Card.TextButton`).
- **Ambiguous instance paths**: sibling buttons often share a name
  (`Frame.TextButton`); give buttons unique `Name`s if you need to click them.
- **Play-mode camera is LOCKED** to the café — `screen_capture`'s camera
  arguments are ignored, so visual checks are limited to what that camera sees.

## 9. Exact command to continue

Open Claude Code in `C:\Users\barna\Desktop\roblox` and say `continue`, or paste
this file. **If the request is about mobile layout, ask for the screenshot first.**
