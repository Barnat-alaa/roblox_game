# Session handoff — Social Café City — 2026-08-05

_Authoritative pick-up doc. Read this top to bottom, then the docs it points to._

---

## 0. You are

Lead developer of **Social Café City**, a social café-management sim at
`C:\Users\barna\Desktop\roblox` (git, `main`, CI-green). Strict-Luau / Rojo /
Rokit / Wally, **server-authoritative**, **data-driven** (all tuning in
`src/shared/Config`). Published privately as DEV place `85898641225605`,
universe `10501568035`. You drive Roblox Studio through the **Studio MCP**.

## 0a. ⚠️ SEVEN MERGES ARE UNVERIFIED LIVE — run this first (2026-08-06)

The Studio MCP dropped mid-session and everything below shipped gates-green but
without a live pass. **Studio is already staged with `test-build.rbxlx` open.**

Root cause of the outage, for next time: two orphaned `StudioMCP.exe` processes
(started hours earlier) survived the disconnect and blocked a clean handshake, so
restarting Claude Code alone did not fix it. Kill every `StudioMCP.exe`, make
sure Studio has a PLACE OPEN (not the start page), then restart Claude Code.

Run the suite first (`§5.3`), then these in order:

| # | What | How to tell it worked |
| --- | --- | --- |
| 1 | Test suite | 117+ passed, 0 failed |
| 2 | HUD icons | pictures, NOT the letters BU/CB/CR/UP/SH/MK. The fallback now waits 15s and polls, and HUD art preloads before the catalogue |
| 3 | Intro card | says "Loading the street…", and when it lifts the trees and NPCs are ALREADY there (no pop-in) |
| 4 | Café name | a profile with a name shows "Welcome back to <name>", no text box |
| 5 | Welcome rush | 5 customers arrive ~3.5s apart on join |
| 6 | Café busy | 2+ diners present at level 1; they LINGER (~150s visit) rather than leaving after 7s |
| 7 | Multi-seat sets | `set_diner_four` seats 4 at once (proved once already, re-confirm after the visit-length change) |
| 8 | Furniture bounds | a counter at gridX=0 is REFUSED; the build ghost turns RED on bounds, overflow AND overlap |
| 9 | Put away | Build → tap a placed item → "PUT AWAY" returns it to inventory |
| 10 | Tutorial | step 2 is "Serve your first customer" and completes when Noah serves — 5 steps total |
| 11 | Economy | level-1 kitchen makes 40 servings/hr; no unservable arrivals; ~23% shortfall |
| 12 | Console | clean — no errors, 24 services, 24 controllers, 70 asset templates, 0 fell back |

**Perf item that has never been measured:** longer visits push peak concurrent
NPCs to roughly **90 per full server**. Needs a MicroProfiler pass on a low-end
phone before soft launch — it is the one real cost of the busy-café change.


## 1. Read first, in this order

1. **`HANDOFF.md` §1** — the ethics rails. ABSOLUTE: server-authoritative, no
   loot boxes, no pay-to-win (every Robux SKU also coin-earnable), no fake
   urgency, no free-text chat between players. §2a covers publishing.
2. **`docs/ECONOMY_ANALYSIS.md`** — the full economy model, a simulator, and the
   §8 fix list. **All twelve items are done**; the twelfth (§5.5) is built but
   dormant until the owner mints two product ids — see §4.
3. **`CHANGELOG.md` `[Unreleased]`** — every change with its verification notes.
4. `docs/GAMEPLAY_DIRECTION.md`, `docs/IMPLEMENTATION_MAP.md`,
   `docs/CORE_LOOP_SPEC.md`, `docs/MONETISATION.md`.

## 2. 📸 THE OWNER TESTS FROM THEIR PHONE — WAIT FOR SCREENSHOTS

Layout and feel work is driven by photos of their phone. **If the task is about
layout, ask for the screenshot before changing anything.** Guessing has cost
rounds. Read the shot carefully — several rounds were solvable purely from it.

## 3. THE OWNER IS ABOUT TO TEST. This is their checklist

Nothing below has been verified on a real device. In priority order:

1. **Do saves work?** Every test so far ran in Studio, which prints `DataStore
   unavailable — running IN-MEMORY`. Persistence has **never** been verified on
   a published place. Publish → play → leave → rejoin → is the café still there?
2. **Buy one of every product.** The IDs are real but no purchase has gone
   through end-to-end. A broken grant path takes real money and delivers
   nothing — it fails **silently**, which is why it is the top risk.
3. **MaxPlayers → 10** on the Creator Dashboard. Boot warns every time:
   `MaxPlayers (12) exceeds cafés (10)`.
4. **Two-player test** of steal / smell bomb / help-by-working. Every guard and
   every solo half is verified; what is untested is a genuinely different
   player. **The Studio MCP cannot do this** — it cannot attach to the child
   processes a multi-client test spawns.
5. **Is player chat on?** Roblox's chat window was visible in `PlayerGui` during
   testing. The rails say no free-text chat between players — confirm it is off
   in the published place's settings.
