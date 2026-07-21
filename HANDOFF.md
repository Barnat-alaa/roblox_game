# PROJECT HANDOFF — Social Café City (working title)

_Last updated: 2026-07-19. This is the single source of truth for picking the
project up — by the owner, a new developer, or a fresh AI session. Read this
before touching anything._

---

## 1. What this project is

A **Roblox café-management social sim**: every player owns a café on a shared
two-row boulevard (**10 plots/server** since 2026-07-21 — scale comes from
Roblox spawning more servers, not bigger ones), cooks dishes ahead of time on
stoves,
keeps counters stocked while chibi customers queue, sit, eat and tip, grows a
**Buzz** rating that drives customer flow, masters recipes for stars, chases
daily goals and streak trophies, and visits neighbours' cafés.

**Design north star:** evoke the *feeling* of the classic Facebook café sims
(cook-ahead planning, counters full of food, decor as status, a street of
neighbours) through **original mechanics and 100% original procedural art —
never copied assets**. This is both the creative identity and the legal
strategy (see `docs/ART_DIRECTION.md` and `docs/ASSET_LICENSES.md`; the rule
is absolute: analyse references into abstract principles, rebuild originally;
discontinued games are still copyrighted).

**Ethics rails (owner-approved, from the master plan):** spoilage is transparent,
controllable, and pauses completely while offline; there is no missed-day
punishment. No loot boxes, pay-to-win, fake urgency, or free-text between
players (whitelisted compliments only).

## 2. Where everything lives

| Thing | Location |
| --- | --- |
| Repo (public) | <https://github.com/Barnat-alaa/roblox_game> (branch `main`) |
| Local checkout | `C:\Users\barna\Desktop\roblox` |
| Published experience | **Social Cafe DEV** — universeId `10501568035`, placeId `85898641225605`, **Private**, API Services **ON**. ⚠️ Max Players must be **10** to match `World.plotCount` (2026-07-21) |
| Place file (built artifact, gitignored) | `SocialCafe.rbxlx` — rebuild any time with `rojo build --output SocialCafe.rbxlx` |
| **Publishing** | `./scripts/publish.ps1` — gates + build + Open Cloud upload, straight from `src/`. See §2a. |

### 2a. Publishing (always ships the LOCAL source)

```powershell
$env:ROBLOX_API_KEY = "<Open Cloud key>"   # once per shell
./scripts/publish.ps1
```

Do **not** publish from Studio's *Fichier → Publier sur Roblox*: that uploads
whatever is currently OPEN in Studio, which is not necessarily what is on disk.
Forget to reopen the rebuilt `SocialCafe.rbxlx` first and you silently ship
stale scripts — this has already caused confusion once. `publish.ps1` builds
from `src/` and uploads that, so published == local, always.

Create the key at <https://create.roblox.com/dashboard/credentials> with the
**universe-places** system, this universe selected, and the **write** scope.
Never commit it (`.gitignore` already covers `.env` / `*.key`).

**DataStore environments** (`DataService.environmentPrefix`), so a playtest can
never corrupt a real player's save:

| where | store |
| --- | --- |
| Live server on the published place | `PROD_PlayerProfiles_v1` |
| Studio playtest (any place) | `DEV_PlayerProfiles_v1` |
| Unpublished / local `.rbxlx` (PlaceId 0) | `DEV_PlayerProfiles_v1` |

No setup needed — live is PROD by default. Only set an `Environment` string
attribute on the place if you want to override (e.g. `"STAGING"`, or `"DEV"` on
a secondary dev place once a separate production place exists, so the two don't
share the PROD store).
| Docs | `docs/` (+ `ROADMAP.md`, `CHANGELOG.md`, `KNOWN_ISSUES.md`, `CURRENT_STATUS.md`) |

