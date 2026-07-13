# Release checklist

Publishing flow: `feature/*` → PR → CI → review → `develop` (Dev) → test →
`staging` (Staging) → manual QA → tag → **manual production approval** → `main`
(Production) → monitor. Production publish is never automatic.

## Do not publish publicly until ALL are true
- [ ] Tutorial can be completed start to finish.
- [ ] Save and load work on a published place (API access enabled).
- [ ] Purchases are idempotent (`ProcessReceipt` grants each id once).
- [ ] No critical Output errors during a full smoke test.
- [ ] Every remote validates input; rate limits exist.
- [ ] Development/debug commands are disabled in production.
- [ ] Production uses `PROD_` DataStores; keys never touched dev data.
- [ ] Mobile UI is usable on a real Android device (large targets, no hover-only).
- [ ] NPCs recover when stuck.
- [ ] Players cannot: place outside their plot · overlap · exceed the object cap ·
      purchase without funds · claim an order twice · edit another player's café.
- [ ] Content maturity questionnaire completed.
- [ ] All major assets have documented licences (docs/ASSET_LICENSES.md).
- [ ] Music/sound have permission; icon + thumbnails are original.
- [ ] Privacy/moderation reviewed; no open text input anywhere.
- [ ] Analytics events are live and visible in the dashboard.
- [ ] A previous stable version exists; rollback steps written (below).
- [ ] Tester feedback reviewed; top drop-offs addressed.

## Publish steps (Open Cloud)
1. Merge to the target branch; CI green.
2. Tag the release (`vX.Y.Z`).
3. Publish via the Place Publishing API with the environment's scoped API key
   (GitHub encrypted secret), or manually from Studio for early releases.
4. Verify the live version number in the Creator Dashboard.

## Rollback
1. Keep the last-known-good `.rbxl`/version id recorded per release.
2. To roll back: republish the previous place version (Dashboard → Version history
   → Restore, or re-publish the tagged build) and announce.
3. Data: schema changes must be **forward-compatible** (reconcile fills new keys),
   so a code rollback does not brick saved profiles. Never ship a destructive
   migration without a backup + `SaveMigration.spec` coverage.

## References
- <https://create.roblox.com/docs/cloud/guides/usage-place-publishing>
- <https://create.roblox.com/docs/cloud/auth/api-keys>
