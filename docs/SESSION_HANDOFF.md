# Session handoff — 2026-07-21

Paste the "Prompt for the next session" block below into a fresh session.
Full project context is in [HANDOFF.md](../HANDOFF.md).

## Where things stand

`main` is green and everything below is merged. **No open PRs.**

| PR | What |
| --- | --- |
| #3 | Kitchen layout verified in Studio; counter fills its footprint; espresso machine sits flush |
| #4 | Permanent ambient pedestrians walking the sidewalks |
| #5 | Persistence safety — a failed load no longer wipes the account |
| #6 | 10-café lobbies; surplus players queued instead of stranded |
| #7 | `scripts/publish.ps1` — one-command publish straight from local source |

### The lobby is now 10 cafés

`World.plotCount = 10`, `plotsPerRow = 5` (street 1248 → 408 studs). Scale comes
from Roblox spawning **more servers**, not bigger ones: total concurrent players
is unbounded, each street stays 10. `plotCount == plotsPerRow * 2` is asserted at
boot and covered by a spec — `plotOriginFor` wraps its column modulo
`plotsPerRow`, so a mismatch silently stacks two cafés on one origin.

### Persistence — how it actually works

The experience **is** published (see HANDOFF §2). `PlaceId = 0` in Studio only
means the local `.rbxlx` isn't linked to it; that misled a whole session.

| where | DataStore |
| --- | --- |
| Live server | `PROD_PlayerProfiles_v1` |
| Studio playtest / local file | `DEV_PlayerProfiles_v1` |

No attribute needs setting. Studio is pinned to DEV so a playtest can never
corrupt a real save.

**Offline earnings already exist and are complete** —
`CafeOperationsService:ResumeAfterOffline`:

```
earningSeconds   = min(now - lastSeenAt, 8h)      -- hard cap
effectiveMinutes = earningSeconds / 60 / 20       -- the 20x offline penalty
earnings         = netPerMinute * effectiveMinutes * waiterCapacityScale
```

Lands in `data.coins` via `EconomyService:AddCoins`, pushes `ProfileUpdated`, and
toasts "While away: +$X at 1/20 speed". `KNOWN_ISSUES.md` and `ROADMAP.md`
previously described this as unbuilt — corrected.

## ⚠️ Owner actions still outstanding

1. **Dashboard Max Players → 10.** Not settable from code. Recorded setting is
   30; leave it and 20 players per server join with no café.
2. **Create an Open Cloud API key** for `scripts/publish.ps1` — see HANDOFF §2a.
3. ~~Supply the HUD icons~~ — **done 2026-07-22**: sourced, licence-verified and
   self-uploaded by the agent (CC0 Nieobie + Kenney), recorded in
   [docs/ASSET_LICENSES.md](ASSET_LICENSES.md).
4. **Look at the new HUD and say what to tune.** It is measured and correct, but
   feel is yours to judge — plate size, how far the buttons lift, badge weight.
5. **Send a screenshot per menu panel** when you want the panels themselves
   restyled; that was deliberately out of scope for the HUD pass.

## The HUD was rebuilt (2026-07-22)

Bottom-left stat pills, a bottom-centre dock of five chunky icon buttons with
numbered shortcuts, and a right rail with letter shortcuts — full detail in
[docs/HUD_REDESIGN.md](HUD_REDESIGN.md), which now carries the measured results.

Two things to know before touching HUD layout again:

- **`ResponsiveLayout.hudLayout(mode, viewport)` owns every HUD rectangle.** Six
  controllers read it (UI, Inventory, Operations, Camera, Cooking, Tutorial).
  Before this, each guessed its own position, which is exactly why the tutorial
  card ended up on top of the stat pills and the camera pad under them. If you
  move something, move it there, then re-run the overlap measurement.
- **Phone sizing is tuned against a measured floor, not taste.** 560×365 lands at
  56.3% world visible against a 55% floor. Growing the phone plates or pills
  will break it; the numbers live in `Theme.Hud`.

## Verification state

- **The 10-café street and the ambient crowd: playtested and confirmed by the
  owner (2026-07-21).** Do not ask him to re-run it. Geometry had also been
  verified by recomputing against the same formulas CafeService uses
  (walkXBounds [-6, 414] inside the east wall at 418; road paving to 468 ≥ 408;
  2 trees at 210-stud spacing; 3 mailboxes / 2 hydrants).
- **Still not runtime-tested: the `saveBlocked` path.** Reproducing it needs a
  store that exists but whose `GetAsync` fails, which cannot be forced from
  Studio. Correct by inspection only — treat with care if you touch DataService.

## Known gaps worth picking up

From the 2026-07-21 audit (parallel readers + critic over the whole repo):

- **No session locking.** `saveAsync` does a blind last-writer-wins
  `UpdateAsync`; a server hop can roll a profile back. ProfileStore is the
  documented fix and matters more now that many small servers exist.
