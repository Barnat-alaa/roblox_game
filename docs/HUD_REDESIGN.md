# HUD redesign — chunky icon dock, stat chips, right rail

_Created 2026-07-21 at the owner's request: "work more on the menu, I don't like
it." The owner supplied a screenshot of a successful Roblox restaurant tycoon
as the reference for **layout and feel**._

## ⚠️ Read this first: what we copy and what we do not

We copy the **layout, information architecture and interaction pattern** — where
things sit on screen, that buttons are chunky rounded squares with a numbered
badge, that the name appears on hover, that a right-hand rail carries
single-key shortcuts. Layout and UX patterns are not copyrightable.

We do **NOT** copy the reference game's icon art, button skins, fonts, colours
or wording. Every image must be an owner-approved Creator Store asset (or
original), recorded in `docs/ASSET_LICENSES.md` exactly like every other asset
in this project. This is the same line `docs/MENU_SPEC.md` already draws for
Café World, and `docs/ART_DIRECTION.md` is still the authority on palette.

Do not screenshot-trace or re-upload anything from the reference image.

---

## 1. What exists today

| Piece | Where | State |
| --- | --- | --- |
| Stat chips (Coins / Reputation / Buzz) | `UIController` `createStat`, ~line 590 | small chips, text-glyph fallback |
| Action dock | `UIController` `actionDock`, ~line 659 | **bottom-RIGHT**, 334×48, small text buttons + a "MENU" button |
| Design tokens | `src/client/UI/Theme.luau` | Colors, Radius, Font, Motion, `Images = Graphics.UI` |
| Primitives | `src/client/UI/Components.luau` | `Corner`, `Stroke`, `Padding`, `Gradient`, `Label`, `Icon`, `Button`, `Panel`, `PanelHeader`, `SetPanelVisible` |
| Icon images | `src/shared/Config/Graphics.luau` → `Graphics.UI` | Coin, Reputation, Level, Buzz, Goals, Cookbook, Build, Shop, Pantry |
| Responsive rules | `src/client/UI/ResponsiveLayout.luau` | phone/desktop; phone must keep ≥55% world visible, desktop ≥62% |

`Components.Icon` already falls back to a `Theme.Glyphs` text glyph when an
image fails to load — keep that behaviour, it is what stops the HUD going blank
if an asset is moderated.

## 2. Target layout

Three zones. Nothing else changes position.

```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│                                                     [rail]│  ← 2c right rail
│                                                     [rail]│
│                                                     [rail]│
│                                                           │
│  ┌──────┐                                                 │
│  │ 💎 10│  ← 2a stat chips (bottom-LEFT)                   │
│  ├──────┤                                                 │
│  │ 💵350│         ┌───┐┌───┐┌───┐┌───┐┌───┐               │
│  └──────┘         │ 1 ││ 2 ││ 3 ││ 4 ││ 5 │  ← 2b dock    │
└───────────────────┴───┴┴───┴┴───┴┴───┴┴───┴───────────────┘
```

### 2a. Stat chips — bottom-left

Stacked pills, one per stat: **Money · Reputation · Buzz**.

- Rounded pill, dark translucent background (`Theme.Colors.Espresso`, ~0.15
  transparency), `Theme.Radius.Pill`.
- Circular coloured icon disc on the left (icon image inside), value text right.
- Money keeps the existing coin colour; Reputation `Theme.Colors.Honey`; Buzz
  `Theme.Colors.Coral` (already the case — keep the semantic colours).
- Value animates on change: tween the number up, and pop the chip scale to
  1.08 → 1.0 over `Theme.Motion.Fast`. Never snap.
- Move from wherever they are now to bottom-left, anchored `(0, 1)`.

### 2b. Action dock — bottom-centre

The main change. Five chunky square buttons, horizontally centred, replacing the
current bottom-right text dock.

Buttons, left → right, with keyboard shortcuts:

| # | Button | Opens | Key |
| --- | --- | --- | --- |
| 1 | **Build** | build/placement mode | `1` |
| 2 | **Cookbook** | recipe book | `2` |
| 3 | **Staff** | staff hire/manage | `3` |
| 4 | **Upgrades** | upgrades panel | `4` |
| 5 | **Shop** | shop panel | `5` |

