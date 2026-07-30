# Session handoff — Social Café City — 2026-07-28

_Authoritative pick-up doc (supersedes prior handoffs). Written for a fresh AI
session or a new developer taking over. This is the "start here" prompt — read it
top to bottom, then the docs it points to._

---

## 0. You are

A senior Roblox dev continuing **Social Café City**, a social café-management sim
at `C:\Users\barna\Desktop\roblox` (git repo, `main`, CI-green). Strict-Luau /
Rojo / Rokit / Wally, **server-authoritative**, **data-driven** (all tuning in
`src/shared/Config`). Published privately (DEV place `85898641225605`,
universeId `10501568035`). You drive Roblox Studio via the **Studio MCP**.

## 1. Read first (in order)

- **`HANDOFF.md` §1 (ethics rails — ABSOLUTE)** + §2 (where everything lives +
  publishing).
- `docs/GAMEPLAY_DIRECTION.md` (what/why), `docs/IMPLEMENTATION_MAP.md` (exact
  code hooks per feature), `docs/CORE_LOOP_SPEC.md` (recipe/production balance),
  `docs/MONETISATION.md`.
- `ROADMAP.md` → **"⭐ NEXT — owner priorities (2026-07-28)"** (the ordered to-do)
  and "ACTIVE BUILD — Direction phases A–D" (context).
- `CHANGELOG.md` `[Unreleased]` — every change this session, with rationale.

## 2. State (2026-07-26) — everything below is MERGED to `main`, CI-green

Shipped this session (PRs #30–#35, all merged):

| PR | What |
| --- | --- |
| #30 | **Production balance** — per-serving margins fixed to 42–58% (were 0% on the cheapest); `tests/Recipes.spec` invariant guards it |
| #31 | **Auto-collect + wall food shelves** — finished manual cooks auto-collect (`Kitchen.autoCollectCooks`); per-recipe wall shelves (`Kitchen.useFoodShelves`) |
| #32 | **Phase B — brainrot VIP + earned gift box** — Creator Store asset `112586636995159`; `VipService`, `Config/Vip`, `Config/Gifts`, `RewardMath.rollGift` |
| #33 | **Shelf rework** — bigger shelves + props/labels; order pickup moved from the counter to each recipe's wall shelf |
| #34 | **VIP rework + lobby Buzz leaderboard** — VIP enters, orders the fanciest dish, instant serve; `LeaderboardService` ranks cafés by Buzz on the plaza board |
| #35 | **Phase C 4a — neighbour help + friendships** — `NeighbourHelp` remote, `HELP_ACTIONS`, `PlayerData.social` |

**Phase status:** A ✅ · B ✅ · C-4a ✅ · C-4b ✅ · D ✅.

Also shipped this session (all merged to `main`, CI-green — see `CHANGELOG.md`):

| PR | What |
| --- | --- |
| #37 | **3 owner bugs** — seating leak (derive occupancy from live diners), VIP-as-customer (via `CustomerService:SpawnVip`), session + 15-min playtime gift with a HUD countdown pill |
| #38 | **Phase C-4b mischief** — smell bomb + recruit lure, all guardrails (`MischiefService`, `CustomerService:LureOne`) |
| #39 | **Phase D monetisation** — boost-timer HUD pill, VIP perks wired (+50% gift, faster walk, 👑 sign badge), Auto-Collect pass removed |
| #40 | **World aesthetics** — natural sky+sun, sea+grass island, more trees, upside-down-sign fix, **spawn-on-wall fix**, cozier 72×72 café |
| #41 | **Player-named cafés** — typed name, `TextService`-filtered, on the sign (`SetCafeName`, `CafeNameController`) |
| #42 | **docs** — session handoff update |
| #43 | **Intro/onboarding + advanced sky + health strip** — first-run naming overlay masking the load (`IntroController`, `WorldReady` remote, controls frozen, reveals in front of café); dropped the fake cloud-wall backdrop for `Sky` + `Atmosphere` + **volumetric Terrain `Clouds`**; café-health redesigned to 4 slim pills at the extreme top-centre (`OperationsController`, `ResponsiveLayout`) |

**➡️ NEXT WORK: see `ROADMAP.md` → "⭐ NEXT — owner priorities (2026-07-28)".**
That section is the ordered to-do (P1 grass-under-road bug → P2 the 3 real
neighbour actions → P3 VIP timer event → P4 monetisation into Upgrades +
sell-multiplier SKUs), each with code hooks. Build one deliverable per PR.

Still owed (carry-over): **PUBLISH** (owner runs `scripts/publish.ps1`); a live
Robux purchase test (IDs are real); the 2-player mischief-lure + neighbour-help
playtest; the owner's eyeball on the new Clouds sky/sea (tweak in
`CafeService.applyLighting`/`buildGroundAndSea`); VIP name-colour; café-**style**
picker in the intro panel; café **width** reduction (kept at 72 studs); ProfileStore
swap (Phase 6); the pre-existing `Graphics.spec` failure (Coin/Coins glyph).

