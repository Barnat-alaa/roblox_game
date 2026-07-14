# Security

## The rule
The client may **request** an action; it may never **decide** a reward, currency
change, unlock, or authoritative placement. All of that lives on the server.

Bad: `GiveCoins:FireServer(100000)` · Good: `ClaimOrder:FireServer(orderId)` and
the server computes the payout from server-side config.

## Every remote validates
Type · range · length · ownership · permission · distance/proximity · current
player state · request frequency · replay/duplicate. Reusable helpers:
`RateLimiter` (sliding window) and per-handler `typeof` guards.

## Current handlers — audited 2026-07-14 (Day 6 review)
| Remote | Guards implemented |
| --- | --- |
| `ClaimOrder` | typeof(orderId)==string; rate-limited; order exists; owner matches; not already claimed (claimed flag set **before** granting); recipe unlocked; player within 60 studs of own café. Reward from server config only. **The client's `manualCook` argument is ignored** — the bonus comes solely from a server-verified brew (`RecipeService.ConsumeManualCook`, one-shot, per-order). |
| `StartCooking` | typeof string; rate-limited; order exists/owned/unclaimed; recipe unlocked; near own plot. Server records its own start clock. |
| `FinishCooking` | typeof string; rate-limited; session exists and matches the order; TTL enforced; **server derives the bar position from its own clock** (shared Config/Cooking constants) — a "perfect brew" cannot be forged. |
| `PlaceFurniture` | payload is table; catalogId string + coords/rotation numbers; rate-limited; item exists; **owned in inventory**; NaN/non-integer/out-of-bounds/overlap/rotation/object-cap rejected; inventory decremented on commit. |
| `RemoveFurniture` | typeof(instanceId)==string; rate-limited (added in Day-6 audit); must exist in the player's own placedFurniture. |
| `PurchaseItem` | typeof(catalogId)==string; rate-limited; item exists; level requirement; `TrySpendCoins` (can't overspend). |
| `CompleteTutorialStep` | integer; rate-limited; strictly ordered (`step == current+1`); capped at the step count; completion reward granted exactly once per profile. |
| `VisitCafe` | payload table; rate-limited; plot index integer + must exist and be owned; **compliments from a fixed whitelist only** (no free text, §19); physical-presence check (≤50 studs); one compliment per visitor→owner per session; teleports only to fixed plot doors. |
| `RequestProfile` | returns only the caller's own profile. |

## Known gaps (tracked in KNOWN_ISSUES.md)
- Serve distance check is coarse (plot radius, not the counter point).
- No cross-server session lock yet → item-dupe risk until ProfileStore lands.
- Rate limits are per-remote; consider a global per-player budget under load.
- `RequestProfile` (RemoteFunction) has no rate limit — cheap lookup, but add
  one if invoke-flooding shows up in logs.
- Zero-gap duplicate `ClaimOrder` race untested behaviourally (code path is
  guarded: claim marked before grant; sequential re-claims observed to pay 0).

## Monetisation (when added)
`ProcessReceipt` must be **idempotent** — grant each `PurchaseId` exactly once,
persist that it was granted, and return `PurchaseGranted` only after the grant is
saved. Never trust a client-reported purchase.

## Data & secrets
- Never commit API keys/tokens (`.gitignore` blocks `.env`, `*.key`, `*.pem`).
- Open Cloud API keys live in GitHub **encrypted secrets**, scoped minimally.
- Production publishing requires explicit approval; no auto-publish to prod.
- DEV/STAGING/PROD use separate DataStore prefixes so dev can't overwrite prod.

## Reference
- <https://create.roblox.com/docs/scripting/security/client-server-boundary>
- <https://create.roblox.com/docs/scripting/security/security-tactics>