Per button:
- ~72×72 on desktop, ~58×58 on phone (drive off `ResponsiveLayout`).
- Rounded square, `Theme.Radius.Large`, subtle vertical `Gradient` for the
  glossy look, 2px `Stroke` in `Theme.Colors.Cream` at low transparency.
- Icon image fills most of the face; **no permanent text label** on the button.
- Small circular badge bottom-right with the shortcut number.
- **Hover:** the button lifts (scale 1.0 → 1.10, `Theme.Motion.Fast`) and the
  **name appears underneath** as a small dark pill (this is the owner's explicit
  ask — "the name under them when the mouse is on them"). Fade the label in;
  do not reserve layout space for it when hidden.
- **Press:** dip to 0.94 then settle to 1.0. This is the "pop" feel.
- **Active/open panel:** button stays raised with a brighter stroke, so you can
  see which panel is open.
- Touch devices have no hover — show the name label permanently underneath at a
  smaller size instead, and skip the lift.

### 2c. Right rail — vertical, single-key shortcuts

A vertical strip of smaller round buttons on the right edge, each with its
keyboard letter shown beside/below it, matching the reference's pattern.

| Button | Opens | Key |
| --- | --- | --- |
| **Goals** | daily goals | `G` |
| **Trophies** | trophies/achievements | `T` |
| **Map** | neighbourhood map / visit | `M` |
| **Music** | audio toggle | `B` |
| **Settings** | settings panel | `V` |

- ~46×46 round, same gradient/stroke language as the dock, just smaller.
- The key letter sits in a tiny pill next to the button.
- Same hover-name, lift and press-dip behaviour as the dock.
- Must not overlap the order ticket or the health card — check both at phone
  size before calling it done.

## 3. Implementation notes

- **Build it in `Components.luau`, not inline in `UIController`.** Add
  `Components.IconButton(parent, opts)` returning the button plus its hover
  label, and let both the dock and the rail use it. The current dock is
  hand-rolled and that is why it is hard to restyle.
- Keep every colour/radius/motion value in `Theme`. No literals in the
  controller.
- Register shortcuts through one table so the key, the icon and the panel are
  declared in a single place — today the bindings are scattered.
- `Graphics.UI` is the only place image ids may live.
- Respect `ResponsiveLayout`'s world-visibility floors (phone ≥55%, desktop
  ≥62%). The dock is the biggest risk here — measure, don't eyeball.
- Panels themselves are out of scope for this pass. The owner will supply a
  screenshot per menu and those get specced separately.

## 4. 🖼️ Icons — source these yourself

**The owner has asked the implementing agent to source the icons, not to wait
for them.** The research below is already done and licence-verified (2026-07-21,
parallel scouts + an adversarial licence-verification pass). Do not redo it;
do confirm each licence page yourself before uploading, because licences change.

### 4.1 The pack to use — Nieobie Game Icon Pack (CC0)

<https://github.com/Nieobie/Game-Icon-Pack>

- **CC0 1.0**, verified down to the repo's actual `LICENSE` file containing the
  full legal deed — not just a README claim.
- **800+ icons from a single artist**, so cohesion is guaranteed by
  construction. Covers all 13 HUD icons in ONE `ASSET_LICENSES.md` row with
  **zero attribution burden**.
- Explicitly "no sharp corners" — the closest verified match to this project's
  warm rounded direction.
- Ships **padding and no-padding** variants in SVG and PNG; no re-packing
  needed. The repo carries no version number — **pin the exact git commit hash**
  in `ASSET_LICENSES.md`.

It is *flat*, not glossy. That is fine: the glossy chunk comes from the button
plate behind it, not the glyph.

### 4.2 The button plates — Kenney UI Pack (CC0)

<https://kenney.nl/assets/ui-pack-adventure> (and the base `ui-pack`)

- **CC0 1.0**, verified on the pack page and site-wide at kenney.nl/support:
  "Attribution is not required", commercial use permitted.
- Rounded plates, buttons, panels. This is what supplies the chunky warmth.
- The base pack's blue is cool and clashes with the maroon/oak palette — take
  the grey/white variants and tint them warm in `Theme`.
