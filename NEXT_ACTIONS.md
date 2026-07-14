# Next actions

Ordered. Items marked **[you]** need your account/machine; the rest Claude does.

## 1. Publish the Dev experience **[you]** — the only real blocker left
Persistence (MVP criterion #12: "return without losing progress") cannot be
tested until this is done:
1. Open `SocialCafe.rbxlx` in Studio (or ask Claude to open it).
2. **Alt+P** (File → Publish to Roblox) → new experience → name `Social Cafe DEV` → **Create** (stays private by default).
3. **Home → Game Settings → Security → Enable Studio Access to API Services → Save**.
→ **Send:** "published". Claude then verifies PlaceId ≠ 0 and runs the
   save → rejoin → data-persists smoke test.

## 2. Install the Rojo plugin **[you, optional, 2 min]**
Toolbox → Plugins tab → search **Rojo** (by evaera) → install → Plugins
ribbon → Rojo → **Connect** while Claude runs `rojo serve`. Eliminates all
manual Studio syncing.

## 3. Day 6 remainder (Claude, next Studio session)
- Scripted brew-bonus assertion + zero-gap duplicate-claim test.
- Device-simulator mobile pass (touch targets, safe areas, layout).
- Audio feedback pass (original/licensed only).
- Two-client test **[you: click Test → Start (2 players) when asked]** —
  verifies visits, compliments, and two cafés operating at once.

## 4. Day 7 — publish the MVP to testers
- Content maturity questionnaire, icon + thumbnail, private access for
  testers, full RELEASE_CHECKLIST pass, KNOWN_ISSUES triage.

## Backlog after MVP week
- ProfileStore swap for session locking (Week 6 hardening).
- Staff automation (Week 3), more recipes/furniture (Week 5), monetisation
  after the loop is fun (Week 6).
