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
3. **Supply the HUD icons** listed in [docs/HUD_REDESIGN.md](HUD_REDESIGN.md) §4.

## ⚠️ Merged but NOT yet verified in-engine

Be honest about this with the owner — it is the biggest risk carried forward.

- **The 10-café world has never been run.** Geometry was verified by recomputing
  against the same formulas CafeService uses, not by playtesting.
- **`PedestrianService` has never executed once.** The lane math and café-entry
  path were proven with probe NPCs injected into a running session; the service
  itself has never started.
- **The `saveBlocked` path is not runtime-tested.** Reproducing it needs a store
  that exists but whose `GetAsync` fails.

First thing next session: reopen the rebuilt place, playtest, and verify these.

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
- **Counter depth under-fills** — body is 2.0 studs of its 4-stud footprint, so
  the espresso machine overhangs ~1.1 studs front and back. Needs a `deepen`
  companion to `widen`.

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
> **Copy the layout and interaction pattern, NOT the reference's art.** Every
> image must be an owner-approved Creator Store asset recorded in
> docs/ASSET_LICENSES.md — same rule docs/MENU_SPEC.md applies to Café World.
> Ask the owner for the icons listed in docs/HUD_REDESIGN.md §4 (Staff,
> Upgrades, Trophy, Map, Music, Settings) and prefer ONE cohesive pack; he has
> said he will supply them. He will also send a screenshot per menu panel later
> — panels are out of scope for this pass.
>
> **FIRST, though:** three things merged today have never actually run — the
> 10-café street, PedestrianService, and the saveBlocked path. Reopen the
> rebuilt SocialCafe.rbxlx, playtest, and verify the shorter street builds
> cleanly, the decor spacing looks right, and the ambient crowd stays on the
> pavement. Don't build on top of unverified ground.
>
> Keep StyLua+Selene+Rojo gates green, commit with conventional messages +
> CHANGELOG, open a PR and merge it once CI is green. Work in strict Luau,
> verify live via Roblox Studio MCP by MEASURING (screenshots cannot be posed
> during Play, and MCP cannot see the Studio ribbon — ask the owner for those),
> and never import copyrighted assets.
