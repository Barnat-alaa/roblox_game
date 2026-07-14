# Asset licences

Every shipped asset (model, texture, image, audio, font) is recorded here with its
source and licence **before** it ships. Code dependencies live in
[../THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

## Current assets
All 3D/UI art is **code-generated greybox** (see docs/ART_DIRECTION.md) — no
imported visual assets. Icon and thumbnail are staged screenshots of our own
game. Audio comes exclusively from Roblox's licensed partner catalogs:

| Asset ID | Name | Type | Creator | Source | Licence | Roblox asset id | Approved for prod |
| --- | --- | --- | --- | --- | --- | --- | --- |
| audio_bell | Desk Bell Counter Service 1 | Audio SFX | ProSoundEffects | Creator Store | Roblox licensed SFX partner catalog (on-platform use) | 9125485591 | ✅ |
| audio_serve | Desk Bell Counter Service 2 | Audio SFX | ProSoundEffects | Creator Store | Roblox licensed SFX partner catalog | 9125485659 | ✅ |
| audio_brew | Blender Water 1 | Audio SFX | ProSoundEffects | Creator Store | Roblox licensed SFX partner catalog | 9113456593 | ✅ |
| audio_music | Cozy Cafe Focus Piano | Audio music | DistrokidOfficial | Creator Store | Roblox licensed-music program (on-platform use) | 97316511727172 | ✅ |

Audio rule: only Roblox partner catalogs (ProSoundEffects, APM,
DistrokidOfficial, Monstercat…) or original/commissioned audio. Community
re-uploads of stock sounds are provenance risks — never ship them.

## Rules (do NOT skip)
- No ripping/decompiling/extracting from any game. No tracing protected artwork.
- No reusing another work's textures, music, SFX, logos, character designs, UI
  icons, identifiable maps, or distinctive fictional recipe names.
- Credit does **not** grant permission. Don't assume old/discontinued games are
  public domain. Never market as an official remake.
- References are analysed into **abstract principles**, then re-created originally.

## Before adding any asset
1. Identify the true original source.
2. Read the licence; confirm it permits our use (commercial, on Roblox).
3. Record the exact version/commit or purchase/commission proof.
4. Add a row above (with poly count + mobile notes) and, for code, a
   THIRD_PARTY_NOTICES entry.
5. For Creator Store models: prefer reputable creators, inspect/disable scripts,
   strip suspicious remotes/obfuscated code, rebuild core gameplay ourselves.

## Sourcing plan
Original assets in Blender/Blockbench; UI in Figma; audio only original/commissioned/
properly licensed via Roblox's permitted systems. AI-assisted meshes are drafts to be
reviewed, simplified, optimised, and ownership-checked — never final art as-is.

## References
- <https://create.roblox.com/docs/production/publishing/dmca-guidelines>
- <https://create.roblox.com/docs/ip-licensing/creators>
- <https://create.roblox.com/docs/production/creator-store>
