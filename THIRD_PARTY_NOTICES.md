# Third-party notices

Every external dependency, its version/commit, licence, and why it's here.
Nothing is imported without an entry. See also [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md)
for art/audio/model assets.

## Toolchain (dev only — not shipped in the place)

| Tool | Version (pinned in rokit.toml) | Licence | Purpose |
| --- | --- | --- | --- |
| rojo | 7.4.4 | MPL-2.0 | Sync filesystem ↔ Studio, build place files |
| wally | 0.3.2 | MPL-2.0 | Package manager |
| StyLua | 2.0.2 | MPL-2.0 | Formatter |
| Selene | 0.27.1 | MPL-2.0 | Linter |
| luau-lsp | 1.30.0 | MIT | Editor language server / type checking |

## Runtime dependencies (Wally)

_None yet._ The MVP scaffold ships with **zero** third-party runtime code.

Planned, each pending a licence + source review before adoption:

| Package | Intended use | Licence | Status |
| --- | --- | --- | --- |
| ProfileStore | Session-locked autosaving player data | MIT | Planned (Week 6) — will pin exact version |
| RbxUtil (Signal, Trove) | Only the specific utilities we use | MIT | Under consideration |

## CI actions

| Action | Purpose | Licence |
| --- | --- | --- |
| actions/checkout | Checkout repo | MIT |
| CompeyDev/setup-rokit | Install Rokit in CI | MPL-2.0 |
| actions/upload-artifact | Upload build output | MIT |

_When any dependency is added: record the exact version/commit here **and** review its scripts before first run._