6. **Play an hour on a phone.** Twelve economy changes have landed unfelt.

## 4. Owner actions blocking further work

- **Create two Developer Products, then paste their ids.** Economy #11 is now
  **built and dormant** (`docs/ECONOMY_ANALYSIS.md` §5.5) — the code is done and
  verified; only the ids are missing, because a Product ID can only be minted on
  the dashboard.

  | Name | Price | Grants |
  | --- | --- | --- |
  | Double Shift — 1 Hour | 79 R$ | every producer delivers 2× for 60 min |
  | Instant Expansion | 199 R$ | the next café tier now |

  Then open `src/shared/Config/Products.luau`, find the two lines reading
  `productId = PENDING,` in `Products.timeProducts`, and replace `PENDING` with
  the matching id. That is the whole task — the cards, the grants and the two
  offer moments switch on by themselves. Until then both SKUs are hidden and no
  receipt can match them, so shipping as-is is safe.

  When you do turn them on, **glance at the two card icons** (⏳ and 🏠): the
  Roblox UI font has no glyph for some emoji (§5.6) and these two have not been
  seen rendered. If either shows a tofu box, swap `icon` in the same table.

- **Rename** `3612636928` → "Stock Pack +12" and `3612637043` → "Stock Pack
  +24". IDs and prices unchanged, but the native prompt shows the dashboard name
  and currently under-promises what it grants.
- **Icons** for all five products.
- **Upload Level artwork** — the only HUD icon with no image; that pill renders
  from the `"L"` glyph. `tests/Graphics.spec` excludes it by name; put it back
  when art exists.

## 5. TESTING SKILLS — read this before touching Studio

This is the hard-won part. Every item cost a round to learn.

### 5.1 The relaunch cycle

One `Stop-Process` of `RobloxStudioBeta`, `Start-Sleep 4`, `rojo build`, launch
the exe with the absolute place path, `Start-Sleep 34`, then
`list_roblox_studios` + `set_active_studio`. **Never `rojo build` the `.rbxlx`
while Studio holds it open.** Repeated force-kill relaunches can drop Studio on
its recovery page — minimise them.

### 5.2 `execute_luau` runs in an ISOLATED VM

You **cannot** `require` the running game's service singletons. You **can**:

- require anything under `ReplicatedStorage.Shared` (config, utilities) — this
  is how the whole economy was measured;
- require client modules under `PlayerScripts` — this is how every HUD rectangle
  was verified;
- drive the game through remotes (`RequestProfile:InvokeServer()`,
  `PlaceFurniture:FireServer{...}`);
- read the DataModel directly (positions, sizes, attributes, `.Enabled`).

**Instance paths use the real player name** (`game.Players.aloulouba1...`), not
`LocalPlayer`.

