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

## 4. 🖼️ Images needed from the owner

The HUD only reads as one system if the icons come from **one cohesive pack**.
Ask for a single Creator Store icon set and take everything from it.

Already have (in `Graphics.UI`, from the "Simulator pack"): Coin, Reputation,
Level, Buzz, Goals, Cookbook, Build, Shop, Pantry.

**Still needed:**

| Slot | Used by |
| --- | --- |
| `Staff` | dock button 3 |
| `Upgrades` | dock button 4 |
| `Trophy` | right rail |
| `Map` | right rail |
| `Music` | right rail |
| `Settings` | right rail |

For each: the owner sends the **Creator Store asset id or link**, and it gets
recorded in `docs/ASSET_LICENSES.md` with its creator before use. If the owner
prefers to replace the existing nine as well so the whole set matches, that is
better — ask.

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