**Toolchain (installed & pinned):** Rojo 7.4.4 · Rokit 1.2.0 · StyLua 2.0.2 ·
Selene 0.27.1 · Wally 0.3.2 (TestEZ dev-dep) · gh CLI (authed as Barnat-alaa).
CI: GitHub Actions — StyLua → Selene → wally install → Rojo builds of BOTH
`default.project.json` and `test.project.json`. **CI is the honest gate**;
run local gates with `set -o pipefail` and *unpiped* selene (a piped selene
once masked a real error — see commit `c80b17b`).

## 3. Architecture (all strict Luau)

```
src/shared/   Config (Economy, Recipes×14, Furniture×9, Customers, Kitchen,
              Goals, World, Audio, Tutorial, Progression, Staff), Types,
              Network/Remotes (name registry), Utilities (Grid, Mastery,
              RewardMath, RateLimiter, Log)
src/server/   Main + ServiceRegistry (two-phase Init/Start over Services/)
              Services: Data, Economy, Cafe, Build, Order, Customer, Kitchen,
              Recipe, Progression, Goal, Staff, Social, Analytics, Monetization(stub)
              Fx.luau (module, not a service): coin bursts + floating text
src/client/   Main + Controllers/: UI (compact HUD/shop/toasts/level-up),
              Inventory (active-stock pill + pantry/production drawer), Build,
              Camera (fixed ¾ café-sim cam + touch controls), Cooking (brew
              minigame), Kitchen (cook/collect prompts + picker), Cookbook,
              Goals, Interaction (visits/compliments), Tutorial, Audio
tests/        TestEZ specs (RewardMath, Grid, Progression, Mastery) + RunTests
              bootstrap (only in the test place)
```

**Iron rules already enforced — keep them:**
- Server authority for every grant. The client's opinion is never trusted
  (e.g. `ClaimOrder`'s manualCook arg is ignored; brew timing is re-derived
  from the server clock; tips validate the claimer).
- Every remote: type/range/ownership/rate/distance validation
  (audit table in `docs/SECURITY.md`).
- Config-driven everything; `Types.PlayerData` is the schema — heal nested
  shapes on read (see `kitchenOf`, `dailyOf`) because reconcile only fills
  top-level keys.
- Wall-clock (`os.time`) for cook timers so overnight cooking works.
- StyLua/Selene clean before any push; conventional CHANGELOG entries.

## 4. What is DONE and how it was verified

**MVP (all 15 criteria)** — join → own café → grid build (place/rotate,
server-validated) → brew minigame → serve → earn coins/rep/XP → shop →
**real DataStore persistence verified end-to-end** (place → leave → rejoin)
→ visits → tutorial (server-owned, strictly ordered) → published private.

**Idle/tycoon kitchen loop:** placed appliances continuously produce enabled
menu products toward player-set stock targets. Baristas/cooks gate production,
waiters cap service throughput, FIFO lots spoil only while online, and the
always-visible inventory rail exposes stock, incoming batches, freshness, and
bottlenecks. The 8h Overnight Roast remains the appointment batch.

**Compact tycoon UI:** the permanent screen footprint is one resource capsule,
one dynamic 226–344px active-stock pill, a contextual order ticket, and a
collapsed action menu. Landscape phones/short windows open 41–44% edge drawers;
desktop drawers preserve at least 62% world visibility. All full panels share
`CafeModals` at DisplayOrder 20. `Theme.Images` intentionally stays blank until
the owner approves specific Creator Store icon assets.

**Phase 2 — alive café:** customers queue (3-deep line), walk with a chibi
waddle, **sit on your placed chairs** (verified at the exact grid cell), eat
from plates, leave **collectible tips** (owner-only prompt), dirty plates,
coin-burst + float-text juice, food stacks visible on counters, striped
awnings + interior glow, 8 procedural customer styles with name tags.

