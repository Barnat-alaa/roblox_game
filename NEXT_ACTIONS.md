# Next actions

_Last updated 2026-07-21._ Ordered. Items marked **[you]** need your
account/machine; the rest Claude does.

## 1. HUD/menu rework **[Claude]** — the main build task
Full spec in [docs/HUD_REDESIGN.md](docs/HUD_REDESIGN.md): bottom-left stat
pills, bottom-centre chunky icon dock with hover names and 1–5 shortcuts,
right-hand rail with letter shortcuts. **Claude sources the icons himself** —
verified CC0 packs are named in §4 (Nieobie for glyphs, Kenney UI Pack for the
plates, Kenney Food Kit for menu items). Panels themselves come later — the
owner will send a screenshot per menu.

_Verification status: the 10-café street and the ambient crowd were playtested
and confirmed by the owner on 2026-07-21. The only thing still untested by
execution is the `saveBlocked` path, which needs a DataStore whose `GetAsync`
fails and cannot be forced from Studio._

## 2. Dashboard Max Players → 10 **[you]** — real blocker
`World.plotCount` is now 10 but the dashboard is recorded at **30**. Until this
changes, 20 players per server join with **no café**. It is not settable from
code.
→ Creator Dashboard → the experience → **Places → Max Players → 10 → Save**.

## 3. Open Cloud API key for publishing **[you, 3 min]**
So `./scripts/publish.ps1` can ship local source directly (never publish from
Studio — it uploads whatever is *open*, not what is on disk).
→ <https://create.roblox.com/dashboard/credentials> → Create API Key → add the
**universe-places** system → select this universe → tick **write** → Accepted IP
`0.0.0.0/0` → copy the key (shown once).
→ Then: `$env:ROBLOX_API_KEY = "<key>"` and `./scripts/publish.ps1`.

## 4. Menu panel screenshots **[you, when convenient]**
The HUD pass covers the dock, stat chips and right rail only. For each panel
behind a button (Build, Cookbook, Staff, Upgrades, Shop) send a reference
screenshot and it gets specced and rebuilt the same way.

## Hardening backlog (before public launch)
- **ProfileStore swap** for session locking — `saveAsync` is currently a blind
  last-writer-wins `UpdateAsync`; a server hop can roll a profile back. This
  matters more now that many small servers exist.
- `BindToClose` waits a flat 3s instead of waiting for saves to finish.
- CustomerService walks customers down the street-decor lines (z −14 / −46) and
  is the only street-facing service not using `StreetMath`.
- Offline earnings ignore producer capacity (Waiter-only `capacityScale`).
- `onPlayerRemoving` stamps `lastSeenAt` even if settlement never ran.
- SocialService compliment anti-farm is per-server in-memory — beaten by rejoin.
- AnalyticsService is a log-only stub, so none of the above is visible at scale.
- Counter depth under-fills its footprint (machine overhangs ~1.1 studs).
- Monetisation: `MonetizationService` is a stub; `ProcessReceipt` must be
  idempotent and receipt-ledgered before any purchase ships.