- **`BindToClose` waits a flat 3s** instead of waiting for saves to finish.
- **CustomerService walks customers down z = -14 / -46** — exactly the mailbox
  and hydrant lines. It is the only street-facing service that doesn't use
  `StreetMath`. It also hand-rolls `streetLength`, duplicating it a fourth time.
- **Offline earnings ignore producer capacity** — `capacityScale` uses Waiter
  only, so Barista/Cook can be at 0 and the claim still pays in full.
- **Offline window can be forfeited** — `onPlayerRemoving` stamps `lastSeenAt`
  unconditionally, even if settlement never ran that session.
- **SocialService compliment anti-farm is per-server, in-memory** — defeated by
  rejoining.
- **AnalyticsService is a log-only stub**, so none of the above is visible at scale.
- ~~**Counter depth under-fills**~~ — **fixed 2026-07-22.** `deepen` now exists as
  the companion to `widen`, and the counter body fills its cell depth (3.9 of 4
  studs). The espresso machine is still wider than the counter it stands on
  (6.3 vs 3.9 studs, so ~1.2 studs over each side) — that is the *machine* being
  a big model, not the counter being thin. Shrink `coffee_machine.maxSpan` or
  raise the counter's `deepen` if it bothers you.

## Workflow reminders

Gates: `stylua --check src tests` + unpiped `selene src tests` + `rojo build` of
**both** `default.project.json` and `test.project.json`. CI is the honest gate.

Publish with `./scripts/publish.ps1` — **never** Studio's *Publier sur Roblox*,
which uploads whatever is open in Studio rather than what is on disk.

Studio MCP notes: `screen_capture` only grabs the 3D viewport (never the ribbon
— ask the owner for a screenshot for any UI question), its `camera_position`
argument is ignored during Play, the game's camera controller overwrites a
scripted camera every frame, and MCP **cannot attach to the child processes** a
`Serveur et clients` multi-client test spawns. Prefer `execute_luau` measurement
over screenshots for anything geometric. Owner runs a **French Studio UI** —
give French click paths. Never run two agents on this repo at once.

---

## Prompt for the next session

> Continue the Social Café game (repo at C:\Users\barna\Desktop\roblox). Read
> HANDOFF.md, then docs/SESSION_HANDOFF.md, then docs/HUD_REDESIGN.md.
>
> **MAIN TASK: rebuild the HUD/menu.** The owner does not like the current one
> and supplied a screenshot of a successful Roblox restaurant tycoon as the
> reference for layout and feel. Full spec is in docs/HUD_REDESIGN.md — follow
> it. In short:
>   • bottom-LEFT: money, reputation and buzz as stacked pill chips with
>     circular icon discs, values animating rather than snapping;
>   • bottom-CENTRE: five chunky rounded-square icon buttons — Build, Cookbook,
>     Staff, Upgrades, Shop — with numbered badges 1-5, which lift and show
>     their NAME UNDERNEATH on hover and dip-then-settle on press ("pop");
>   • RIGHT edge: a vertical rail of smaller round buttons — Goals, Trophies,
>     Map, Music, Settings — each showing its single-key shortcut, same feel.
> Build it as a reusable `Components.IconButton` rather than inline in
> UIController, keep every colour/radius/motion value in Theme, and put image
> ids only in Graphics.UI.
>
> **SOURCE THE ICONS YOURSELF — do not wait for the owner to send them.** He
> has explicitly asked you to go and get them. The research is already done and
> licence-verified in docs/HUD_REDESIGN.md §4: use the **Nieobie Game Icon Pack**
> (CC0, github.com/Nieobie/Game-Icon-Pack, 800+ rounded icons from one artist —
> covers all 13 HUD icons with zero attribution) for the glyphs, and **Kenney UI
> Pack** (CC0, kenney.nl) for the rounded button plates behind them. For food/menu
> item icons use **Kenney Food Kit** (CC0) and render each 3D model to a flat 2D
> icon, so the cookbook icon and the object on the plate are the same asset.
> Re-confirm each licence page yourself before uploading, pin Nieobie by git
> commit hash, self-upload as Decals so the owner is the uploader, and record
> every id in docs/ASSET_LICENSES.md. §4.4 lists sources that are explicitly
> rejected (game-icons.net, OpenMoji, Noto, CraftPix, Lucide, the unverified
> Filwarka itch.io pack) — do not quietly reintroduce them.
>
> **Copy the layout and interaction pattern, NOT the reference's art** — same
> rule docs/MENU_SPEC.md applies to Café World. §4.5 explains why migrating off
> the current Simulator Icon Pack also retires a provenance risk: prefer
> replacing all 13 icons with Nieobie rather than mixing packs, because mixed
> corner radii are visible side by side in one toolbar. The owner will send a
> screenshot per menu panel later — panels are out of scope for this pass.
>
> Keep StyLua+Selene+Rojo gates green, commit with conventional messages +
> CHANGELOG, open a PR and merge it once CI is green. Work in strict Luau,
> verify live via Roblox Studio MCP by MEASURING (screenshots cannot be posed
> during Play, and MCP cannot see the Studio ribbon — ask the owner for those),
> and never import copyrighted assets.