**Phase 3a — progression:** recipe **mastery stars** (5/15/40/100 cooks →
−time/−cost/+serving/fresh-boost; pure `Mastery` module, 8/8 spec),
**Cookbook UI** (live numbers, stars, locked silhouettes), 14-recipe ladder
to Lv 9, level-up celebration. *Verified live + spec.*

**Phase 3b — retention:** **daily goals** (3/day, coin rewards, hooks across
5 services), **streak + permanent trophy shelf** rendered in-café,
**staff crew of three** (Mia barista rescue, Noah waiter tray-delivery, Pia
cleaner → +1 Buzz per plate). *Gates green; **live playtest still owed** —
see §6.*

**Platform/infra:** 30-plot two-row boulevard with plaza + closed-café
shutters (unowned cafés visibly CLOSED, open on claim), golden-hour lighting,
licensed audio (ProSoundEffects/DistroKid only — logged), mobile camera
buttons + pinch zoom, security audit of all remotes, zero-gap duplicate-claim
race verified closed, TestEZ runner place, spawn-in-front-of-your-café.

## 5. Known quirks a newcomer MUST know

1. **Two Studio doc types.** The window titled **"Social Cafe DEV"** is bound
   to the cloud place (publishing target). Windows titled `SocialCafe.rbxlx`
   are disposable file instances for testing. NEVER rebuild the rbxlx while a
   file instance holds its lock — kill the instance first
   (`Get-Process | ? MainWindowTitle -like "*SocialCafe.rbxlx*" | Stop-Process`).
2. **The cloud place lags the repo** until someone opens a current place and
   publishes with **Alt+P → "Mettre à jour l'expérience existante…" →
   Social Cafe DEV**. The repo is ALWAYS the source of truth.
3. **Studio start-page quirk:** double-clicking the rbxlx sometimes opens
   Studio's start page with no file. Reopen from the start page's Recent list.
4. **MCP execute_luau has an isolated module cache** — you cannot `require`
   the running game's singletons; drive live tests through remotes/instances.
5. **Owner's machine runs other AI agents sometimes** (Codex on CritterClash).
   Don't fight for Studio/desktop focus; coordinate via the owner.
6. Owner works in **French Studio UI**; give French labels for click paths.
7. Two agents/sessions must not drive Roblox Studio MCP simultaneously.

## 6. WHAT STILL NEEDS TO BE DONE

> **2026-07-15 priority change (owner review):** the build order is now the
> **5-step session roadmap** at the top of ROADMAP.md (S1 asset/graphics
> pipeline → S2 customer feelings → S3 preparation/menu → S4 customisation/
> expansion → S5 social city), built from the full original-game feature map
> in `docs/CAFE_WORLD_PARITY.md` with graphics from
> `docs/ASSET_SHOPPING_LIST.md`. The "Immediate" items below ride along
> (publish after S1; two-client + mobile passes ride S5/S2). Creator Store
> assets are now allowed under the ART_DIRECTION 2026-07-15 addendum.

### Immediate (blocking release-quality confidence)
1. **Owner playtest of Phase 3b** (goals tick + pay, crew of three visible,
   Noah delivers tray, Pia clears plates for +Buzz) — my test instance hit
   quirk §5.3, so 3b never had a live pass. Fix anything that feels wrong.
2. **Publish repo → cloud place** (Alt+P update-existing; 30 seconds).
3. **Two-client test** (Studio: Test tab → 2 players): visits, compliments
   (+2 rep, once/visitor), two cafés running simultaneously, plot
   assign/release with shutters.
4. **Device-emulator mobile pass** (phone viewport: HUD fits, camera buttons,
   brew panel cap, cook picker, goals/cookbook panels; touch targets ≥44px).
5. **Icon + thumbnail**: raw staged screenshots exist at
   `scratchpad/thumb_raw.png` + `icon_raw.png` (session scratchpad — retake
   if gone: boulevard wide shot + café close-up). Crop/letterbox → upload on
   the dashboard (paths in `docs/RELEASE_ASSETS.md`).
