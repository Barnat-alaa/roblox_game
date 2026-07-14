# Art direction

_Established 2026-07-14 from owner-supplied reference screenshots of a classic
Facebook café-management game (analysed per GAME_DESIGN §26: we extract
abstract, uncopyrightable design principles and build ORIGINAL art that evokes
the same feeling. No asset, texture, sprite, logo, character design, or
identifiable map from any existing game is ever reproduced.)_

## The feeling to hit

"My cosy little café, seen from above, alive with cooking and customers."
Players should think *"this reminds me of the classic café sims"* — never
*"this is that game copied into Roblox."*

## Camera (the #1 feel-driver) — implemented in CameraController

- Fixed elevated three-quarter view: **38° elevation**, yaw locked to 90°
  steps (Q/E), default from the plot's front-left.
- Mouse-wheel zoom, clamped 26–95 studs; smooth follow on the character.
- **Camera-facing walls fade out client-side** so you always look INTO the
  room — interiors read like a diorama.

## Proportions & characters — implemented in CustomerService

- Chibi read: oversized round head (~head:body 1:1), short body, floating
  first-name tag ("Alicia"-style) + thought-bubble orders above.
- Big, readable silhouettes over detail. One accent colour per customer type.

## Interior read — implemented in CafeService + BuildService

- Deep warm **maroon walls**, white-framed windows, wooden door, warm **oak
  plank floor**; the street outside stays neutral grey so interiors pop.
- **Tables**: red cloth top over a white skirt (checkered-tablecloth energy
  without copying any texture), dark pedestal.
- **Appliance row**: white bodies, dark cooktops, steel kettle/pot
  silhouettes, a red accent stripe.
- **Counters**: white body, wood top, plates on display.
- Grid-aligned placement stays visually obvious — it's part of the genre.

## Palette

| Role | Colour |
|---|---|
| Walls | `150, 60, 50` (maroon) |
| Floor | `176, 132, 90` (oak) |
| Cloth accent | `196, 60, 50` |
| Whites | `245, 242, 235` |
| Wood | `150, 110, 80` / dark `96, 70, 52` |
| Warm light | `255, 208, 140` |

## UI direction (next pass)

- Top bar: coins pill + XP progress bar + café rating.
- Bottom-centre: chunky rounded icon toolbar (social / build / shop / cook).
- Rounded cards everywhere; no neon, no clutter (§25 guardrails).

## Rules

1. Reference images are **analysed, never traced or extracted**.
2. Every asset in this game is procedural greybox (this pass) or original
   Blender/Figma work (later) — logged in ASSET_LICENSES.md.
3. Discontinued games are still copyrighted; DMCA risk is an existential
   threat at launch. When in doubt, redesign further away.