⚠️ **NOT PUBLISHED.** All 7 merged features are in `main` but **NOT live** in the
DEV place. Publish with `./scripts/publish.ps1` — it needs `$env:ROBLOX_API_KEY`
(the owner's Open Cloud key). The **owner runs it or provides the key**; an agent
must NOT enter/handle the key in plaintext. See `HANDOFF.md` §2a.

---

## 3. 🐞 BUGS THE OWNER FOUND (2026-07-26) — ✅ ALL THREE FIXED (branch `fix/owner-bugs-seating-vip-session`, verified live in Studio)

> **Status 2026-07-26:** all three fixed end-to-end and Studio-verified (clean
> boot, no errors; connect + playtime gifts fired with the HUD countdown pill; a
> customer AND the VIP both sat in placed chairs; the VIP ordered → waited →
> was served → dropped its gift box; a third customer was rejected only when both
> chairs were genuinely held). See `CHANGELOG.md [Unreleased]` top entry. Details
> below kept for reference.

### Bug 1 — Session gift + 15-minute playtime gift with a visible counter
A gift should appear **once when the player connects**, and **another after they
stay connected 15 minutes**, with a **clearly-shown countdown timer** ("compteur")
on the HUD. This is a NEW retention feature (there is no login/session-gift system
today; the VIP gift box is unrelated — it drops when a VIP visits).
- Build: a new server service tracking each player's session connect-time + a HUD
  countdown; grant the gift on connect and again at the 15-min mark; show the
  ticking timer.
- Look at `GoalService` / the `daily` state + `RewardMath.rollGift` / `Config/Gifts`
  for reward patterns; the HUD countdown mirrors the boost-timer pill idea in
  `docs/MONETISATION.md` ("2× Coins — 43:12 left"). Rails: earned by play, not
  paid, no fake urgency.

### Bug 2 — Brainrot VIP must behave like a normal customer
Right now the VIP walks in and is **served instantly** (`VipService`, a standalone
path). The owner wants it to act like a real customer: **enter → find & SIT in an
empty chair (if one is free) → order a RARE item (a fancy dish, NOT coffee/tea) →
WAIT to be served** (owner or waiter serves it), then leave the earned gift box.
- Hooks: `CustomerService` owns the customer lifecycle (spawn → walk to a seat →
  order → wait → served → leave) and seating. `VipService` currently does the
  standalone instant path (tuning in `Config/Vip`).
- Cleanest approach: spawn the VIP THROUGH `CustomerService` as a special customer
  (VIP flag + forced RARE recipe + the brainrot rig from `AssetLibraryService:GetVip`),
  reusing its seating/order/serve flow, instead of the standalone instant-serve
  path. Keep the leaderboard targeting (#1 by Buzz), the entrance walk, and the
  earned gift box on leave.
- "Rare item, not coffee/tea": pick a high-tier non-Coffee/Tea recipe the café has
  unlocked (`Config/Recipes` has `category` + `basePrice`).

### Bug 3 — Customers wait even when chairs are empty
Some customers enter and keep waiting/standing even though there ARE free chairs.
Seating bug in `CustomerService` — the seat-assignment / chair-availability scan
isn't picking up empty chairs (candidates: stale seat state, a seat reservation
never released, or the scan missing newly-placed chairs). Fix so a waiting
customer takes any genuinely-free chair; verify seated dining end-to-end.

---

## 4. Also open (from earlier this session)

- **Phase C 4b — mischief ✅ SHIPPED** (branch `feat/mischief-4b`, Studio-verified
  solo). Smell Bomb (coin-bought consumable → guaranteed pull, big green
  `Fx.smellVapour` telegraph) + Recruit (free, reputation-scaled), both on the
  neighbour visit card, both routed through the new `MischiefService` (one
  `Mischief` remote). ALL guardrails enforced: cooldown, proximity, not-yet-served
  / un-seated / non-VIP only (VIPs resist), per-customer immunity + per-victim
  max-stolen cap, visible vapour, no permanent loss (victim's customer leaves
  calmly, re-appears at the caster via `CustomerService:LureOne`). New
  `PlayerData.smellBombs`; ships behind `Config/Mischief.enabled`. **Still owed: a
  2-player playtest of the actual cross-café lure** (solo can't — same as 4a; the
  buy path + guard ladder + vapour ARE verified live).
- **2-player playtest of 4a** — the helper→online-neighbour reward/friendship path
  + the once-per-neighbour-per-day cap. A single client can't test it (the remote/
  guard path IS verified live: firing `NeighbourHelp` at your own plot returns the
  self-block). Needs Studio 2-client or two real players.
