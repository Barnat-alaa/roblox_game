# Current status

_Last updated: 2026-07-13 — Day 1 verified live in Studio; first push to GitHub._

## What was completed

- **Toolchain installed and working**: rokit 1.2.0, rojo 7.4.4, stylua 2.0.2, selene 0.27.1, gh 2.95.0 (authenticated as Barnat-alaa).
- **MCP connected**: Claude Code drives Studio directly (game-tree inspection, Luau execution, play/stop, console reads).
- **Day 1 scaffold verified live**: server boots clean — 6 plots built, 12 services, profile loads, client boots 6 controllers.
- **All 21 logic tests pass** (Economy/RewardMath, Grid placement, Progression) — run inside Studio against the live DataModel via an MCP TestEZ-compatible harness.
- **End-to-end serve loop verified behaviourally**: order created → client `ClaimOrder` → +7 coins espresso payout (matches config), reputation/XP granted, re-claim of the same order rejected (no double payment).
- **Fixed first real bug**: client `Main` waited on `script:WaitForChild("Controllers")` but `Controllers` is a *sibling* — controllers/UI never loaded. Fixed to `script.Parent` (src + Studio patch + place rebuilt).
- **CI gates green locally**: StyLua check, Selene 0 errors (added `testez.yml` std for spec globals), Rojo build.
- Repo pushed to <https://github.com/Barnat-alaa/roblox_game> with GitHub Actions CI.

## What was tested

- 21/21 unit specs in live Studio (Edit DataModel).
- Playtest boot: no errors in Output except the expected in-memory DataStore warning (place unpublished).
- E2E via real remotes from the Client VM: `RequestProfile`, `ClaimOrder` (150 → 157 → 164 coins across two distinct orders; duplicate claim paid 0).
- Customer generator cadence: one pending order per user, next order ≤8 s after resolution — confirmed live.

## What failed / is not done

- Zero-gap duplicate-claim race (two `ClaimOrder` fires in the same frame) not yet behaviourally tested — code path is guarded (claim marked before grant); retest scheduled with the Day-6 security review.
- Visible walking NPCs, manual-cook minigame, café-visit interaction, lighting/audio, onboarding flow, mobile pass: Days 3–6.
- Persistence is in-memory in Studio until the place is published with API access.
- Studio was closed mid-session; SocialCafe.rbxlx has been rebuilt from the repo (contains the boot fix) and is ready to reopen.

## What YOU need to do next

1. Reopen `C:\Users\barna\Desktop\roblox\SocialCafe.rbxlx` in Studio (double-click the file).
2. Later this week: publish the place as a private experience + enable Studio Access to API Services (see NEXT_ACTIONS.md) so saves persist.

## Exact command to continue

Open a Claude Code session in `C:\Users\barna\Desktop\roblox` and say "continue" —
tasks are tracked; next up is Day 3 (visible customer NPCs + coffee minigame).
