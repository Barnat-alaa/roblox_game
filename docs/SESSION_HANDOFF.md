# Session handoff — 2026-07-22

Paste the "Prompt for the next session" block at the bottom into a fresh
session. Full project context is in [HANDOFF.md](../HANDOFF.md); what the game
*is* and where to take it is in
[docs/GAMEPLAY_DIRECTION.md](GAMEPLAY_DIRECTION.md).

`main` is green. **No open PRs.**

---

## 1. What shipped this session (2026-07-22)

Six PRs, all merged with CI green, all verified live in Studio by measurement.

| PR | What |
| --- | --- |
| [#10](https://github.com/Barnat-alaa/roblox_game/pull/10) | The chunky icon HUD — stat pills, centre dock, right rail — and 17 CC0 icons sourced and self-uploaded |
| [#11](https://github.com/Barnat-alaa/roblox_game/pull/11) | Catalogue rows show the real item, blurred while locked |
| [#12](https://github.com/Barnat-alaa/roblox_game/pull/12) | All 14 dishes get their own icon |
| [#13](https://github.com/Barnat-alaa/roblox_game/pull/13) | Furniture renders 1.5× bigger; round table is one cell; `deepen` added |
| [#14](https://github.com/Barnat-alaa/roblox_game/pull/14) | HUD rearranged (camera pad, health bars, tutorial card) + **the tutorial dead-end fixed** |
| [#15](https://github.com/Barnat-alaa/roblox_game/pull/15) | The last three button icons — the whole HUD is one style |

### The HUD

Bottom-left: **Money · Reputation · Buzz** as stacked pills whose values tween
(measured: 16 intermediate frames on a −15 purchase) with a 1.08 scale pop.
Bottom-centre: five chunky plates — **Build 1, Cookbook 2, Staff 3, Upgrades 4,
Shop 5** — that lift to 1.10 and fade their name in on hover, dip to 0.94 and
settle on press, and stay raised with a bright stroke while their panel is open.
Right edge: **Goals G, Trophies T, Map M, Music B, Settings V** as smaller round
plates with the key in a pill beside them. Music is a toggle and shows its state
through tint, not the raised treatment.

Both zones are one component, `Components.IconButton`. Every size, scale, tint
and motion value is in `Theme.Hud`; controllers hold no layout literals. One
`HUD_BUTTONS` table in `UIController` declares id, zone, order, key, badge,
label and accent together — controllers only attach behaviour via
`registerAction(id, callback)`. Buttons with no panel yet (Staff, Upgrades, Map,
Settings) raise a toast saying so rather than doing nothing.

Full spec and the measured acceptance table: [HUD_REDESIGN.md](HUD_REDESIGN.md).

### Item and dish art

Shop rows, build-placement rows, cookbook cards and pantry rows show **the real
item**. Furniture is rendered on demand by Roblox from the Creator Store model
we already ship (`Graphics.ItemThumbnail`); dishes have their own uploaded icon
(`Graphics.Dishes`, keyed by recipe id). Locked entries show that same picture
**heavily blurred** with the level requirement over it.

Coverage is complete: 20/20 furniture, 14/14 dishes, 13/13 HUD buttons, 3/3 stat
pills. Every id is recorded in [ASSET_LICENSES.md](ASSET_LICENSES.md).

### World scale

`AssetManifest.displayScale = 1.5` scales every placed piece from one number.
`table_round` is **1×1**, so the four adjacent cells are exactly the four chair
seats — measured at 4.00 studs centre-to-centre with a +0.07…+0.14 stud gap.

---

## 2. Hard-won facts — read before re-deriving them

These each cost real time to establish. They are not guesses.

**`rbxthumb` for `type=Asset` serves only 150×150 and 420×420.** Every other
size (48/60/75/100/110/128/140/160/180/250/256/352/512/720) is accepted as a
string and silently returns a **blank image**.

**Roblox has no GUI blur.** `BlurEffect` is a Lighting post-process on the 3D
world and does nothing to a `ScreenGui`. With no small thumbnail available to
upscale either, the locked-item blur is composited — the same picture drawn 14×
at small offsets. Measured cost: 20 blurred rows = 260 ImageLabels = 61 fps.

**Roblox does not fetch images it is not rendering.** A row scrolled out of view
reports `IsLoaded == false` forever. That is normal, not a fault — scroll it in
before concluding an asset is broken. First-ever requests also generate
server-side and took seconds, which is why `UIController` warms every catalogue
image with `PreloadAsync` on a background thread at join.

**Automatic production monopolises appliances.** `ProductionService` holds a job
on the appliance, so a player's manual `StartCook` answers `stove_busy`. This is
why the tutorial could not be completed, and it is worth knowing before
designing anything that asks the player to cook on demand.

**MCP's Luau context has its own module cache.** `require`ing `ServiceRegistry`
from `execute_luau` gets a fresh, empty registry — you cannot reach the running
singletons. Drive tests through remotes, exactly as a client would.

**Generated icon sheets are not transparent.** The checkerboard is painted in as
opaque pixels in two tones, with each icon's glow blended into it. A colour key
leaves a dirty halo; `scripts/slice_icon_sheet.py` un-mixes the background
instead and takes `--rows/--cols/--names`.

---

## 3. ⚠️ Owner actions still outstanding

1. **Dashboard Max Players → 10.** Not settable from code. The recorded setting
   is 30; leave it and 20 players per server join with no café.
2. **Create an Open Cloud API key** for `scripts/publish.ps1` — see HANDOFF §2a.
3. **Publish.** The cloud place still lags the repo — everything above is local.
4. **Decide the next feature.** [GAMEPLAY_DIRECTION.md](GAMEPLAY_DIRECTION.md)
   ranks seven; the recommendation is ingredients + rush hours, then regulars.

---

## 4. Verification state

- **The 10-café street and the ambient crowd: playtested and confirmed by the
  owner (2026-07-21).** Do not ask him to re-run it.
- **The HUD, item art and furniture scale: verified by measurement, not by eye**
  — zero overlapping elements in all three responsive modes, world visibility
  80.3% / 64.4% / 56.3% against 62 / 62 / 55% floors, every image `IsLoaded`,
  hover/press/active states read back off the instances.
- **The tutorial: run end to end, 1 → 2 → 3 → 6, no dead end.**
- **Still not runtime-tested: the `saveBlocked` path.** Reproducing it needs a
  store that exists but whose `GetAsync` fails, which cannot be forced from
  Studio. Correct by inspection only.
- **Never tested: two clients at once.** MCP cannot attach to the child
  processes a `Serveur et clients` test spawns, so visits, compliments and two
  cafés running simultaneously remain unverified.

---

## 5. Known gaps worth picking up

- **No ingredients exist.** The word is a coin cost with no representation. See
  GAMEPLAY_DIRECTION §1 — this is the owner's own top complaint.
- **The game automates away its own gameplay.** Staff remove the physical loop
  as you progress. GAMEPLAY_DIRECTION §3.
- **No session locking.** `saveAsync` does a blind last-writer-wins
  `UpdateAsync`; a server hop can roll a profile back. ProfileStore is the
  documented fix and matters more now that many small servers exist.
- **`BindToClose` waits a flat 3s** instead of waiting for saves to finish.
- **CustomerService walks customers down z = −14 / −46** — exactly the mailbox
  and hydrant lines. It is the only street-facing service not using
  `StreetMath`, and it hand-rolls `streetLength` a fourth time.
- **Offline earnings ignore producer capacity** — `capacityScale` uses Waiter
  only, so Barista/Cook can be at 0 and the claim still pays in full.
- **Offline window can be forfeited** — `onPlayerRemoving` stamps `lastSeenAt`
  unconditionally, even if settlement never ran that session.
- **SocialService compliment anti-farm is per-server, in-memory** — defeated by
  rejoining.
- **AnalyticsService is a log-only stub**, so none of the above is visible at
  scale.
- **The espresso machine is wider than the counter it stands on** (6.3 vs 3.9
  studs). That is the machine being a big model, not the counter being thin —
  shrink `coffee_machine.maxSpan` or raise the counter's `deepen`.
- **Three furniture pieces overhang by >2 studs** on their long side:
  `cake_display` +2.7, `coffee_machine` +2.9, `rug_round` +3.4. A rug is fine;
  the other two are the first to trim if the owner wants things tighter.
- **Two spare icons are unused** from the owner's sheet: a coin stack and a
  trophy-with-bar-chart (`Graphics.UI.Coins` / `.Rankings`). The second suits a
  street leaderboard.

---

## 6. Workflow reminders

Gates: `stylua --check src tests` + **unpiped** `selene src tests` + `rojo build`
of **both** `default.project.json` and `test.project.json`, with
`set -o pipefail`. CI is the honest gate.

Publish with `./scripts/publish.ps1` — **never** Studio's *Publier sur Roblox*,
which uploads whatever is open in Studio rather than what is on disk.

**Layout belongs in one place.** `ResponsiveLayout.hudLayout(mode, viewport)`
returns every HUD rectangle and six controllers read it (UI, Inventory,
Operations, Camera, Cooking, Tutorial). They each used to guess, which is
exactly how the tutorial card ended up on top of the stat pills. If you move
something, move it there, then re-run the overlap measurement.

**Phone sizing is tuned against a measured floor, not taste.** 560×365 lands at
56.3% world visible against a 55% floor. Growing the phone plates or pills in
`Theme.Hud` will break it.

Studio MCP notes: `screen_capture` only grabs the 3D viewport and cannot be
posed during Play (the camera controller overwrites a scripted camera every
frame); it never shows the Studio ribbon — ask the owner for those. Prefer
`execute_luau` measurement over screenshots for anything geometric. Relaunching
Studio repeatedly can trigger its recovery/start page — relaunch once per change
set. Owner runs a **French Studio UI**; give French click paths. Never run two
agents on this repo at once.

---

## Prompt for the next session

> Continue the Social Café game (repo at C:\Users\barna\Desktop\roblox). Read
> HANDOFF.md, then docs/SESSION_HANDOFF.md, then docs/GAMEPLAY_DIRECTION.md.
>
> **State:** `main` is green, no open PRs. The HUD, the item/dish art and the
> world scale were all rebuilt and verified on 2026-07-22 — do not redo them.
> Every buyable, placeable and cookable thing has real art; every HUD button is
> on the owner's own icon set. The tutorial runs end to end.
>
> **MAIN TASK — ask the owner which to build first, then build it.** The game's
> real weakness is diagnosed in docs/GAMEPLAY_DIRECTION.md: there are **no
> ingredients** (the word is a coin deduction with nothing behind it), and the
> game **automates away its own gameplay** — staff progressively remove every
> physical action, so the most engaged a player ever is, is their first twenty
> minutes. The recommended order is:
>   1. **Ingredients as a delivery you go and meet** — a supply van, crates you
>      unload, pantry shelves that visibly empty as cooking drains them, and
>      running dry as a real failure state. Hooks into the existing
>      `ingredientCost` path in KitchenService/ProductionService.
>   2. **Rush hours** — Buzz spikes for ~90s, staff capacity cannot cover it, so
>      the player works the floor by hand. An opportunity, never a punishment.
>   3. **Regulars** — named customers who return, have a favourite dish, and warm
>      to you the more you serve them personally.
>
> **Ethics rails are absolute** (HANDOFF §1): spoilage transparent and paused
> offline, no missed-day punishment, no loot boxes, no pay-to-win, no fake
> urgency, whitelisted communication only. Any design that breaks one is invalid.
>
> **Before you build anything that asks the player to cook on demand:** the
> automatic production loop holds a job on the appliance, so a manual `StartCook`
> answers `stove_busy`. That is what made the old tutorial impossible.
>
> Work in strict Luau on disk. Keep StyLua + Selene + both Rojo builds green with
> `set -o pipefail` and unpiped selene, commit with conventional messages +
> CHANGELOG entries, open a PR and merge once CI is green. Verify live via
> Roblox Studio MCP by **measuring** — screenshots cannot be posed during Play,
> MCP cannot reach the running singletons (drive tests through remotes), and it
> cannot see the Studio ribbon. Relaunch Studio once per change set, not per
> edit. Never import copyrighted assets; record every asset in
> docs/ASSET_LICENSES.md before it ships.