- **Live shelf-pickup playtest** — confirm the owner picking a dish off its wall
  shelf → carrying → delivering → paid feels right. Only verified structurally
  (idle-test Buzz was ~0, so no live customers ordered).
- **Brainrot scale/offset** — tune `Config/Vip.modelHeight` / `hipHeight` /
  `rigYOffset` by eye in a playtest.
- **`tests/Graphics.spec` failure (pre-existing).** "defines a non-empty image for
  every persistent HUD icon" fails: `Config/Graphics.luau` `UI` has `Coins` but the
  test expects `Coin` (and a `Level` icon looks missing). CI only builds (it does
  NOT run TestEZ), so it never caught it. Fix the key mismatch + add the missing
  icon(s). This is the "1 failed / 87 passed" in every Studio TestEZ run —
  unrelated to any feature.
- **Friendship reward ladder (4a follow-up)** — friendship points accumulate +
  persist (`PlayerData.social.friendship`), but there's no reward ladder yet
  (daily rewards / exclusive decor from friendship levels).
- **Auto-Collect gamepass overlap** — auto-collect is now free for everyone, so the
  Auto-Collect gamepass (`Config/Products`, R$149) is redundant; repurpose it in
  the Phase D monetisation pass.
- **MaxPlayers = 10** on the Creator Dashboard (owner action; boot warns
  MaxPlayers 12 > 10 plots).

---

## 5. Working rules (the owner expects these)

- **Senior dev team loop:** understand → build cleanly → **TEST IN ROBLOX STUDIO**
  → commit → open PR → wait CI green → merge. **Never merge unverified core-loop
  code.** Run an adversarial review for risky changes.
- **Every gate (this IS the CI):** `stylua .` + `selene .` (unpiped) +
  `rojo build default.project.json` + `rojo build test.project.json`. House style:
  tabs, `--!strict`, plain-table services with `Init`/`Start`, data-driven config,
  no hardcoded values in logic. Add new remotes to the `EVENTS` list in
  `Remotes.luau`; validate every payload server-side; new persisted state should be
  a **top-level** `PlayerData` field (so `reconcile` heals old saves) + a heal
  helper for nested shapes (see `SocialService.socialOf`, `KitchenService.kitchenOf`).
- **Ship risky/core changes behind a config flag first**, test with it on, then
  flip live (`Kitchen.enforceIngredients` / `useProductionPlan` / `autoCollectCooks`
  / `useFoodShelves`; `Vip.enabled`).
- **Ethics rails (ABSOLUTE — `HANDOFF.md` §1):** server-authoritative; no loot
  boxes; no pay-to-win (every Robux SKU also coin/level-earnable); no fake urgency;
  no free-text chat (whitelisted compliments/help actions only). §4b mischief is
  the ONE rails-brushing mechanic — the owner has signed off, but ONLY with the
  guardrails in §4 above.

## 6. Studio workflow (the owner authorised driving Studio directly)

- **Close:** a SINGLE `Stop-Process` of `RobloxStudio*`, then `Start-Sleep 3`.
  Repeated force-kill relaunches trigger Studio's home/recovery page — minimise
  them.
- **Rebuild:** `rojo build default.project.json --output SocialCafe.rbxlx` (or
  `test.project.json` for the TestEZ place) — NEVER while Studio has that file open.
- **Relaunch:** launch `RobloxStudioBeta.exe` with the absolute place path, wait
  ~24s, then `list_roblox_studios` + `set_active_studio`.
- **Driving:** `execute_luau` runs in an ISOLATED VM (fresh require cache) — read
  the running server's state via **remotes** (e.g.
  `RS.Remotes.RequestProfile:InvokeServer()`) or by inspecting the DataModel, not
  by requiring services. **The Play-mode camera CANNOT be repositioned from the
  MCP** (the game's camera controller overrides any set) — verify visual features
  via **server data** (`execute_luau` + `inspect_instance`) + console/analytics,
  and expose visual tuning as config knobs for the owner to eyeball. Upload an
  image by serving it over `python -m http.server` and passing the URL to
  `upload_image` (it rejects local paths).
- **TestEZ:** build `test.project.json`, open it, `RunTests` prints the report on
  Play. Expect **1 known failure** (the Graphics HUD-icon spec, §4) — CI does NOT
  run TestEZ, only builds.

## 7. Exact command to continue

Open Claude Code in `C:\Users\barna\Desktop\roblox` and paste this file, or say
"continue" (a fresh session reads `docs/SESSION_HANDOFF.md`). Recommended order:
**fix the three §3 bugs** (what the owner is blocked on) → build **Phase C 4b** →
**publish** → **Phase D**.