You **cannot** drive the running UI by requiring its controller. `require` in the
isolated VM builds a **second instance** with an empty action registry, so
`UIController.openAction("Upgrades")` leaves the real panel shut and you measure
an empty panel and believe it. Drive it the way a player does — the HUD hotkeys
(Build 1, Cookbook 2, Staff 3, Upgrades 4, Shop 5) via `user_keyboard_input`.
`VirtualInputManager:SendKeyEvent` is blocked here ("lacking capability
RobloxScript"). Requiring a controller is still fine for **pure module-load**
logic, and a server→client remote can be fired from `datamodel_type: "Server"`
(`Remotes.Notify:FireClient(plr, …)`) to test a client reaction without
reproducing its trigger.

You can also run the test place in a **second Studio instance** rather than
closing the owner's: build to a different filename, `Start-Process` the exe with
the absolute path, then `list_roblox_studios` + `set_active_studio` on the new
id, and kill only that PID afterwards to discard the in-memory patches.

### 5.3 Running the test suite

Build `test.project.json`, launch it, Play, then get totals in-process rather
than scraping the console:

```lua
local TestEZ = require(game.ReplicatedStorage.DevPackages.TestEZ)
local r = TestEZ.TestBootstrap:run({ game.ReplicatedStorage.Tests }, TestEZ.Reporters.TextReporterQuiet)
return string.format("%d passed, %d failed", r.successCount, r.failureCount)
```

Current state: **104 passed, 0 failed.** Keep it there.

### 5.4 Screenshotting the WORLD

- The intro overlay covers everything. Disable every `ScreenGui` in `PlayerGui`
  first.
- **The camera controller re-asserts `CFrame` every frame.** `RenderStepped` and
  `BindToRenderStep` at `Camera + 10` both lose. What works: create a **new**
  `Camera`, parent it to workspace, and set `workspace.CurrentCamera` to it —
  the controller still holds the old one and writes to a detached object.
- A leftover pin loop keeps overwriting a later camera; `:Destroy()` the probe
  camera to stop it.
- The server **teleports strays back to their own plot**, so you cannot walk to
  the map edge to photograph it.

### 5.5 Testing something the default profile cannot reach

Patch Studio's **in-memory** DataModel only — `ModuleScript.Source` in Edit
mode. Used this session to unlock all 14 recipes (`requiredLevel`,
`requiredReputation`) and to reseed `DataService`'s default profile.

- **Never on disk.** Verify with `git status` afterwards; the disk is the truth.
- Revert by closing Studio **without saving** — the `.rbxlx` is a build artifact.
- Use plain `string.find(s, needle, 1, true)` + `string.sub` splice. `gsub`
  treats the needle as a **pattern** and has silently failed here before.
- The same trick fast-forwards timers (a Config's `.Source`).

### 5.6 Traps that have bitten more than once

- **Lua locals must be defined ABOVE their callers.** Two red builds this
  session came from inserting helpers below the code that calls them. After
  moving a function, run `selene` before anything else.
- **CHECK CI BEFORE MERGING.** One PR was merged while its check read `fail`,
  breaking `main`. `gh pr checks <branch>` must say **pass**.
- **A Roblox part is capped at 2048 studs per axis and clamps SILENTLY.** The
  sea was declared 8000 wide for months and was really a 2048 square.
- **`Model:GetBoundingBox()` returns PIVOT-oriented extents**, not world-axis
  ones — it cannot detect world rotation. Project the 8 corners instead.
- **`math.clamp` errors when max < min.** Guard any clamp whose bounds come from
  layout.
- **`AbsolutePosition` is offset by the GUI inset** for `DeviceSafeInsets`
  ScreenGuis — an element at y=4 reads as `-54`. Compare like with like.
- **Assert on every programmatic edit.** A silent no-op replace once shipped a
  missing config key and Studio errored at runtime.
- **The Roblox UI font has no glyph** for 🪙 (U+1FA99), 🫳, 🏆, 🥇🥈🥉 — they
  render as tofu. Draw them from Frames (see `UI/StylePreview`).

### 5.7 Gates (identical to CI)

`stylua --check .` + `selene .` (**unpiped**) + `rojo build` of **both**
`default.project.json` and `test.project.json`. Branch off `main`, one
deliverable per PR, co-author to `Claude <noreply@anthropic.com>`. **Never merge
unverified core-loop code.**

## 6. What shipped this session (PRs #70–#85)

| Area | Change |
| --- | --- |
| World | Wall shelves wrap onto the back wall instead of standing in the garden · café walls stay solid from the garden · beach shoreline, tiled open sea, sun on the water · café name on a hanging wooden board |
| Economy | **Full analysis + simulator** (`tools/economy_sim.py`), then fixes #1–#10 and #12 |
| Intro | Live blurred world behind the naming card |
| Tests | Suite green for the first time — 89 passed, 0 failed |

The economy fixes, one line each:

- **#1** the production forecast modelled a **disabled** scheduler — 12–32×
  optimistic, ingredients up to 62% understated. Rewritten against the plan.
- **#2** capacity audited: LIVE for Waiter/Cleaner, work-minutes for producers.
- **#3** satisfaction kept (owner's call), documented as presentational.
- **#4** demand capped to what the kitchen can deliver — angry walkouts over 60h
  fell **2,201 → 752**.
- **#5** Buzz decays, so it measures throughput. Ceiling **31 → 78** of 105.
- **#6** recipes re-tiered: a level-1 dish beat six later ones. Endgame income
  **389 → 806/h**.
- **#7** **buy a bigger café** — the missing coin sink; the game used to end at
  hour 20 with coins piling up and nothing to buy.
- **#8** session gifts **338 → 110/h**, so playing beats idling (50% → 16% of
  income).
- **#9** stock packs +5/+12/+24 — the top pack is now 41% better per Robux.
- **#10** pack coin prices 5× market value → **2.2×**.
- **#12** contextual offers at three real moments, rate-limited, with a
  first-class **NOT NOW**.

## 7. Known-open, in priority order

1. ~~**Economy #11**~~ — **built 2026-08-05 and dormant.** Nothing left to code;
   it needs the two product ids from §4 and turns itself on. `ECONOMY_ANALYSIS`
   §8 is now fully closed.
2. **B5 garden items** — unblocked now that expansion exists (buying land is
   exactly what makes the garden placeable). **This is the top open item.**
3. **The HUD shows behind the intro card.** Cosmetic. The overlay is at
   `DisplayOrder 200` so the tint dims it, but hiding those ScreenGuis outright
   never took effect (`HUD.Enabled` stayed true). Needs a proper diagnosis, not
   another guess.
4. **Offline settlement still models producers spending capacity** — a rule the
   online game no longer uses (`docs/ECONOMY_ANALYSIS.md` §2.3).
5. **M3** — the "Name your café" prompt is a world `ProximityPrompt`, so Roblox
   renders it dead-centre. Needs a custom prompt style.

## 8. Exact command to continue

Open Claude Code in `C:\Users\barna\Desktop\roblox` and say `continue`, or paste
this file. **If the request is about mobile layout, ask for the screenshot
first.** If the owner has created the two products, start with economy #11.