- Kenney asks you not to use *his logo*. That is a trademark reservation and
  does not constrain the art.

### 4.3 Food icons — Kenney Food Kit (CC0)

<https://kenney.nl/assets/food-kit> — ~200 low-poly models, CC0, no attribution.

The trick that makes this the right answer: **render each 3D model to a flat 2D
icon.** The cookbook icon and the object on the plate are then literally the
same asset, which no 2D-only pack can give you. CC0 permits rendering and
redistributing those renders.

Verified coverage: tea cup, frappe, croissant, cake, cake slice, sandwich,
muffin, donuts, bread/baguette. **Gap:** no small espresso cup — recolour the
tea cup.

### 4.4 Explicitly rejected, with reasons

Do not quietly reintroduce these:

| Source | Why not |
| --- | --- |
| **game-icons.net** | CC BY 3.0 with **per-author** attribution — 13 icons from 6 artists = 6 credits, forever. Monochrome silhouettes anyway. |
| **OpenMoji** | CC BY-**SA** 4.0. Recolouring to the palette forces re-release under SA. Looks like CC BY at a glance — the classic trap. |
| **Noto Emoji** | README says "**most** image resources" are Apache 2.0. You cannot cleanly assert coverage for a specific image. |
| **CraftPix free** | Custom licence forbids redistribution, which conflicts with uploading to Roblox. |
| **Lucide** | Dual **ISC + MIT** (~150 Feather-derived icons keep Cole Bemis's MIT notice). Thin outlines — wrong style regardless. |
| **Filwarka "2D Roblox Food Icons"** (itch.io) | Closest style match to the current HUD, but itch.io blocked verification — licence **UNVERIFIED**. Do not adopt until someone reads the terms; "free download" often does not grant commercial use. |

### 4.5 ⚠️ Provenance caveat on the pack currently shipping

`Graphics.UI` currently draws nine icons from **Simulator Icon Pack**
`99176447965360`. `ASSET_LICENSES.md` audits it as "112 decals, no scripts" —
that is a **script** audit, not a **provenance** audit.

The same pack is published on the Creator Store **three times** with
byte-identical descriptions, each claiming to be the original:
`99176447965360` (DevJoob, 2026-02-26), `75039072715318` (WDavidig,
2026-04-12), `71964724767093` (CodeNova492Frost9191). Ours is the earliest, so
it is the likely origin on Roblox — but there is no findable artist footprint
and no written commercial grant, and a Creator Store licence does **not**
warrant provenance (Roblox cannot grant rights the uploader never held). The
grant is also scoped to Studio and Experiences only — it does not cover the game
icon, thumbnails, or marketing.

Migrating the HUD to the CC0 packs above therefore also *retires* this risk.
Prefer replacing all 13 icons with Nieobie rather than mixing the two — mixed
corner radii and stroke weights are visible side by side in one toolbar.

### 4.6 Uploading to Roblox

Self-upload the CC0 art as Images/Decals via the Creator Dashboard — the owner
becomes the uploader, provenance is documented, attribution burden is zero.
Note: since 2026-05-05 **new** accounts/Groups default to Asset Privacy on, so
uploads can be *Restricted* and silently fail to render; existing accounts are
unaffected but it is a toggle. "Open Use" is **irreversible**.

Record every uploaded id in `docs/ASSET_LICENSES.md` with pack, licence, source
URL and commit hash before shipping it.

## 5. Acceptance criteria

- [ ] Money / Reputation / Buzz sit bottom-left as pills; values animate, never snap.
- [ ] Five chunky buttons centred at the bottom, in the order above.
- [ ] Hovering a button lifts it **and shows its name underneath**.
- [ ] Pressing dips then settles ("pop").
- [ ] Number badges 1–5 present, and those keys open the same panels.
- [ ] Right rail present with its letter shortcuts working.
- [ ] The open panel's button reads as active.
- [ ] Touch layout shows names permanently and stays within the visibility floors.
- [ ] Every image comes from `Graphics.UI` and is licensed in `ASSET_LICENSES.md`.
- [ ] Text-glyph fallback still works if an image fails to load.
- [ ] StyLua + Selene + both Rojo builds green; verified live in Studio, not just built.
