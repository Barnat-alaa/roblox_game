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

## Current handlers
| Remote | Guards implemented |
| --- | --- |
| `ClaimOrder` | typeof(orderId)==string; rate-limited; order exists; owner matches; not already claimed (claimed flag set **before** granting); recipe unlocked; player within 60 studs of own café. Reward from server config only. |
| `PlaceFurniture` | payload is table; catalogId string + coords/rotation numbers; rate-limited; item exists; **owned in inventory**; NaN/non-integer/out-of-bounds/overlap/rotation/object-cap rejected; inventory decremented on commit. |
| `RemoveFurniture` | typeof(instanceId)==string; must exist in the player's own placedFurniture. |
| `PurchaseItem` | typeof(catalogId)==string; rate-limited; item exists; level requirement; `TrySpendCoins` (can't overspend). |
| `RequestProfile` | returns only the caller's own profile. |

## Known gaps (tracked in KNOWN_ISSUES.md)
- Serve distance check is coarse (plot radius, not the counter point).
- No cross-server session lock yet → item-dupe risk until ProfileStore lands.
- Rate limits are per-remote; consider a global per-player budget under load.

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