6. **Content-maturity questionnaire** on the dashboard — answer key ready in
   `docs/RELEASE_ASSETS.md` (everything "None"; no free text).
7. **Tag `v0.1.0-mvp`** + run `docs/RELEASE_CHECKLIST.md`, triage
   `KNOWN_ISSUES.md`.

### Phase 4 — the social city (next build phase, per ROADMAP.md)
- Help-a-neighbour tap (stir their pot: +cook progress for them, coins for
  you; once per café per day; fully whitelisted).
- **Street Buzz leaderboard** on the plaza board (lobby ranking).
- Daily ingredient **gift crate** to another player (predefined, no trading).
- Café **name signs** from a curated word list; photo spot.
- Weekly lobby goal ("serve 500 together") → street decoration unlock.

### Phase 5 — retention/LiveOps
Seasonal dish collections; first plaza Food Festival event; analytics-driven
tuning (wire funnels to real Roblox AnalyticsService — currently events only
log to console via our AnalyticsService stub — needs the published place +
`docs/ANALYTICS_EVENTS.md` mapping).

### Phase 6 — monetisation + hardening (only after the loop is proven fun)
Cosmetics only (themes/uniforms/signs) + one honest pass; idempotent
`ProcessReceipt`; **ProfileStore swap** for session locking (dupe risk until
then — public API in DataService was designed for the swap); MicroProfiler
pass at 30 concurrent; low-end device matrix; staging + production
experiences with `STAGING_/PROD_` datastore prefixes; Open Cloud CI publish.

### Phase 7 — alpha → soft launch
Testers, drop-off fixes, economy rebalance from data, **the real game name**
(distinctive + trademark-clear; candidates tracked in ROADMAP), production
release + rollback procedure.

### Debt / nice-to-haves (tracked, not urgent)
- Tutorial step for the NEW loop (current tutorial predates cook-ahead; step
  2 says "press E and stop the bar" — should become cook→collect).
- Serve-distance check is plot-radius, not counter-point.
- `RequestProfile` RemoteFunction lacks a rate limit.
- Old `preparationTime`/`baseQuality` recipe fields are unused — prune or use.
- Barista/waiter/cleaner are free — hiring/wages when economy matures.
- Rojo plugin live-sync (owner installs plugin → `rojo serve`) would remove
  the rebuild/relaunch loop entirely.
- Gingham/wood generated textures; interior wall/floor palette customisation.

## 7. How to continue (exact)

**Owner, each session:** open Claude Code in the repo → say `continue` (or
name a phase). Playtest builds by double-clicking `SocialCafe.rbxlx` (see
quirk §5.3), report feelings/screenshots. Publish to cloud with Alt+P →
update existing.

**Fresh AI session bootstrap prompt (paste as-is):**

> You are the lead developer of the Roblox game in this repo (see HANDOFF.md
> — read it first, then ROADMAP.md and KNOWN_ISSUES.md). Work autonomously:
> code in strict Luau on disk, keep StyLua+Selene+Rojo gates green with
> `set -o pipefail` and unpiped selene, commit with conventional messages +
> CHANGELOG entries, push to origin main, and verify CI with `gh run list`.
> Test live via Roblox Studio MCP: kill any `SocialCafe.rbxlx` Studio
> instance, `rojo build --output SocialCafe.rbxlx`, launch it, set it active,
> playtest through remotes (the MCP Luau context cannot require running
> singletons). Never touch the "Social Cafe DEV" bound window except to
> publish, never run alongside another agent using Studio, and never import
> or imitate copyrighted assets — all art is original procedural work per
> docs/ART_DIRECTION.md. Current priority order: §6 "Immediate" items in
> HANDOFF.md, then Phase 4.

---

*Everything above was built solo in ~3 days by owner + AI pair. 20+ green
commits, one red CI (caught, fixed, process hardened). The loop is fun-shaped;
now make it undeniable.*
