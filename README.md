# Social Café City

> Working title — a distinctive, legally-clear name is chosen before public release (see [ROADMAP.md](ROADMAP.md)).

A social café-management game for Roblox. Every player owns a café on a shared
neighbourhood street: they cook, serve customers, decorate with a grid-based
build system, progress a star rating, and visit each other's cafés. The emotional
hook is **"start with a tiny forgotten café and turn it into the heart of a living
neighbourhood — and it's yours, and others can see it."**

This repository is a **Rojo project in strict Luau** with a server-authoritative
architecture. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## Status

**Day-1 scaffold complete and intended to build & play as a greybox.** The core
loop (join → own a café → place furniture → a customer orders → serve → earn
coins/reputation → buy an item → save → rejoin) is implemented end-to-end at a
greybox level. See [CURRENT_STATUS.md](CURRENT_STATUS.md) and
[NEXT_ACTIONS.md](NEXT_ACTIONS.md).

## Prerequisites

- [Roblox Studio](https://create.roblox.com/docs/studio/setup) (latest)
- [Git](https://git-scm.com/downloads)
- [Rokit](https://github.com/rojo-rbx/rokit) — installs the rest of the toolchain

## Getting started

```sh
# 1. Install the toolchain pinned in rokit.toml (Rojo, Wally, StyLua, Selene, luau-lsp)
rokit install

# 2. (optional) install Wally deps — none are required for the MVP scaffold yet
wally install

# 3. Serve to Studio: open a Baseplate in Studio, install the Rojo plugin, click Connect
rojo serve

#    …or build a place file directly:
rojo build --output SocialCafe.rbxlx
```

Then in Studio press **Play**. You should spawn on a plot in a street of six
greybox cafés, see your coins/reputation HUD, get a customer order within ~8s,
and be able to Serve it, open Build, place furniture, and Shop.

## Toolchain & checks

```sh
stylua .           # format
stylua --check .   # verify formatting (CI does this)
selene .           # lint
rojo build --output build.rbxlx   # build check
```

## Repository layout

```
src/shared/    Types, data-driven Config, Network remotes, pure Utilities
src/server/    ServiceRegistry + Services/ (authoritative game logic) + Main
src/client/    Controllers/ (HUD, build, tutorial…) + Main
tests/         TestEZ specs for pure logic (economy, placement, progression)
docs/          Design, architecture, security, test plan, release, economy…
```

## Documentation index

| Doc | Purpose |
| --- | --- |
| [GAME_DESIGN.md](docs/GAME_DESIGN.md) | The game: fantasy, loop, systems, scope |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Code structure, data flow, services |
| [SECURITY.md](docs/SECURITY.md) | Client/server boundary, remote validation, anti-exploit |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | Unit + Studio + smoke tests |
| [RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) | Gate before any production publish |
| [ECONOMY_BALANCE.md](docs/ECONOMY_BALANCE.md) | Currency, prices, reward tuning |
| [ANALYTICS_EVENTS.md](docs/ANALYTICS_EVENTS.md) | Event + funnel taxonomy |
| [ASSET_LICENSES.md](docs/ASSET_LICENSES.md) | Every asset's source + licence |
| [ROADMAP.md](ROADMAP.md) | 7-day MVP + 8-week soft launch plan |

## License

Code: MIT (see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for dependencies).
Assets are tracked separately in [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md).
