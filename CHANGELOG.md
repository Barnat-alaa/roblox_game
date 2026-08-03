# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Change — 2026-08-03 — recipes re-tiered so levelling up is a promotion
Economy fix #6 (`docs/ECONOMY_ANALYSIS.md` §3.2). Every job costs work-minutes,
so **coins per work-minute** is the only rate that matters — and on that measure
the level-1 Espresso beat **six of the eight recipes unlocked after it**.
Croissant, Latte, Muffin, Iced Tea, Cinnamon Swirl and Terrace Club were all
economic *downgrades*: the correct play was to ignore them and keep pulling
espresso. Nine levels of progress bought a 17% rate improvement.

Base prices now sit on a rising curve — 3.0 coins per work-minute at level 1 to
9.5 at level 9 — so each unlock is a genuine step up:

| Level | Best recipe | Was | Now |
| --- | --- | --- | --- |
| 1 | Espresso | 3.00 | 3.00 |
| 2 | Café Sandwich | 3.00 | 3.50 |
| 3 | Croissant | 2.50 | 4.00 |
| 4 | Silky Latte | 2.50 | 4.50 |
| 5 | Sunrise Fruit Bowl | 4.67 | 5.33 |
| 6 | Velvet Mocha | 3.50 | 6.00 |
| 7 | Terrace Club | 3.00 | 7.00 |
| 9 | Morning Quiche | 3.50 | **9.50** |

Production minutes and ingredient tables are untouched, so the market sink and
the pantry pressure are unchanged — only what the dish sells for moved.
Endgame café income rises **389 → 806 coins/hour**. Overnight Roast is left
alone: it is an appointment cook outside the work-minute budget.


### Fix — 2026-08-03 — the production forecast now models the game that runs
Economy fix #1 (`docs/ECONOMY_ANALYSIS.md` §2.1/§2.2). `OperationsMath`
forecast `machines × productionYield × 60 / productionTime` — the LEGACY
scheduler, disabled since `Kitchen.useProductionPlan` went true. The live path
makes ONE serving per job costing `productionMinutes` of the role's hourly
work-minute budget.

| Recipe | Menu said | Truth (L1) | Overstated |
| --- | --- | --- | --- |
| Espresso | 180/h | 15/h | 12× |
| Muffin | 144/h | 6/h | 24× |
| Quiche | 120/h | 3.8/h | **32×** |

The ingredient line was wrong too: it multiplied a PER-SERVING cost by
`batchCostMultiplier` and divided by yield, understating Quiche by 62%.

Both are now computed from the plan: each role spends one shared hourly budget
across the recipes queued to it, and ingredients are read per serving straight
off the recipe. **That sharing is the biggest thing the old forecast missed — it
reported every recipe as if it had the whole kitchen to itself.**

Signature unchanged, so all three callers are untouched; `batchCostMultiplier`
is accepted and ignored (the plan model charges no coins per batch). Tests
updated to the real numbers plus a new case covering budget sharing — **88
passed, 1 failed** in Studio, the failure being the pre-existing `Graphics.spec`
Coin/Coins mismatch.


### Change — 2026-08-03 — demand is capped to the kitchen; Buzz now decays
Economy fixes #4 and #5 from `docs/ECONOMY_ANALYSIS.md`.

**Demand no longer ignores the kitchen.** A new café produced 15 servings an
hour against 77 arrivals, so **62 customers stormed out ANGRY every hour** — and
a fully-maxed café still lost 35/hour. The café was in visible failure from the
first minute of a save to the last. Demand is now capped at what the production
plan can actually deliver × `demandHeadroom` (1.2), so there is always slightly
more custom than you can serve — pressure, not carnage. A floor of 0.35/min
keeps a café from ever being dead.

**Buzz decays 0.9% per minute.** As a pure accumulator it could only ever be
"always max" or "always zero": with demand capped, `served − 2×walkouts` is
positive at any headroom below 2.0, so every café drifts to the cap; at headroom
2.0 half the room storms out and we are back to the bug. With decay, Buzz
settles where serving balances the bleed, making it a live readout of throughput.

Simulated over 60 hours of play:

| | Before | After |
|---|---|---|
| Angry walkouts, hour 1 | 81 | **21** |
| Angry walkouts, maxed café | 35 | **14** |
| Total walkouts over 60h | 2,201 | **752** |
| Customers served / arrived | 62% | **83%** |
| Buzz at a maxed café | 31/105 (hard ceiling) | **78/105** |

Buzz now climbs 2 → 17 → 49 → 78 as the café grows, instead of sitting at 0 for
fourteen hours and then pinning at 31. It stops short of 105 on purpose: the
production increases in fixes #6/#7 are what should carry it the rest of the way.

Verified live in Studio: decay measured 7.9671 → 7.9135 over 45s against a
predicted 7.9135. Both behaviours sit behind `Kitchen.useDemandCap` and
`buzzDecayPerMinute = 0`.


### Change — 2026-08-03 — beach shoreline, open sea and sun on the water
Owner: *"make the horizon better looking and make the edges of the map look like
a beach that leads to an infinite sea… add a sun with reflections so the game
feels more vibrant."*

**The map edge is a beach now.** The island used to stop dead in a 1.9-stud drop
into a flat water slab. It now ends in a walkable band of sand, then steps down
and outward under the water in rings that get wider and deeper — 0 to 20 studs
deep across about 190 studs — so the water grades from turquoise in the shallows
to blue offshore. The water is semi-transparent on purpose: what you see is the
sand and seabed underneath, which is where the gradient comes from.

**The sea was never actually infinite.** It was declared 8,000 studs wide, but a
Roblox part is capped at **2,048 per axis and the engine clamps silently** — so
it had always been a 2,048 square with a hard edge just past the island. Water
and seabed are now tiled to 4,000 studs in every direction.

**The sun.** Bigger disc, stronger rays, lower bloom threshold so the highlight
ON the water blooms and not just the disc, full `EnvironmentSpecularScale`, and
reflectance on the sea so the surface picks the sun up. Plus a light colour
grade (saturation +0.14, contrast +0.07) for overall vibrancy.

All of it is tunable from the new `src/shared/Config/Scenery.luau`, including a
`beachEnabled` switch to drop the whole shoreline in one line if it ever costs
too much on a phone. No assets were imported — sand and sky are Roblox built-in
materials, everything else is built from parts.

**Three defects found by screenshotting rather than assuming:**
- A **hairline running from the island straight to the horizon**, across the
  whole sea. The tile count came out EVEN, so tiles straddled the middle and a
  seam landed exactly on the island, then ran away from camera to the vanishing
  point. Forcing an odd count centres a tile on the island and pushes the
  nearest seam 1,000 studs out, past the shelf and into the haze.
- The **shelf was far too wide** (800+ studs), so everything in frame sat over
  shallow sand and the entire sea was one flat pale turquoise. Shortened to ~190
  studs, which also confines the nested rectangles' 45° corner staircase to the
  band hugging the beach where a drop-off contour looks like a real shore.
- **Haze at 0.85 washed the colour out of the cafés down the street**, not just
  the sea. Pulled back to 0.55 — the street is where the game is played.


### Fix — 2026-08-03 — café walls stay solid when you are out in the garden
Owner screenshot: *"once outside in the garden the wall disappear, i can't see
it."*

Walls fade to near-invisible when you are INSIDE so the camera can see past
them. The test for "inside" was `Grid.distanceToPlotRect(origin, position)` with
no depth argument — which falls back to `Grid.PLOT_DEPTH`, **32 cells / 128
studs, the MAXIMUM expansion**. A starting café's interior is 18 cells / 72
studs, so everything from the back wall out to z=128 — the entire garden —
counted as indoors, and the back wall faded away while the player stood outside
looking straight at it.

`rebuildShell` now publishes `interiorDepthCells` on the plot model, and the
fade rule measures against that. Each plot carries its own value, so a
neighbour's walls behave correctly too, and it updates when buying land moves
the back wall. If the attribute is ever missing the client falls back to the
SMALLEST tier: at worst a wall stays solid a few studs too long, rather than
vanishing outdoors.

Measured on the running client, tier-0 café (interior ends at local z=72):

```
 local z | OLD rule (PLOT_DEPTH) | NEW rule            | where you are
      40 | inside -> walls fade  | inside -> walls fade | inside the cafe
      74 | inside -> WALLS FADE  | outside -> SOLID     | IN THE GARDEN
     100 | inside -> WALLS FADE  | outside -> SOLID     | IN THE GARDEN
     120 | inside -> WALLS FADE  | outside -> SOLID     | IN THE GARDEN
```

Confirmed end-to-end by walking the character to local z=95 and z=115 and
reading the parts back: `WallBack/WallLeft/WallRight LocalTransparencyModifier =
0.00` at every garden position, and the inside test still returns true at z=40.
Only the `enabled` input changed — the camera-facing half of the rule is
untouched.

The three server proximity checks that also default this argument were left
alone deliberately: they are "am I near my café?" range tests with a distance
tolerance, where counting the garden is intended, and narrowing them would
quietly shorten mischief and social reach.


### Fix — 2026-08-02 — wall shelves no longer run out of the café
Owner screenshot: *"when I have a lot of items the shelves are shown outside the
cafe… if the first wall isn't enough use other wall, the back door."*

Shelves were laid out as `slot % 7` down one wall at a 10-stud step starting at
z=22, so the seventh column sat at **z=82 in a room only 72 studs deep**. The
column count was a guess that never consulted the room, so once a café unlocked
six dishes the last two columns — four shelves across both rows — stood out in
the garden.

The room decides now. `shelfSlots` walks the right-hand wall until it runs out,
then **continues along the back wall**, skipping the garden gate and both
windows rather than burying them. The whole lower row fills across both walls
before anything goes up high, so a café with a few dishes reads at eye height.
Each shelf is built relative to its slot's CFrame (+X into the room) instead of
absolute offsets, which is what lets one body of code hang a shelf on a wall
running along Z and one running along X.

Shelves also **rebuild when the layout moves under them**, keyed on an `anchor`
attribute. That heals cafés still holding the old off-the-wall positions and
re-flows everything when buying land pushes the back wall out.

Capacity, measured against the real configs: **18 slots at the starting tier**
(10 on the right wall, 8 on the back) for 14 recipes, 22 at tier 2, 28 at tier 3.
If recipes ever outgrow that it now warns instead of silently walking outside.

Verified live with all 14 recipes unlocked: every shelf inside the interior
(x 68.5–71.5 on the right wall, z 68.5–71.5 on the back), every one facing into
the room, **0 of 14 outside** — and clear of the gate, both back windows, and
the trophy shelf.


### Fix — 2026-08-01 — the gift and VIP pills really are in the top-right now
Owner, from the phone: *"the VIP and gift message, make it more at the top
right — now it hides some parameters button."*

They were positioned at y=4 and y=36 and I had verified those numbers, but they
were the only two HUDs in the game that never set `ScreenInsets`. So they
inherited the default `CoreUISafeInsets` and Roblox pushed them a topbar's
height DOWN the screen — a measured y of 4 was landing near y=90 on the phone,
level with the rail's first button, which they then covered. Every other HUD had
`DeviceSafeInsets` and positioned from the true top; these two silently
disagreed. Both now set it.

**That exposed a second collision.** Correcting the pills to sit where they
claimed to put them straight into the order ticket, which also lives on the
right edge at y 58–100 — a 10px overlap, and worse on desktop where the ticket
started at y=9. The right edge is now **one derived column** instead of four
files each choosing a number: `Theme.Hud.Pills` declares the band, `hudLayout`
starts the ticket at `pillsBottom + 8`, and the rail starts below the ticket.
`HudToggleController` reads the same value rather than re-deriving `36 + 32 + 8`
by hand.

Measured live on the running client (gift `4..32`, VIP `36..68`, ticket
`76..118`, rail `126..351`) and across seven viewports: **0 overlaps of 7** on
the right-edge column, and the camera arrows re-checked at **0 clashes of 7**
since the rail's top moving from 108 to 126 changes `railPlate`.


### Change — 2026-08-01 — pantry shortened, corners cleared, arrows always on
Owner, on the phone build: *"the pantry and production make it less lengthy and
make the orange button appear and clear… with that you leave more room so the ?
menu with the steps will be put above the star money icons. On the right put the
VIP and gift at the extreme top right so it doesn't hide any buttons. And make
the arrows that control the camera always visible, put them in a place where
there is no buttons or icons."*

**The pantry lost a third of its height** — 162px to 110px on a phone. Two
changes got it there: the header is now two rows so the **PANTRY button owns a
full-width row of its own** instead of being squeezed against the status text,
and the dock **caps at two dish slots**. That cap is the bigger win: four slots
were always reserved, so with one dish active the column ended in a block of
empty black. It is a glance widget, not the inventory.

**The tutorial "?" card moved above the stat pills** rather than below them, and
**gift and VIP moved to the extreme top-right corner** (y=4 and y=36), where
nothing else lives, so they can no longer sit over a button.

**The camera arrows are always visible.** They had been touch-only, which meant
they vanished the moment Studio or a laptop reported a mouse — the owner could
not see the thing they had asked for. They now flank the action dock, and where a
screen is too narrow for a touch target either side of it, the pair moves into
the empty band directly above the dock instead of overlapping the rail.

Verified by measurement across six viewports (844×390, 667×375, 932×430,
560×320, 1600×900, 390×844 portrait): **0 arrow clashes** with the pantry, the
dock, the rail, or the screen edge. Two bugs were caught this way that no
screenshot would have shown — the HUD toggle's `math.clamp` inverting its bounds
on a short screen (`math.clamp` *errors* when max < min), and the narrow-screen
arrow fallback running off the right edge of a 560-wide display.


### Change — 2026-08-01 — mobile HUD rearranged around a narrow pantry
Owner, on the phone build: *"make the pantry and production less wide and more
length… with that you liberate more space at the bottom so you can put at the
extreme bottom all the 6 menu buttons. The introduction steps, put them on the
left. And next gift and VIP information are ugly and too big."*

**The pantry is now a narrow vertical column** on phones and any short viewport:
132 wide with its dish slots stacked, instead of a strip spanning most of the
screen. On a 844×390 landscape phone that is **16% of the width, down from 85%**.

**That freed the bottom edge, and the six menu buttons now sit on it.** Two
things had pinned them up into the middle: the caption band reserved under each
button (gone — names flash on tap now) and the wide pantry. The dock is also six
plates wide at last — the width maths said `5 * dockPlate` and had been
under-measuring by a whole plate ever since Market was added, which is part of why
it kept colliding with the left column.

**The tutorial card is hard against the left edge.** It was indented 118px on
touch to clear the old camera pad; that pad became two edge chevrons, so the
indent was just wasted screen. It is also narrower and taller now, so it reads as
a left-hand column rather than a banner across the top.

**The gift and VIP pills are much smaller**: 196×38 → **132×28** and 196×44 →
**132×32**, text 15 → 12, VIP portrait 34 → 24, and the labels trimmed to
"Gift 14:33" / "VIP 4:47".

Two ordering bugs surfaced while measuring and are fixed: the "can the dock sit
beside the left column?" test used a looser threshold than the shift that acts on
it, so on a narrow screen the dock was told it fitted, refused to shift, and
overlapped the pantry; and the shift measured against the stat pills rather than
the whole left column, which the taller pantry now dominates.

Verified in Studio across real device classes — every phone and tablet-landscape
size puts the dock on the **extreme bottom** with the pantry at **14–20%** of the
width, and **0 of 5 layouts** have the dock clashing with the pantry, the rail, or
the screen edge. Desktop keeps its wide pantry and lifted dock, where there is
room for both.


### Change — 2026-08-01 — HUD declutter + a tap-to-hide tab (phone)
Owner, with a phone screenshot: *"I still don't like all the menus and buttons,
they take a lot of the screen… make smart decisions so the central screen stays
clean, and you can even add a sort of sliding button to hide them."*

**A hide-the-HUD tab.** One small chevron on the right edge; tap it and the entire
interface slides away, leaving just the café. Tap again and it all comes back.
What stays visible when hidden is deliberate: the tab itself (or there is no way
back), the camera arrows (so you can still look around), the attack banner (being
robbed must never be silently missed), and any open panel (hiding the HUD should
not cancel what you were doing).

**Button names no longer sit pinned open on touch.** With no hover to reveal
them, every dock and rail button carried a permanent caption — eleven of them —
and that caption row was most of what made the HUD tall. A tap now FLASHES the
name for about a second instead: you still learn what you pressed, and the rest
of the time the screen belongs to the café.

**Phone plates came down with them**, now that they no longer reserve room for a
caption: dock 54 → 46, rail 40 → 38, dock gap 10 → 8. Both stay at or above the
44px touch floor where they are the tap target.

Verified in Studio: the tab builds at 44×44 on the right edge at 40% transparency;
**permanently-visible captions went from one per button to 0**; one tap hid all
six managed HUDs (`HUD`, `InventoryHUD`, `OperationsHUD`, `SessionRewardHud`,
`VipEventHud`, `TutorialHint`) with **0 left on**, while all four essentials
(`AlertHud`, `CameraGui`, `CafeModals`, `HudToggleHud`) stayed up, and the chevron
flipped to 180° to point the way back. Confirmed visually — a completely clean
café view with only the tab remaining.


### Change — 2026-08-01 — C4/C5: panels dock to the edges, mobile baselines
Owner: *"all the menus and buttons are not well organised, they are in the middle
of the screen"* and *"be sure every item is in the extreme top, bottom and left so
they are not in the center of the screen"*.

**Every modal now docks to a screen edge.** All fourteen carried their own
three-branch layout, and every one ended the same way — centred on Desktop
(`fromScale(0.5, 0.5)`). That is what put the menus in the middle. One shared
`ResponsiveLayout.dockPanel` now owns all three breakpoints:

- **Phone** — a bottom sheet, leaving the top of the screen showing the café so
  the game stays playable one-handed while a panel is open.
- **Compact / Desktop** — a full-height column on the panel's own side. Build
  keeps the left, everything else the right, so nothing moved from where players
  already expect it — it just stopped covering the middle.

Because it is one helper, a panel cannot drift back to the centre, and the
`topInset()` fix reaches all of them at once: panels now start **below Roblox's
own topbar** (measured at 58px), which is why the build and upgrades panel headers
were unreadable in the owner's screenshots.

**Touch-target floor.** `Components.Button` now lifts every button on a
touch-only device to at least `Theme.Hud.TouchTarget` (44px — the size Apple and
Google both publish as the floor for a reliable finger press). Done in one place
rather than forty call sites, so no button can ship under the minimum; desktop
keeps its tighter, denser layout untouched.

Verified in Studio by driving all three breakpoints and measuring where each
panel's box actually lands:

| Viewport | Mode | Centred panels | Under the topbar |
| --- | --- | ---: | ---: |
| 1600 × 900 | Desktop | **0** | **0** |
| 1170 × 576 | Compact | **0** | **0** |
| 500 × 900 | Phone | **0** | **0** |

Confirmed visually: the Upgrades panel docks to the right edge with its header
fully clear of the platform topbar, and the café stays visible beside it.


### Change — 2026-08-01 — C4 (part 1): camera arrows + mobile baselines
Owner: *"don't show Q, E etc icon, just add a small arrow right and left
transparent to direct the camera"*.

The touch camera pad was an opaque 100×100 slab of four lettered buttons
(Q / E / + / −). The letters mean nothing on a phone, which has no keyboard, and
the slab ate a corner of the view. It is now **two transparent chevrons pinned to
the extreme left and right edges** at thumb height — nothing in the middle of the
screen.

The **zoom buttons are gone**: pinch-to-zoom already existed and is the gesture a
phone player reaches for, so two controls beat four. Desktop keeps the scroll
wheel. (`zoomBy` went with them — pinch and scroll set `targetZoom` directly.)

Each chevron is drawn from two rotated bars rather than a glyph, so it can never
land on a font that lacks the character — the lesson from the coin emoji.

New shared `Theme.Hud.TouchTarget = 44`, the size Apple and Google both publish
as the floor for a reliable finger press, so every surface sizes taps against one
number instead of inventing its own. New `ResponsiveLayout.viewport()` and
`ResponsiveLayout.topInset()` — the latter exists because Roblox draws its own
topbar over the screen, so anything pinned to the "extreme top" has to start below
that inset or its header is unreadable (which is what was happening to the build
panel).

Verified in Studio: both chevrons build at **44×44**, anchored to the true screen
edges (left `(0, 10)`, right `(1, −10)`) at y=357 of a 576-tall viewport,
background transparency 0.55, two drawn bars each, and **zero** Q/E/+/− buttons
remain.

⚠️ **Not yet done — the rest of C4/C5.** `ResponsiveLayout.panelSize/
panelPosition/panelAnchor` now describe an edge-docked layout (left column on
desktop, bottom sheet on phone), but **no panel calls them** — each controller
still sets its own centred position, so the panels themselves have not moved yet.
Migrating the six panel controllers and doing the touch-target audit is the
remaining work.


### Change — 2026-08-01 — stock packs are CONSUMABLE, not a permanent multiplier
Owner clarification: *"if a player chooses +5 it will add +5 in every item, ONE
TIME only (+5 coffees, +5 teas etc)"*. P4 shipped a permanent production-yield
multiplier, which is a different mechanic. Reworked to a consumable restock, and
wired to the owner's three real Developer Products.

| Pack | Effect | Coins | Robux | Product ID |
| --- | --- | ---: | ---: | --- |
| Stock Pack +5 | +5 of every unlocked dish | 900 | R$29 | `3612636850` |
| Stock Pack +10 | +10 of every unlocked dish | 1,700 | R$59 | `3612636928` |
| Stock Pack +20 | +20 of every unlocked dish | 3,000 | R$99 | `3612637043` |

**Removed** the permanent ladder entirely: `PlayerData.yieldTier` and its
reconcile clamp, `Products.yieldMultiplier` and its application in
`KitchenService.CompleteProduction`, and the OWNED/IN-USE state in the panel (a
consumable is meant to be re-bought).

**Added** `KitchenService.GrantStockPack`, which tops every UNLOCKED dish up by
`amount` and returns how many units actually landed. Deliberately not
`CompleteProduction`: none of it was cooked, so it grants no XP, mastery, goal
credit or produced-stat. It is clamped per recipe by `maxStockPerRecipe`, so a
nearly-full café gets the remainder rather than overflowing.

Because the grant reports what it delivered, **neither path charges for nothing**:
`ProcessReceipt` returns `NotProcessedYet` (so Roblox retries rather than taking
the money) and the coin path refunds and says "Your shelves are already full."

Developer Products are now the CORRECT type — the earlier Game Pass concern was
for a permanent unlock, and this is repeatable by design. Prices dropped from the
placeholder R$99/199/349 and 25k/120k/500k coins, which had been sized for a
permanent ×20 income ceiling. The **economy-rebalance debt from P4 is gone**: this
is a convenience restock you can also grind for, not a permanent income ceiling.

Verified in Studio (coin price temporarily lowered in Studio's in-memory DataModel
only — disk untouched, reverted after): buying +5 took **espresso 3 → 8 and tea
3 → 8** (+10 across 2 unlocked dishes = 5 × 2), charged once; **buying it again
added another +5 each** (8 → 13), confirming it repeats. Guards: an amount that is
not a real pack does nothing, and insufficient coins refuses with
"Not enough coins — 900 needed."


### Fix — 2026-08-01 — the coin glyph no longer renders as an empty box
Roblox's UI font has no glyph for **🪙 (U+1FA99)**, so every coin amount in the
game rendered as a tofu box — `□ 250`, `+6 □`, `Buy smell bomb (150 □)`. Verified
in Studio.

All eleven live sites now read **"coins"** instead: tip pickups, the served-customer
bubbles, combo bonuses, neighbour-help payouts, the smell-bomb buy button, the
batch-output coin buttons and the not-enough-coins message. Two other
recently-added glyphs went the same way — **🫳 (U+1FAF3)**, a Unicode 14 addition
used on the steal button, and the **🏆 / 🥇🥈🥉** medals on the leaderboard
(already swapped to "1st / 2nd / 3rd" in C3, with one straggler in the empty-state
string caught here).

Anything that wants a real coin *picture* draws one — `UI/StylePreview.coin`,
added in C1, is two circles and renders everywhere.

Verified in Studio by scanning what is actually on screen rather than the source:
**402 text elements checked live, 0 tofu-glyph hits**, and the new wording
confirmed in place ("Buy smell bomb (150 coins)", "+87 coins").

### Feature — 2026-08-01 — C2: you are TOLD when a neighbour hits your café
Owner: *"when a next door café owner does something bad to you, show a clear
message"* and *"I like the smell bomb effect — make it visible in all the café you
attacked."*

**A loud alert banner** (`AlertController`) now slides down from the top edge
naming the neighbour and what they did — "aloulouba1 hit your café — smell bomb!"
/ "Your café reeks — 1 customer walked out!". Being robbed is the moment the
social loop is supposed to land, and a corner toast was far too easy to miss. It
sits at DisplayOrder 30, above the modals: an attack outranks whatever panel you
have open. It is pinned to the TOP EDGE, never the centre, and spans the width on
a phone so the text can't truncate. All three hostile actions use it — theft,
smell bomb and poaching.

**The smell bomb now fills the whole café it was thrown into.** A single puff read
as a local effect and could be missed entirely from the far side of the room; new
`Fx.smellCloud` lays a 3×3 grid of vapour sources across the victim's interior,
on top of the existing puff under the caster's feet (which is what identifies the
thrower). The grid is deliberately coarse rather than one source per cell, because
every emitter replicates to every client.

Verified in Studio (self-bomb temporarily allowed in Studio's in-memory DataModel
only — disk untouched, reverted after): **10 vapour sources** spawned, spread
**36 studs in X and 68 in Z** — the whole 72×72 interior — and the banner rendered
`visible=true` at y=96 with the attacker, action and detail all correct.

### Change — 2026-08-01 — C3: the street leaderboard is bigger and faces the road
It was a small 8×4 board tucked 16 studs off to one side, facing *across* the
street — easy to walk past and never read. It is now **20×10 (2.5× the size)**,
stands **beside the fountain at the plaza centre**, and is turned **90° so its
faces point along the boulevard**: you read it head-on walking up the street
instead of edge-on.

**Both faces carry the ranking**, so it reads from either end of the street rather
than having a blank back — `LeaderboardService` now rewrites every
`LeaderboardText` it finds instead of just the first.

The 🏆 and 🥇🥈🥉 emoji were rendering as tofu boxes in Roblox's UI font (the same
bug as the coin in C1), so the medals are now "1st / 2nd / 3rd".

Verified in Studio: board measures 20 × 10 at (217, 7.5, −30) — **13 studs from
the fountain** at (204, −30) — yaw 90°, spanning z −40→−20 which sits inside the
road (z −42→−18). Both `SurfaceGui`s show the live ranking.

### Change — 2026-08-01 — C1: the customisation menus show what you are buying
Owner feedback: *"the menu is ugly — for floor, window, façade etc don't show only
a text, show also the photo generated next to each item to show what that item
will give you, and show a coin with price next to it."*

Every option row in the Floor/Wall and Front pickers now carries a **drawn preview
swatch** and a **price chip with a real coin**. New `UI/StylePreview`.

The previews are **drawn from the same config the world renderer uses** — nested
Frames, no images — so a swatch can never drift from what actually gets built, and
adding a colour or motif needs no new art. Frames also cost far less than a
`ViewportFrame` per row, which matters for the phone build.

Each swatch previews the **result of picking it**, not the option in isolation: a
door style is drawn in YOUR wood, a window shape in YOUR glass, a motif in YOUR
colour, and a surface colour wearing the motif you have armed. The façade motif
swatch even draws the door notch, so it shows the rule that bands stop at the
opening. Architecture previews are silhouettes of their crown (striped awning /
stepped gable / flat cornice), and each wood draws its own grain count and tone.

The currently-applied option shows an **IN USE** chip instead of a price.

**The 🪙 emoji renders as a tofu box** in Roblox's UI font (confirmed in Studio —
it showed as `□ 250`), so the coin is now two drawn circles: guaranteed to render
everywhere and consistent with the procedural art direction. The three other
places that had a bare 🪙 in this UI were switched to plain text.

Verified in Studio: the Front picker builds 35 rows, **35 with a preview**, 28 with
a price chip and 7 marked IN USE (one per axis); the Floor/Wall picker shows each
colour wearing the armed motif with a `45 / 70` floor/wall chip. Confirmed
visually — the coin draws as a gold coin, not a box.

### Fix — 2026-07-31 — façade motifs no longer run across the door
Owner report, with the screenshot: the horizontal boards were drawn straight over
the doorway. Battens and boards are **cladding on the wall**, so they now stop at
the opening the way real cladding does — a plank does not cross a doorway.

- A horizontal band **below the door head** is emitted as the two wall segments
  either side of the opening; above the head it still runs the full width.
- A vertical batten that would land on the doorway is drawn **only from the door
  head up**, so the rhythm continues overhead without dressing the door.
- The wainscot band sits at waist height, so it always splits.
- A 0.9-stud `reveal` margin keeps a clean edge around the frame.

Verified in Studio on the hardest case — half-timbered, which has bands in BOTH
directions: **11 motif parts, 0 overlapping the doorway** (local x 46.5–54.3,
y 0–7.9). The count also proves the parts SPLIT rather than vanish: 4 battens +
7 boards, where the 3 bands below the door head each became two segments.

### Feature — 2026-07-31 — B4a: the façade picker
The B4 backend had no way to reach it. Build mode now has a **Front** tab beside
Floor/Wall, with one labelled row per axis — Architecture, Front colour, Front
motif, Door style, Door wood, Window shape, Glass — and the current choice
outlined. Colour and wood options preview themselves as their own swatch.

Each button sends **only its own axis**, because `SetFacade` accepts any subset:
one tap changes one thing and leaves the other six alone. Reusing the build
panel's existing list, scrolling and responsive layout meant no new panel,
DisplayOrder or modal plumbing.

Verified in Studio: the tab row renders all six categories (All · Appl. · Seating
· Decor · Floor/Wall · Front); the picker builds **8 headings and 35 option
buttons** — 3+8+6+6+6+3+3, exactly the catalogue; and clicking "Modern Flat" set
`facade.architecture = modern`, built the Cornice + CorniceLip crown and hid all
8 awning slats, leaving every other axis untouched.

### Feature — 2026-07-31 — B4: exterior personalisation (façade, door, windows)
The café front is the one thing every neighbour sees from the street, so it gets
the deepest customisation in the game — **seven independent axes**:

| Axis | Options |
| --- | --- |
| Architecture | **3** — Classic Awning · Cottage Gable · Modern Flat |
| Colour | **8** — Cream · Sage · Terracotta · Navy · Charcoal · Blush · Mustard · Mint |
| Motif | **6** — Plain · Vertical battens · Horizontal boards · Half-timbered · Wainscot · Pilasters |
| Door style | **6** — Slab · Two panel · Four panel · Arched · Cottage window · Barn cross |
| Door wood | **6** — Golden Oak · Dark Walnut · Pale Pine · Red Mahogany · White Ash · Smoked Ebony |
| Window shape | **3** — Squared · Rounded · Lozenge |
| Glass tint | **3** — Clear · Sea green · Amber |

That is **46,656 distinct café fronts** from ~35 rows of config. Independent axes
rather than a flat list of "themes" is what lets two cafés on the same street look
different without the config becoming thousands of rows.

The architecture axis genuinely changes the silhouette: the `crown` above the door
is either the striped canvas awning (which the other two hide), a stepped pitched
**gable**, or a flat **cornice** with a deep sill. The wood finishes are engine
material (`Wood` / `WoodPlanks`) + base colour + procedural grain lines, differing
in count and tone — pale ash has nine fine lines, mahogany three broad dark ones —
so they read as different timbers rather than recolours of one plank. Nothing is
imported (`docs/ART_DIRECTION.md`).

`FacadeService` **restyles** the front `CafeService` already built rather than
replacing that builder: it recolours the existing `WallFront` / `DoorLeaf` /
window parts and owns a `FacadeStyle` folder for its own decoration. All the
load-bearing geometry (door hinge, collision walls, sign) stays in one place, and
a restyle is a cheap repaint rather than a plot rebuild. Door panels and grain are
**welded** to the leaf, because the leaf swings.

New `Config/Facade`, `FacadeService`, `SetFacade` remote, `PlayerData.facade`.
`Facade.resolve` falls back **per axis**, so retiring one config entry degrades
that single choice instead of resetting somebody's whole café front.

Verified in Studio: a full seven-axis restyle (gable / navy / half-timbered /
arched / mahogany / lozenge / amber) persisted every axis and charged once.
Rendering measured: 4 battens + 4 boards for half-timbered (bands = 4), 7 gable
bars, 2 lozenge panes + 2 frames, all 8 awning slats hidden by the gable, door
recoloured to mahogany on `Enum.Material.Wood` with 5 trim parts (3 grain + panel
+ arch), every trim **unanchored and welded to the leaf** (`Part0 = DoorLeaf`), and
amber glass at transparency 0.25. Guards: unknown ids on any axis are dropped
rather than stored and are not charged; re-sending the same style is a no-op;
insufficient coins refuses.

⚠️ **No picker UI yet** — the remote, validation, persistence and rendering are
done and verified, but nothing in-game lets a player *choose* a style. That is the
next slice (tracked in ROADMAP).

### Feature — 2026-07-31 — B3: floor tiles + wall panels you buy and place
Players can now decorate the café itself, not just fill it with furniture. A new
**Floor/Wall** tab in Build mode arms a style; tapping the floor tiles that 1×1
cell, tapping a wall panels that segment full-height.

**8 colours × 5 motifs = 40 looks** out of thirteen rows of config — Cream, Sage,
Terracotta, Ocean, Charcoal, Blush, Honey, Mint, each crossed with Plain,
**Vertical lines**, **Horizontal lines**, Grid and Checker. Colour × motif rather
than one flat list means a new colour adds five looks and a new motif adds eight.
Every colour carries its own `ink` (the tone its lines are drawn in) — one global
line colour looked wrong on the dark tones, and letting players pick both would
have doubled the UI for nothing. Motifs are drawn from plain thin parts laid over
the base slab, so no textures are imported (`docs/ART_DIRECTION.md`).

Surfaces are a **separate layer from furniture**: they take no grid cells and are
`CanCollide = false` / `CanQuery = false`, so you can tile a floor that already
has tables on it, they never block walking, and they never intercept build mode's
own raycast. Painting is **pay-as-you-go** (45 🪙 a tile, 70 🪙 a panel) rather
than stocking tiles into an inventory nobody would want to manage.

Walls needed a **new raycast pass** — build mode filters to the floor, so wall
picking has its own pass against the shell's wall parts, converting the hit into
plot-local space to read off which wall and which segment. Walls are tested
**before** the floor, because a wall stands between the camera and the floor
behind it and would otherwise be unpaintable.

New `Config/Surfaces`, `SurfaceService`, `PaintSurface` remote, and
`PlayerData.surfaces` (top-level → `reconcile` heals old saves; the two sub-tables
are healed explicitly, like `socialOf`). Server-authoritative: the client sends a
cell and a style **id**, never a colour, and the price, bounds and spend all
happen server-side.

Verified in Studio: 3 floor tiles painted in different motifs persisted with the
right style ids and charged exactly 3 × 45 (coins 150 → 15); tile geometry
measured at 4 × 0.12 × 4 centred on the cell's true world centre (34, 0.06, 34)
with its top 0.12 above the café floor, non-colliding and non-queryable; band
counts matched each motif (vlines/hlines → 3 stripes, checker → 2 quarters, grid
→ 4). One panel on each wall mounted exactly on the inner faces — left x=0.56
against a 0.5 face, right x=71.44 against 71.5, back z=71.4 — at the full 12-stud
wall height. Guards: an unknown wall id, an unknown colour id and a non-integer
cell are silently rejected; index 99 and cell (500,500) return `out_of_bounds`;
too few coins returns `insufficient_coins`.

### Feature — 2026-07-31 — move furniture you have already placed
You could only ever pick an item back up and re-place it. Now, in Build mode,
**tapping a placed item picks it up to carry**; the next tap sets it down, and R
rotates it on the way — the ghost preview and rotation are the same ones normal
placement uses, so there is nothing new to learn. Picking something from the
catalogue cancels the carry, and a live hint line in the panel says what a tap
will do (build mode has three states and the ghost alone did not communicate
"you are carrying something").

New `MoveFurniture` remote, validated exactly like a placement with two
deliberate differences:
- The moving item is **excluded from its own overlap scan**. Without that, nudging
  a piece one cell would collide with the cell it is standing in, and every small
  adjustment — the common case — would be rejected.
- It does **not** re-pay the object cap, since it is not a new object.

Unlike removing, a move is **not** blocked while an appliance is cooking. Removing
a busy stove would destroy its batch; a move keeps the same `instanceId`, and the
cook is keyed to that id and runs on the wall clock, so it carries on untouched.
Guarding it would in practice have made appliances permanently unmovable, because
the automatic production loop holds a job on every enabled appliance almost
continuously (measured: the first attempt was refused with `busy_cooking`).

Verified in Studio: the seed espresso machine moved (4,3) → (12,9) with a new
rotation, then **nudged one cell to (12,10)** — the case that needs the
self-overlap exclusion — while its production job was live. The world model
followed to world (50, 42), the exact centre of grid (12,10), keeping
`instanceId = seed_coffee`. Guards: moving onto the occupied counter → `overlap`;
out of bounds → `out_of_bounds`; a foreign `instanceId` → silently ignored.
`placedFurniture` stayed at 2 throughout, so nothing was duplicated.

### Verified — 2026-07-31 — placement and rotation are correct (no change needed)
Checked before building on top of it, per the owner's ask. Placement and rotation
are already right: measured true world-space bounds (projecting every part's
corners onto the world axes — `GetBoundingBox`/`GetExtentsSize` return
*pivot-oriented* extents and cannot show this) against the reserved grid rect.
A 6×1 counter at rotation 0 rendered X 16.0→40.0 / Z 12.0→16.0 against a reserved
X 16→40 / Z 12→16, and at rotation 1 rendered X 8.0→12.0 / Z 48.0→72.0 against a
reserved X 8→12 / Z 48→72 — matching to the stud. All four rotations apply the
right visual yaw (`90 × rotation + assetYaw`). A catalogue audit also found no
non-square item locked to `rotatable = false`.

### Fix — 2026-07-31 — onboarding no longer dead-ends on step 2/6
The owner reported being **always stuck on step 2 of 6**. Step 2 was not broken —
it was **unreachable**. The only action that satisfied it was the AUTO toggle,
which lives on the pantry's **second tab** (AUTO PRODUCTION), while the step text
only said "Open 🥫 Pantry and choose what it makes" and the pantry opens on FRESH
STOCK — a list of stock numbers with nothing to choose. Players opened the
pantry, saw no way to "choose", and stopped.

Fixed on three fronts so it can't dead-end again:
- **The step text names the tab** ("Open 🥫 PANTRY → the AUTO PRODUCTION tab, and
  switch a dish ON").
- **The pantry opens on that tab** while the step is active (`InventoryController.
  openDrawer`), putting the player where the control is.
- **Tuning counts too** — `ProductionService` now fires `kitchen_tuned` when a
  target stock or priority changes, and the tutorial accepts it alongside the
  toggle. A player who fiddles with targets instead of the switch now advances.

Audited the other five steps rather than assuming: steps 1, 3, 4, 5 and 6 were all
fine, and their signals (`purchased`, the `PlazaCenter` workspace attribute) do
exist. Step 2 was the only dead-end.

Verified in Studio on a fresh profile, driven end-to-end: step 1 (place furniture)
→ **step 2 via the NEW signal alone** (`SetTargetStock`, which previously did
nothing) → step 3 (the waiter serves a customer) → steps 4+5 (buy + place a
decoration) → step 6 (walk to the plaza) → **`tutorialCompleted = true`** with the
completion reward paid.

### Feature — 2026-07-30 — P4: Robux store folded into UPGRADES + batch-output ladder
The separate "Store" rail button (P) is gone. The Robux catalogue now lives inside
the **UPGRADES** dock button — which was a "coming soon" stub — so the coin-bought
upgrades and the Robux ones sit in **one panel, side by side**. That adjacency is
the honest presentation of the rails: you can see both ways to get the same thing.

**New: the batch-output ladder — ×5 / ×10 / ×20.** Per the owner's spec, these
multiply what a batch **yields**, not what it sells for: "×5 to add 5 elements for
each item — 5 coffees, 5 teas — but only to the items that are unlocked". Applied
in `KitchenService.CompleteProduction`, the single funnel both automatic
production and manual collect pass through, and gated on
`data.unlockedRecipes[recipeId]`.

**Rails.** The owner chose PERMANENT tiers, which is only rails-clean because
**every tier is also buyable with coins** (25k / 120k / 500k) — Robux skips the
grind, it never buys power you cannot earn (HANDOFF §1). The coin path is fully
live now; each Robux button stays hidden until a real Product ID is pasted into
`Config/Products.yieldTiers`, so an un-created SKU can never show a dead buy
button. Server-authoritative throughout: the client sends only a tier number, and
the price, the strict one-rung-at-a-time ordering and the spend all happen on the
server. `ProcessReceipt` stays idempotent and now also resolves yield-tier
products; a grant is `math.max`, so it can never downgrade you.

New `PlayerData.yieldTier` (top-level → `reconcile` heals old saves, and the heal
clamps to a real tier so a corrupt value can't grant an unearned multiplier) and a
`BuyYieldTier` remote.

⚠️ **Economy follow-up:** a permanent ×20 yield is a 20× income ceiling. The
per-recipe cap (`Kitchen.maxStockPerRecipe` = 99) throttles it in practice, but
the coin economy wants a rebalance pass once this is live — flagged in ROADMAP.

Verified in Studio: the Store rail button is gone (rail is Goals/Trophies/Map/
Music/Settings) and `UpgradesPanel` replaces `RobuxShopPanel`; the panel renders
BATCH OUTPUT first with all three coin prices, then the dev products, then VIP
(showing an OWNED chip, since the account owns its own pass in Studio). Guards:
buying tier 2 first → "Buy the previous upgrade first"; tier 1 without funds →
"Not enough coins — 25000 🪙 needed"; tier 99 and tier 1.5 → silently ignored;
`yieldTier` stayed 0 through all of it. With the price temporarily cheapened **in
Studio's in-memory DataModel only** (disk untouched, reverted after): coins
233 → 183 (exactly −50), tier 0 → 1, and a re-buy was refused without
double-charging. The multiplier then measured **+5 stock per batch** (produced
0 → 5 → 10, espresso 3 → 8 → 13).

### Feature — 2026-07-30 — P3: the VIP is a scheduled event with a HUD countdown
The brainrot VIP used to drop in on a random 4–8 minute timer, so nobody could
plan for it and half the visits went unnoticed. It is now a **fixed 30-minute
server event** with a **countdown everyone can see**: a pill under the gift timer
showing the **brainrot's own picture** (an `rbxthumb` of the real asset, so
there's no second image to keep in sync) and the time remaining. When it lands,
the whole street is told which café it chose — the countdown resolves into
something visible rather than a private surprise.

The clock is the SERVER's (`workspace:GetServerTimeNow`), so every client agrees
and a mid-cycle joiner is sent the countdown on `PlayerAdded` rather than waiting
for the next tick. A failed attempt (nobody open, a VIP already out, assets still
loading) retries in 60s instead of burning the whole 30-minute slot. New
`VipEvent` remote and `VipEventController`.

**The NPC is much bigger** — `Vip.modelHeight` / `AssetManifest.vip.height` 3 →
5.5, `hipHeight` 1.6 → 2.9. It was previously *shorter* than an ordinary customer;
it now stands taller than one. It still clears the 7-stud door with 1.5 studs to
spare — do not raise it past ~6 without raising the door too.

Verified in Studio (interval temporarily fast-forwarded in Studio's in-memory
DataModel only — disk untouched, reverted after): the pill renders at top-right
below the gift timer with the real brainrot thumbnail and counts down correctly
(0:19 → 0:13 over six seconds); the event fires, spawns the VIP through
`CustomerService:SpawnVip`, broadcasts `arrived cafe=aloulouba1` to every client,
and reschedules. Measured VIP height **5.57** studs against a normal customer's
**4.97**, `HipHeight` 2.94.

⚠️ **For the owner's eye:** the scaled model's bounding box is ~9.4 studs WIDE
against a 6-stud doorway, so it will visually clip the frame on the way in. It is
not physically blocked — only the invisible 2×2×1 root collides — but if it looks
wrong, lower `Vip.modelHeight` (width scales with it) or widen `World.doorWidth`.

### Change — 2026-07-30 — P2c: help a neighbour by WORKING, not by tapping a card
Helping was a card of four buttons — "water plants", "bus a table", "stir a pot",
"hand flyers" — none of which were real things happening in the world, each
once-per-neighbour-per-day, so the whole social loop was **four taps**. All of it
is gone: `SocialService.HELP_ACTIONS`, the `NeighbourHelp` remote, and the
compliment whitelist with it.

Helping is now the actual job. Walk **inside** a neighbour's café and do what the
owner does — **scrub the floor**, **clear a dirty plate**, **carry an order from
the shelf to the right table**. Those prompts were gated to the owner with
`who == player`; they now ask **`SocialService:TryWork(who, owner, action)`**,
which authorises the presser and pays a visiting helper per job (10/12/22 coins,
plus friendship and the Good Neighbour daily bonus). Past
`maxPaidActionsPerNeighbourPerDay` (15) the actions still **work** — you can keep
helping a friend — they just stop paying, so there is nothing to farm. Tuning
lives in the new `Config/Neighbour`.

The helper's fee is **minted for them, never taken from the owner**: the café
keeps its whole sale, its Buzz and its satisfaction, so being helped is pure
upside. `OrderService.pickupOrder`/`deliverOrder` now separate **whose café it
is** (`player` — the stock, the payout, the customer) from **whose hands are
doing it** (`worker` — carries the plate, must reach the shelf, gets the
delivery burst). `CanWork` authorises without paying, used for pickup, since
fetching a plate is only worth something once it reaches the table.
`PlayerData.social.helpLog` changes shape from `{[actionId] = day}` to
`{day, count}`; an old row simply has no `day`, which reads as a new day.

Verified in Studio: clean boot with 22 services after the remote removal, no
errors, no dangling client references. The **owner's own serve loop still works
end-to-end through the refactored prompts** — E at the shelf took stock 4 → 3 and
consumed the pickup prompt, E at the table paid out (coins 212 → 218, served
2 → 3, Buzz 6 → 8) — which also proves `TryWork` short-circuits true for the
owner. Analytics confirms the split is live: `customer_served {"helped":false}`.
The visit card now shows the three real actions plus an explainer instead of the
seven removed buttons. **Still owed: the 2-player pass** for a visitor actually
being paid.

**Left out of this PR: cooking as a visitor.** Starting a cook spends the
*owner's* coins and pantry, so opening it to a visitor is a griefing vector that
needs its own guardrails rather than the same `TryWork` gate — and with
`Kitchen.autoCollectCooks` on there is no physical collect ritual to open anyway.
Tracked in ROADMAP as a follow-up.

### Change — 2026-07-30 — P2b: the smell bomb now CLEARS a neighbour's café
The smell bomb was a second way to *pull* one customer to you. It is now **area
denial**: every customer in the neighbour's café walks out, and **nobody
transfers to the caster** — pulling is what `recruit` is for, and the two now do
genuinely different things. The green vapour is thrown **under the caster's own
feet** rather than at the café, so it is obvious who set it off.

New `CustomerService.ScareAll`, which routes everyone through the existing
`leaving` path — that cancels any order, frees the seat, and walks them to the
street with **no Buzz, satisfaction or reputation penalty** (an angry walkout, by
contrast, costs all three). VIPs resist, as they do every other mischief, and
anyone already **served keeps the meal they paid for**. The bomb is only spent if
it actually cleared someone, so it is never wasted on an empty room. The existing
cooldown and per-victim cap are shared with the pull, so a café cannot be farmed
by alternating the two. `handleLure` is now recruit-only and no longer carries
dead smell-bomb branches.

Verified in Studio (self-bomb temporarily allowed in Studio's in-memory DataModel
only — disk untouched, reverted after): a roomful of 4 customers all fled and the
toast read "4 customers fled their café"; the bomb decremented 2 → 1 → 0; the
vapour landed **0.02 studs horizontally and 1.50 studs below** the caster's
HumanoidRootPart, i.e. at their feet. The rails check needed a second run — the
first showed Buzz −2 / satisfaction −8, which turned out to be the pre-existing
"😡 NO EMPTY CHAIR!" storm-out (the default in-memory profile has no chairs), not
the bomb. After placing a table and two chairs via the `PlaceFurniture` remote,
the clean measurement was **Buzz 6 → 6 and satisfaction 70.00 → 70.00** across a
bomb that emptied the room. **Still owed: the 2-player pass.**

### Feature — 2026-07-30 — P2a: steal an item off a neighbour's wall shelf
The first of the three REAL neighbour actions replacing the old card of abstract
buttons. Choosing "🫳 Steal an item" at a neighbour's café does **not** take
anything — it lists what they have in stock and then **lights up that item's wall
shelf and puts a prompt on it**. You still have to walk over and press **E** at
the shelf. The item then genuinely leaves their café and arrives in yours, and
**the victim is told who took it** ("<name> stole 1× Espresso from your café!").

Guardrails mirror `MischiefService`'s lure ladder, on their own timers so the two
actions can't block each other: a 90s per-thief cooldown, a 3-items-per-5-minutes
per-victim cap (counted across all thieves, so nobody can be farmed), a
must-be-at-the-shelf proximity check measured against the shelf part itself, a
30s arming window, and a visible green vapour puff at the shelf — no silent
theft. All server-authoritative and behind `Mischief.theftEnabled`.

New: `KitchenService.AddStolenServing` / `CanReceiveServing` (deliberately NOT
`CompleteProduction` — the thief didn't cook it, so there is no XP, mastery, goal
credit or produced-stat; the item just changes hands), a `NeighbourStock`
RemoteFunction that returns the shelf **part** per row so the client never guesses
an instance path, and `steal` as a fourth method on the existing `Mischief` remote.
Stealing is limited to recipes the thief has also unlocked — otherwise the stock
would have no shelf to sit on and no menu slot to sell from, i.e. dead weight.

Verified in Studio: the guard ladder returns the right refusal for own-café,
empty-plot, malformed and out-of-range attempts (and stays silent on malformed
payloads); `GetShelfPart` resolves to the real `Shelf_espresso/Ledge`; the
telegraph spawns at the shelf (70, 4.9, 22 = shelf + Fx's lift) with a live
emitter; the cooldown counts down and blocks (20s → 11s → 3s → success → 82s).
The transfer itself was proven by temporarily lifting the self-steal block **in
Studio's in-memory DataModel only** (disk untouched, reverted after) and stealing
from an own shelf: the FIFO-oldest lot went 3 → 2 and a **new** 1-unit lot with a
fresh expiry appeared, while `stats.produced` stayed at 1 — exactly the intended
"changes hands, isn't cooked" behaviour. **Still owed: the 2-player pass** where
the victim is a different player (same limitation as C-4a/4b).

Note: the compliment card and `SocialService.HELP_ACTIONS` are still in place —
they are removed in **P2c**, which is the PR that replaces what they did.

### Fix — 2026-07-30 — grass no longer bleeds up through the road
The owner reported (with a screenshot) green grass showing through and under the
road. Cause: the grass island spans the WHOLE neighbourhood, including the ground
beneath the boulevard, and its top face sat at y −0.20 against a road top of
−0.22 — **0.02 studs ABOVE the tarmac**. The grass therefore won the depth test
wherever the two overlapped, so the near half of the street rendered as a green
field (the far half flipped back to road as depth precision degraded, which is
the hard horizontal seam across the road in the screenshot).

`CafeService` now declares the outdoor surface stack as four named constants
(`GRASS_TOP` −0.70, `ROAD_TOP` −0.22, `SIDEWALK_TOP` −0.13, `PAVING_THICKNESS`
0.9) with the ordering written down, instead of four unexplained magic offsets
spread across two builders. The grass drops to a **kerb height below the paving**,
and the road/sidewalk slabs are correspondingly **deep (0.9 studs)** so their
undersides (−1.12 / −1.03) reach well past the grass top: the kerb is a solid
step down, never a floating slab with daylight under its edge.

Verified in Studio by measurement, not by eye: grass top −0.700 vs road top
−0.220 (0.48 clearance) and paving undersides 0.33–0.42 studs *below* the grass
top; a sweep of every near-ground slab confirmed nothing floats over bare grass
(plaza disc, garden paths, visit pads and street decor all rest on plot floors or
paving, which themselves reach past the grass top); the sea (top −2.10) still
clears the lowered grass underside (−1.70). Clean boot, no errors. Screenshots
from two angles show the road reading solid with zero green bleed.

### Feature — 2026-07-27 — intro/onboarding, advanced sky, cleaner health strip
Three owner-requested polish items:
- **First-run intro** (`IntroController`) — a full-screen welcome shown from the
  first frame (built in `Init`, before any HUD) that MASKS the initial asset load +
  café render while you **name your café**, then fades out to reveal you standing
  in front of your own café door. The server fires a new `WorldReady` remote once
  the café is built + Creator-Store assets are loaded; only then does "Enter my
  café" light up. Player controls are frozen behind the overlay. (Café STYLE choices
  will slot into the same panel later.)
- **Advanced sky** — deleted the old flat cloud-TEXTURE backdrop walls
  (`buildSkyBackdrop`) and switched to the modern engine technique: a `Sky` skybox +
  `Atmosphere` + **volumetric Terrain `Clouds`** that drift and light with the sun.
- **Café-health strip redesigned** — the ugly 2×2 dark card is now four slim,
  rounded pills (😊 ✨ ☕ 🍽️ with a coloured fill + %) at the EXTREME top-centre, so
  it never covers the café or dishes (`OperationsController` + `ResponsiveLayout`).

Verified in Studio: clean boot, no errors; the intro overlay reliably appears on the
first play after a fresh launch, "Enter my café" enables on `WorldReady`, typing a
name + clicking it saves the name (sign → "👑 Sunset Brew"), fades the overlay, and
reveals the player in front of the café (50, 3, -14); the new health pills render at
the top-centre; the sky backdrop walls are gone. The Clouds look is the owner's
eyeball (the fixed café-sim camera can't frame the sky).

### Feature — 2026-07-26 — player-named cafés (typed, filtered)
Players can now name their own café (owner request). A **"Name your café"** prompt on
your own doormat opens a small text-box panel; the typed name is sent to the server
(`SetCafeName`), which **trims, length-caps (22), and runs it through Roblox's
`TextService` filter** — mandatory for any player text shown to others — before it is
stored (`PlayerData.cafeName`, top-level) and painted on the street sign
(`cafeSignName`: custom name if set, else "<DisplayName>'s Café", with the VIP 👑
still prefixed). Rate-limited; a name that can't be filtered is rejected (in Studio,
where the moderation service is unreachable, an unfiltered name is allowed **only**
for local testing). New `CafeNameController` (prompt + panel), `SetCafeName` remote.
Verified in Studio: firing `SetCafeName("  The Cosy Bean  ")` trimmed + stored the
name, repainted the sign to "👑 The Cosy Bean · 🔥 Buzz 8", and the rename prompt is
attached to the owner's plot.

### Feature — 2026-07-26 — world aesthetics pass + spawn/sign fixes
Owner-requested visual polish for the neighbourhood (docs/SESSION_HANDOFF.md):
- **Natural sky + sun** — a real `Sky` (default cloud cubemap + a bigger sun disc,
  `SunAngularSize` 19), a brighter midday `ClockTime`, and a much lighter Atmosphere
  so the sky reads clear blue instead of a heavy golden wash.
- **Sea + grass island** — a grass base fills the bare ground between plots and
  around the boulevard, with a Water sea stretching to the horizon beyond it (new
  `buildGroundAndSea`); no more grey void at the map edges.
- **More trees** — boulevard trees on BOTH sidewalks and denser, plus two extra
  trees in each back garden.
- **Café sign fixed** — the front decor sign rendered upside down (+90° about X);
  now -90°, upright and facing the street.
- **Spawn fixed** — players spawned on the café's corner WALL (the default (0,0,0)
  spawn) because the profile loads instantly in Studio and a single teleport was
  overridden by Roblox's own spawn-repositioning. Now connect-first + re-assert the
  target CFrame across a few frames → the player reliably lands on the sidewalk in
  front of their door, facing in.
- **Cozier café** — interior depth reduced ({24,28,32} → {18,24,30} cells): the base
  café is a roughly square 72×72 instead of a deep empty hall, with a bigger garden.

Verified in Studio: clean boot, no errors; the player spawns in front of the café
(50.5, 3, -13.9) not the wall; the café is 72×72 and seating still works (a customer
sat + ordered); the Sky/Sea/grass/trees are all built (the fixed café-sim camera
can't frame the sky, so the final look is the owner's eyeball). Player café-naming
follows as a separate PR.

### Feature — 2026-07-26 — Phase D: monetisation completion (boost pill · VIP perks · Auto-Collect removed)
Finished the rails-clean Robux monetisation (docs/MONETISATION.md). The core was
already built (idempotent `ProcessReceipt`, working 2× boosts, the full Store UI,
the VIP offline-cap); this completes it:
- **Boost-timer HUD pill** — the visible boost the design asks for ("2× Coins ·
  43:12"). New `BoostController` reads the `PlayerData.boosts` expiries and stacks
  one small pill per active boost top-right, under the session-gift pill. Display
  only — `EconomyService` already applies the 2×.
- **VIP Membership perks wired** (server-authoritative, gated on `ownedPasses.vip`):
  **+50% session/playtime gift** (the pass's "daily bonus", in `SessionRewardService`),
  **faster walk** (WalkSpeed 20 on spawn, re-applied the instant the pass flag
  lands), and a **👑 badge on the café sign**. (Offline cap 8h→12h was already done.
  Deferred: unique name colour; "larger ingredient storage" is N/A — the pantry has
  no cap.) New `Config/Products.vipPerks` tuning. Rails: convenience + cosmetic only.
- **Auto-Collect pass removed** (owner decision): auto-collect is free for everyone
  via `Kitchen.autoCollectCooks`, so the R$149 pass was a redundant SKU — nothing
  gated on it. VIP is now the sole flagship pass.

Verified in Studio (in-memory, VIP seeded): clean boot (22 services, 17 controllers,
no errors); the Store shows no Auto-Collect (only VIP; order count 8); a VIP owner
got WalkSpeed 20, the "👑 …'s Café" sign, and a 135-coin connect gift (= 90 × 1.5);
both boost pills rendered, counted down, and stacked under the gift pill. The owner
confirmed the product/pass IDs are real, so a live purchase test follows publish.

### Feature — 2026-07-26 — Phase C-4b: mischief (smell bomb + recruit)
The competitive social mechanic (docs/GAMEPLAY_DIRECTION.md §4b, IMPLEMENTATION_MAP
"Feature 4 / 4b") — the ONE rails-BRUSHING feature, owner-approved and built with
the FULL guardrails. Two ways to pull a WAITING customer from a neighbour to your
café, both on the neighbour visit card:
- **Smell Bomb** — a coin-bought consumable (`Config/Mischief.bombCost`);
  GUARANTEED if an eligible customer exists; big green vapour telegraph.
- **Recruit** — free; success scales with your REPUTATION.

Both route through the new **`MischiefService`** (one method-tagged `Mischief`
remote) which enforces EVERY guardrail server-side: bought consumable + per-caster
**cooldown**, **proximity** to the target, only **not-yet-served / un-seated /
non-VIP** customers (**VIPs resist**), per-customer **immunity** + a per-victim
**max-stolen cap** per window, and a **visible** green **`Fx.smellVapour`**
telegraph. The pull is `CustomerService:LureOne` — the victim's customer leaves
CALMLY (no Buzz / coin / satisfaction penalty → **no permanent loss**, and capped)
and a fresh, temporarily lure-immune walk-in appears at the caster's café (the
normal spawn, extracted to a shared `spawnWalkIn`). New top-level
`PlayerData.smellBombs` (reconcile heals old saves; `startingBombs` starter).
Ships behind `Config/Mischief.enabled`.

Verified in Studio (in-memory, solo): clean boot (22 services, no errors); buying
a bomb spent 150 coins + added one (persisted); the guard ladder blocked
self-poach (bomb NOT consumed) and an empty plot; the green vapour telegraph
rendered + self-cleaned; normal customers still spawn via the refactored
`spawnWalkIn`. The full cross-player lure needs a 2-player playtest (same
limitation as §4a).

### Fix — 2026-07-26 — three owner-reported bugs (seating, VIP customer, session gifts)
The three bugs the owner found (docs/SESSION_HANDOFF.md §3), fixed end-to-end:

- **Seating: customers no longer wait while chairs sit empty.**
  `CustomerService.claimSeat` tracked occupancy in a mutable `occupiedSeats`
  side-table that permanently LEAKED a chair whenever a customer coroutine ended
  without reaching `releaseSeat` (an error mid-visit, a furniture re-place that
  changes instanceIds, a player leaving) — the seat stayed "taken" forever, so
  arrivals found the café full while the chairs were empty. Occupancy is now
  DERIVED from the live diners on every scan (`occupiedSeatIds` over
  `allCustomers`), so it cannot drift and a genuinely-free chair is always taken.
- **Brainrot VIP now behaves like a normal customer** (was served INSTANTLY on a
  standalone path). It spawns THROUGH `CustomerService` as a special customer
  (`CustomerService:SpawnVip`): enters → sits in an empty chair → orders a RARE
  dish (the priciest UNLOCKED, on-menu, non-Coffee/Tea recipe; falls back to the
  priciest drink if the café has only drinks) → WAITS to be served (owner or
  waiter) → leaves the earned gift box at its table. `VipService` is now only the
  scheduler (scores every open café by Buzz, hands the #1 to `SpawnVip`); its
  instant-serve walker + gift code is gone. One VIP server-wide at a time (guard +
  failsafe despawn so a dead coroutine can't strand the slot).
- **NEW: session + 15-minute playtime gift with a HUD countdown.** A gift lands the
  moment you connect and again for every 15 min of connected play, with a live
  countdown pill top-right ("🎁 Next gift · 12:04") and a toast as each one lands.
  New `SessionRewardService` (server owns the clock + grant),
  `SessionRewardController` (the pill, fed the next-gift server time),
  `Config/SessionRewards` (interval + weighted reward table), and a `SessionReward`
  remote. `RewardMath.rollReward` is the generic weighted roller now (the VIP box +
  session gifts share it; `rollGift` delegates to it). Rails-clean: EARNED by play,
  never paid, no fake urgency, odds never touch money (HANDOFF §1).

Verified live in Studio (in-memory, temporarily fast intervals): clean boot (21
services, no errors); the connect gift + repeating playtime gifts fired (coins AND
reputation) with the countdown pill visible top-right; a normal customer AND the VIP
both sat in placed chairs; the VIP ordered → waited → was served by the waiter →
dropped its gift box at the table; a third customer was turned away only when both
chairs were held by live diners. Rare-dish selection checked against real recipe data
(full menu → quiche $48; drinks-only café → tea fallback).

### Feature — 2026-07-26 — Phase C 4a: neighbour help + friendships
Co-op social layer (docs/GAMEPLAY_DIRECTION.md §4a). Visit an **online** neighbour
and lend a hand from the visit card:
- New **`NeighbourHelp`** remote + `SocialService.handleHelp` (mirrors the
  compliment guard ladder). Data-driven `HELP_ACTIONS`: Water Plants, Bus a Table,
  Stir a Pot, Hand Flyers — each **once per neighbour per day** (persisted
  anti-farm on `PlayerData.social`, survives rejoin).
- The helper earns coins/XP/reputation + **friendship points** (persisted
  per-pair); the online owner gets reputation and/or a Buzz bump. A
  first-help-of-the-day **"Good Neighbour"** bonus. Rails-clean (whitelisted
  actions, no free text).
- New `PlayerData.social` `{friendship, helpLog, lastGoodNeighbourDay}` (top-level
  → `reconcile` heals old saves; `socialOf` heals sub-tables).
- Client: a **"Lend a hand"** section of help buttons in the neighbour visit card.
Verified in Studio: remote + handler wired (self-block guard fired live), `social`
field present + defaulted, clean boot, no errors. The full 2-player
help→reward→friendship path needs a real 2-player playtest.

### Feature — 2026-07-26 — VIP enters + orders the fanciest dish; lobby Buzz leaderboard
Owner revisions to the brainrot VIP, plus a new leaderboard:
- **VIP now enters the café**: scaled down to fit the 6-stud door, it walks INSIDE,
  orders the **fanciest UNLOCKED dish** (highest menu price) served **INSTANTLY**
  (owner paid `basePrice × 4` for it), eats, and leaves the earned gift box by the
  table (inside). Appears rarely now (every 4–8 min).
- **Lobby Buzz leaderboard** on the plaza board (new `LeaderboardService`): ranks
  every open café by Buzz ("boost") with medals for the top 3, refreshed every 5s.
  The VIP walks to **#1** (already the highest-Buzz café). Read-only, rails-clean.
Verified in Studio: board shows `🥇 #1 by Buzz`; the VIP walks inside and its gift
drops at the interior table (z=12); `vip_served` logs the dish + premium (espresso
→ +48 = 12×4); 20 services, clean boot, no errors.

### Feature — 2026-07-26 — shelves: bigger + pick food from the shelf (not the counter)
Owner feedback on the wall food shelves:
- **Bigger + clearer**: each shelf's dish prop is scaled 1.8× and the quantity is
  a bold `GothamBlack` pill on an **always-on-top** billboard, so the food + count
  read across the room. Ledge/back enlarged, columns spaced further apart.
- **Pick from the shelf, not the counter**: an order's pickup now spawns in front
  of that recipe's wall shelf (`KitchenService.GetShelfPart` → OrderService
  `pickupAnchorCf`/`isNearPickup`); the old kitchen-pass pickup is removed (kept
  only as a fallback if a shelf isn't built yet). Table delivery and the waiter's
  auto-serve (which already consumes shelf stock) are unchanged.
Verified in Studio: shelves build bigger (espresso prop 2.3×3.6 vs 1.3×2.0), new
shelves appear on unlock (cappuccino/sandwich), the pickup anchor computes to the
shelf front, clean ~5-min run with no errors. Live owner-pickup pending a real
playtest (idle test Buzz was ~0, so almost no customers spawned).

### Feature — 2026-07-26 — Phase B: brainrot VIP customer + earned gift box
The first Phase B feature (docs/GAMEPLAY_DIRECTION.md §3). A rare "brainrot"
celebrity (owner-chosen Creator Store asset 112586636995159) walks the boulevard
to the busiest café on the server and leaves an EARNED gift box:
- **New server-level `VipService`** (not a per-café branch): on a 90–180s timer it
  scores every OPEN café by Buzz, picks the busiest, and struts one VIP to its
  entrance. Pays the owner a premium order (+coins/+rep), then drops a gift box the
  owner opens with E for a weighted reward. One VIP at a time; own
  `workspace.VipGuests` folder; gated on `Config/Vip.enabled`.
- **The brainrot is a non-humanoid display model** (AnimationController, no
  Humanoid), so AssetLibraryService loads it as a scaled, **script-stripped** prop
  (`GetVip`) and VipService welds it onto an invisible Humanoid to walk it with
  NpcNav — kept OUTSIDE at the entrance (too wide for the door; the direction
  allows "table or café entrance").
- **`Config/Gifts`** weighted reward table (coins/reputation now; furniture / skins
  / crates / boosts append as rows) rolled by `RewardMath.rollGift`. A GIFT, not a
  loot box: earned by play, opened for free — odds never touch money (HANDOFF §1).
- **`Config/Vip`** holds all cadence / scoring / premium / model-scale tuning.
Verified in Studio: the VIP scored the café by Buzz, walked in, paid +120 coins,
and dropped an owner-only gift box; `rollGift` distribution correct; clean boot,
no errors. Brainrot scale/offset are config knobs to tune by eye in a playtest.

### Feature — 2026-07-26 — auto-collect finished cooks + wall food shelves
Two owner requests:
- **Auto-collect finished cooks.** A finished manual cook now drops straight into
  stock the moment its timer ends — no more walking over to Collect. The 1s
  kitchen tick performs it (always prompt, so the fresh bonus always lands);
  `handleCollectCook`'s grant body was extracted into a shared `finishCook` used
  by both the manual remote and the tick. Config flag `Kitchen.autoCollectCooks`
  (default on). *Note: this makes the Auto-Collect gamepass redundant — repurpose
  it in the Phase D monetisation pass.*
- **Wall food shelves.** Instead of piling every dish on the service counter, each
  UNLOCKED recipe gets its own shelf on the wall opposite the front kitchen — a
  permanent food prop + a live "xN" count + the dish name. Shelves appear as
  recipes unlock and read front→back by level; the counter no longer shows the
  pile. New `refreshFoodShelves` / `buildShelf` in KitchenService (props cloned
  once, counts relabelled on refresh); refreshed on join, on unlock
  (`ProgressionService`), and on every stock change. Config flag
  `Kitchen.useFoodShelves` (default on). Placement/scale are tunable constants.
Verified in Studio: a manual cook auto-collected (`batch_collected` fired from the
tick with no click, machine returned to idle), shelves built with correct
props/counts/positions, clean boot, TestEZ 87 pass.

### Balance — 2026-07-25 — production per-serving margins fixed
The auto-production plan draws a recipe's `ingredients` table per **single
serving**, but the tables were authored per-batch, so with `enforceIngredients` +
`useProductionPlan` live the cheapest recipes served at a **0-coin margin** (House
Tea, Garden Iced Tea) or +1 (Espresso). Contained fix — income level unchanged
(a serving still pays ½ the menu price):
- `Config/Recipes` — ingredient tables retuned to genuine **per-serving** amounts;
  `ingredientCost` realigned to the per-serving market value; small menu-price
  nudges (House Tea 10→12, Garden Iced Tea 16→18, Croissant 22→24). `slow_roast`
  stays per-batch (8h appointment, never in the plan).
- `Config/Ingredients` — Cheese and Ham (tagged *common*) 3→2 to match the other
  commons.
- Every plan recipe now nets **42–58%** per serving (50–65% with bulk buying), no
  break-even recipes; verified in Studio (TestEZ 87✓ + clean live boot).
- `tests/Recipes.spec.luau` (new) locks in the invariant so a future edit can
  never reship a break-even recipe. Docs: `CORE_LOOP_SPEC` §1/§4e, `ECONOMY_BALANCE`.

### Docs — 2026-07-23 — gameplay direction set to the owner's chosen features
`docs/GAMEPLAY_DIRECTION.md` rewritten from a menu of options into the committed
next-build spec, each feature named against the service it hooks into:
- **Staff you hire and upgrade** — café starts with only a Barista and Waiter;
  the Staff panel hires the locked Cook/Cleaner (blurred photo when locked) and
  upgrades each in 10% steps that raise capacity, with a level-up effect on the
  NPC. Grounded: `StaffMember` already has `level`, `staffCapacity` is already
  per-role, `starterStaff()` seeds the four.
- **Ingredients bought in bulk at the market** — recipes consume real pantry
  stock; running dry stops production. **Art coverage confirmed: all 14
  ingredients** (11 direct Kenney Food Kit CC0 renders + 3 recolours), rendered
  and proven in a proof sheet. Nothing to buy.
- **VIP customers** — spawn in the lobby, walk to the busiest café on the server,
  leave an *earned* gift box (never a paid random box). Owner supplies the model.
- **Neighbour help** (co-op, extends `SocialService`'s anti-farm) and the
  **smell bomb** (competitive customer-steal) — the smell bomb brushes the ethics
  rails, so the doc spells out the guard rails and flags it for owner sign-off.
- **Monetisation suggestions** — cosmetics-first; the owner's asks (Robux staff/
  upgrades/ingredients/boosters) framed honestly as accelerators-not-power, with
  the pay-to-win line drawn and idempotent `ProcessReceipt` required.

The next-session prompt in `docs/SESSION_HANDOFF.md` now points at this spec.

### Docs — 2026-07-22 — handoff rewritten around what the game actually is
- **`docs/GAMEPLAY_DIRECTION.md` (new)** — the loop read out of the services
  rather than the design docs: the nine things a player can physically do, and
  the two findings behind them. **There are no ingredients** — `ingredientCost`
  is a coin deduction with no item, no stock and no supplier anywhere in the
  codebase — and **the game automates away its own gameplay**, because staff
  progressively remove every physical action. Ends with seven ranked mechanics
  inside the ethics rails and an explicit "do not build yet" list.
- **`docs/SESSION_HANDOFF.md`** — rewritten. Adds a "hard-won facts" section so
  the next session does not re-derive them: `rbxthumb` serves only 150 and 420,
  Roblox has no GUI blur, Roblox does not fetch images it is not rendering,
  automatic production monopolises appliances (`stove_busy`), MCP cannot reach
  the running singletons, and generated icon sheets are not really transparent.
- **`HANDOFF.md`** — the UI section described a "compact tycoon UI" with a
  collapsed action menu and blank `Theme.Images`, none of which is true since
  the HUD rebuild; the platform line still said 30 plots. Both corrected, the
  bootstrap prompt rewritten, and §6 now leads with the honest priority: the
  biggest gap is design, not polish.

### Fixed — 2026-07-22 — the tutorial dead-ended on step 2
Owner report: "it only stops at step 2 even though I did it." It was not a
detection bug — **the step was impossible**.

Step 2 asked for the brew timing minigame, which needs a *live order*; once a
waiter is on shift, orders are served automatically before the player can reach
the machine. Retargeting it to cook-by-hand does not help either: the automatic
production loop holds a job on the appliance, so a manual `StartCook` answers
`stove_busy` — measured live, on the seed café's only coffee machine.

Step 2 is now the **menu**, which is the player's real lever over a cook-ahead
kitchen and is always available: *"Your kitchen cooks on its own. Open Pantry
and choose what it makes."* `ProductionService` emits a `menu_changed` notify so
the tutorial has a signal it can attribute to the player; collecting a batch or
landing the brew minigame still count for anyone who catches an idle appliance.
Step 3's text also stopped describing a "green Serve button" that no longer
exists — the flow is pick up at the pass, then carry to the table.

Verified live end to end: 1 → 2 → 3 → 6 with no dead end.

### Changed — 2026-07-22 — HUD rearranged and rebadged (owner request)
- **Camera pad hidden on desktop.** The Q/E/+/− cluster duplicated the keyboard
  and the scroll wheel and owned the top-left corner. It stays on touch, where
  it is the *only* way to rotate the camera.
- **Café health bars moved to top-centre** (SAT / CLEAN / BARISTA / WAITER).
  Narrow viewports still drop them into the left column, and the camera pad
  reads the same shared geometry so the two cannot overlap.
- **Tutorial card moved to the top-left corner** it freed, below Roblox's own
  top bar — at the obvious y=8 the platform's menu and chat buttons sit on top
  of it and it cannot be read.
- **New button art** from the owner's icon sheet: Build, Staff, Shop, Upgrades,
  Goals, Trophies, Music, and the Money / Reputation / Buzz pills. Tinting is
  now opt-out (`Graphics.UIFullColour`) so full-colour art keeps its palette
  while the flat CC0 glyphs are still recoloured per surface, and a colour pill
  icon replaces its coloured disc rather than sitting on it.
  `Cookbook`, `Map` and `Settings` arrived on a second sheet, so **every** HUD
  button and stat pill is now on the owner's art — no mixed styles left. The
  muted-music icon is derived from the owner's own music note (desaturated and
  dimmed) rather than falling back to a flat glyph.
- `scripts/slice_icon_sheet.py` takes `--rows/--cols/--names`, so the next sheet
  is one command.

### Changed — 2026-07-22 — furniture renders 1.5× bigger; round table is one cell
Owner request: placed furniture read too small next to a character, and a round
table should occupy a single cell so chairs sit square against it.

- **`AssetManifest.displayScale = 1.5`** — one number scales every placed piece.
  It multiplies both `height` and `maxSpan`, because height alone gets undone by
  the span clamp that keeps a model inside its footprint. The procedural greybox
  fallback scales by the same figure, growing from the floor so it neither sinks
  nor hovers, and grid footprints are deliberately **not** scaled — a piece may
  now overhang its cells, which is what makes a room look furnished.
- **`table_round` is 1×1** (was 2×2). The four orthogonally adjacent cells are
  now exactly the four chair positions. Measured live: each chair sits **4.00
  studs** from the table centre with a **+0.07 to +0.14 stud** edge gap — tucked
  in, not clipping. `BuildService.autoFaceSeats` already turns each chair to
  face the table, so a set snaps together with no fiddling.
- **The counter keeps its length.** `widen` is applied *after* the uniform scale,
  so it multiplied it: the counter measured **36 studs inside a 24-stud
  footprint**, hanging 6 studs off each end. `maxSpan` cannot fix this (it
  clamps before `widen` and never bound here), so the counter's `widen` is
  divided by `displayScale`. It now measures exactly 24.0.

### Fixed — 2026-07-22 — `deepen`, the missing companion to `widen`
Closes a tracked issue. The counter body imported ~3.1 studs deep inside a
4-stud cell, so appliances standing on it hung off the front and back, and there
was no mechanism to correct a model that is too thin rather than too short.
`deepen` stretches the **short** horizontal axis exactly as `widen` stretches the
long one; the counter now fills its cell depth at 3.9 studs.

### Added — 2026-07-22 — every dish has its own picture
Closes the one gap the coverage audit found. The 14 dishes are meshes *inside*
one packaged model, so no dish had a Creator Store id to render a thumbnail
from — Espresso and Latte showed the same coffee-cup photo, and the four
pastries shared one croissant.

- **14 dish icons from Kenney Food Kit 2.0 (CC0)**, self-uploaded, one per
  recipe, keyed by `Config/Recipes` id in `Graphics.Dishes`. The kit ships a
  flat 2D render per model, which is exactly the 3D-to-2D step
  `docs/HUD_REDESIGN.md` §4.3 called for; each was upscaled to 256px. Two were
  modified (CC0 permits it): the iced tea is hue-shifted from the stock purple
  to tea colour, and the cappuccino uses `cup` because `cup-saucer` renders as
  an empty plate.
- `Components.ItemThumbnail` gained an `image` option so a dish can pass its own
  uploaded icon, while furniture keeps rendering from its Creator Store model.
- The **always-visible stock dock** slots now show the dish icon instead of a
  coloured letter puck, with the puck kept as the fallback.
- Verified live: 14 cookbook cards, **14 distinct images**, all loading. (Rows
  scrolled out of view report "not loaded" — Roblox does not fetch images it is
  not rendering. Walking the list confirms 14/14.)

Art coverage is now complete for everything the player can buy, place or cook.

### Added — 2026-07-22 — catalogue rows show the actual item, blurred when locked
Owner report: "in the shop or when I want to put an item I can't find the photo
of the item I will be putting." Every catalogue row showed a two-letter category
badge (`AP`, `SE`, `DE`) or, in the build list, nothing but a coloured bar.

- **`Components.ItemThumbnail`** — a row's picture of the real item. Roblox
  renders a preview of any Creator Store asset, so this is the actual model we
  ship, not a stand-in. Falls back to the code-drawn glyph badge when an item
  has no asset, so a row is never empty.
- **Locked items show the same picture heavily blurred**, with the level
  requirement over it. Roblox has no GUI blur (`BlurEffect` is a Lighting
  post-process on the 3D world) and `rbxthumb` serves **only 150×150 and
  420×420** — every other size silently returns blank, so there is no
  low-resolution source to upscale either. The blur is therefore composited:
  the same picture drawn 14× at small offsets. Measured 20 blurred rows = 260
  ImageLabels = 61 fps.
- **Shop** rows: 56px picture; blur toggles live as you level up, since the
  rows are mutated rather than rebuilt. Being short of coins does *not* blur —
  you should be able to see what you are saving for.
- **Build placement** rows: 46px picture, replacing the coloured accent bar. The
  row text also stops being one space-indented string and becomes real labels.
- **Cookbook** cards and **pantry** rows: the category's plate prop, blurred
  while the recipe is locked instead of a bare "?".
- Thumbnails are warmed with `ContentProvider:PreloadAsync` on a background
  thread at join, because Roblox generates a preview server-side on first
  request and that measured several seconds.

**Coverage audit** (asked for in the same report — full table in
`docs/ASSET_LICENSES.md`): all **20/20** buyable/placeable furniture items have
real per-item art, verified rendering live. The gap is **per-dish art**: the 14
recipes are meshes inside one packaged model, so no dish has its own asset id;
they share 4 category pictures. `docs/HUD_REDESIGN.md` §4.3 already documents
the fix (render Kenney Food Kit models to flat icons).

### Changed — 2026-07-22 — the chunky icon HUD (docs/HUD_REDESIGN.md)
The menu rework the owner asked for. The old HUD put a stat capsule at the top
and a small text dock bottom-right; it now reads like a tycoon toolbar.
- **Bottom-left stat pills** — Money · Reputation · Buzz as stacked rounded
  pills with a coloured icon disc, stacked above the active-stock dock. Values
  **tween** to their new number (measured: 16 intermediate frames on a −15 coin
  purchase) and the pill pops to 1.08 and settles. Nothing snaps. The Level chip
  is gone from the HUD; level still drives the level-up celebration.
- **Bottom-centre action dock** — five chunky rounded-square plates: **Build 1,
  Cookbook 2, Staff 3, Upgrades 4, Shop 5**, each with a numbered badge.
  Hovering lifts the plate to 1.10 and fades its **name in underneath**;
  pressing dips to 0.94 and settles back ("pop"); the button whose panel is open
  stays raised with a bright accent stroke.
- **Right rail** — Goals `G`, Trophies `T`, Map `M`, Music `B`, Settings `V` as
  smaller round plates, each with its key in a **tiny pill beside the button**.
  Music is a toggle: it shows its on-state through stroke and tint (and swaps to
  a crossed-out note when muted) rather than sitting permanently raised.
- **`Components.IconButton`** — the dock and the rail are the same component,
  not hand-rolled markup, so restyling is one edit. `Theme.Hud` holds every
  size, scale, tint and motion value; the controllers carry no layout literals.
- **One shortcut table.** `HUD_BUTTONS` in `UIController` declares id, zone,
  order, key, badge, label and accent together; controllers only attach
  behaviour via `registerAction(id, callback)`. Buttons without a panel yet
  (Staff, Upgrades, Map, Settings) say so in a toast instead of doing nothing.
- **`ResponsiveLayout.hudLayout`** — one function computes every HUD rectangle,
  and `UIController`, `InventoryController`, `OperationsController`,
  `CameraController`, `CookingController` and `TutorialController` all read it.
  They used to each guess, which is what let elements land on top of each other.
  On narrow screens the dock slides right out of the pill column (11px on a
  560px phone) rather than restacking the whole left side, and floats above the
  stock dock when a centred dock would sit on it.
- **Landscape phones now get phone-sized controls.** `ResponsiveLayout` is
  landscape-first, so a 668×376 phone reports "Compact" and used to be handed
  72px desktop plates. Sizing now keys off the short axis (`Theme.Hud.ShortViewport`).

Measured live in Studio, all three modes, zero overlapping elements:

| viewport | mode | world visible | floor |
| --- | --- | ---: | ---: |
| 1173×627 | Desktop | **80.3%** | 62% |
| 668×376 | Compact (landscape phone) | **64.4%** | 62% |
| 560×365 | Phone | **56.3%** | 55% |

### Fixed — 2026-07-22 — collisions the HUD move exposed
- **Tutorial card no longer covers the stat pills.** It sat where the pills now
  live and is opaque, so a new player could not read any currency for the whole
  of onboarding. It moves to the band under the café-health card, or to the top
  strip on short viewports.
- **Tutorial card sizing actually applies.** `applyMinimized` hardcoded 360×72
  and ran after the responsive pass, silently undoing every narrow-screen size.
- **Camera pad, café-health card and stat pills stop stacking** on small
  viewports — the pad reads the shared layout and clamps above whatever is below
  it, and the health card's geometry now comes from that same function.
- **Brew panel stops covering the serve button** on desktop (serve moved up with
  the dock), and is clamped so it can never be pushed off the top of a short
  screen.
- **Goals and Trophies no longer both light up.** They open the same panel until
  Trophies gets its own; only the button actually pressed reads as active.
- **Panels sink clicks** (`panel.Active`), so a tap on panel dead space no longer
  falls through to the HUD button underneath it.
- **A slow-loading icon is no longer discarded.** `Components.Icon` used to
  destroy the image at exactly 6s if it had not loaded; it now covers it with the
  glyph badge and swaps the image back in if it arrives.

### Changed — 2026-07-22 — HUD icons are CC0 art we uploaded ourselves
- **17 images self-uploaded** (`docs/ASSET_LICENSES.md`): glyphs from the
  **Nieobie Game Icon Pack** (CC0 1.0, pinned at commit `fb27988`, licence read
  from the repo's own `LICENSE` file) rendered white so `Theme` tints them, and
  button plates from **Kenney UI Pack 2.0** (CC0 1.0, confirmed in the zip's
  `License.txt` and at kenney.nl/support). Zero attribution burden.
- **Retires the Simulator Icon Pack** (`99176447965360`) from the HUD. It is
  published on the Creator Store three times with byte-identical descriptions,
  each claiming originality, and our audit of it was a *script* audit, never a
  *provenance* one. All thirteen icons moved at once rather than mixing packs.
- Every id is verified rendering live (`IsLoaded` true on all 17), so none landed
  Restricted under the 2026-05-05 Asset Privacy default.

### Docs — 2026-07-21 — HUD redesign spec + a truthful status pass
- **`docs/HUD_REDESIGN.md` (new)** — full spec for the menu rework the owner
  asked for: bottom-left stat pills (money/reputation/buzz), a bottom-centre
  dock of five chunky icon buttons with numbered shortcuts that lift and show
  their name on hover, and a right-hand rail with single-key shortcuts. Records
  what we take from the owner's reference screenshot (layout, information
  architecture, interaction pattern) and what we explicitly do not (its icon
  art, skins, wording) — the same line `docs/MENU_SPEC.md` draws for Café World.
  Includes the exact list of icon slots still needed from the owner.
- **`docs/SESSION_HANDOFF.md`** — rewritten: merged work, the DataStore
  environment split, the real offline-earnings formula, and an explicit
  "merged but never actually run" section (the 10-café street,
  `PedestrianService`, the `saveBlocked` path).
- **`NEXT_ACTIONS.md`** — was badly stale: it still listed publishing the
  experience as "the only real blocker left" when the experience has been
  published since 2026-07-20. Rewritten around what is actually outstanding.
- **`KNOWN_ISSUES.md`** — corrected the claim that capped offline earnings
  "remains a later idle-progression feature"; it shipped. The two real
  remaining gaps (Waiter-only capacity scale, and `lastSeenAt` being stamped
  even when settlement never ran) are recorded instead.
- **`CURRENT_STATUS.md`** — persistence is no longer blocked on publishing;
  points at the session handoff as the authoritative status doc.

### Changed — 2026-07-21 — 10-café lobbies, and the surplus-player path made real
The lobby drops from 30 cafés to **10** (owner request). Scale now comes from
Roblox spawning MORE servers, not bigger ones — total concurrent players stays
unbounded while each street stays a readable 10.
- **`World.plotCount` 30 → 10, `plotsPerRow` 15 → 5.** streetLength 1248 → 408
  studs. Nearly all geometry was already parameterised and rescaled cleanly
  (plot origins, road tiling, sidewalk slabs, plaza, sky backdrop, StreetGround,
  world boundary, and all of `StreetMath`).
- **⚠️ The dashboard Max Players must be set to 10 to match.** It is not
  settable from code. At the recorded setting of 30, twenty players per server
  would join with no café.
- **Surplus players are no longer stranded.** `assignPlot` returning nil used to
  `return` silently: no plot, no PlotOrigin attribute, no furniture rendered, no
  teleport, no fall-recovery, and a build mode that swallowed every tap without
  explanation. They now join a **waiting queue**, are told so, and are handed the
  next café that frees up (`serveNextWaiting` on `onPlayerRemoving`).
- **`plotCount == plotsPerRow * 2` is now enforced.** `plotOriginFor` wraps its
  column modulo `plotsPerRow`, so a mismatch silently stacked a second café on an
  existing origin and handed two players the same building. Asserted at boot and
  covered in `tests/StreetMath.spec.luau`.
- **Pedestrians could be trapped outside the world boundary.** `END_MARGIN` was a
  flat 20 studs, but the StreetGround slab only reaches `plotSpacing/2 - 32` = 10
  studs past the last plot, with the boundary wall on that edge — so a spawn in
  that strip landed *outside* the wall and `clampX` kept it there forever.
  `walkXBounds` now clamps the margin to what actually fits (20 → 6). Pre-existing,
  but the odds roughly tripled on the shorter street. Covered by a new spec case.
- **Street decor now scales with the street.** Trees were a hardcoded `for i = 1, 4`,
  which on a 408-stud street meant one tree per café (~3x intended density); the
  count is now derived from length (2 trees, 210-stud spacing). The `% 3` / `% 4`
  accent strides collapsed to 2 mailboxes and a single lone hydrant on the whole
  far pavement; the stride is now size-aware (3 mailboxes, 2 hydrants).

### Fixed — 2026-07-21 — ghost profiles, and an unprotected loop that could disable the shift system
- **Ghost profile overwriting real saves.** `DataService.onPlayerAdded` yields
  inside `loadAsync` (a GetAsync, plus up to 3 retries with 2s waits). It then
  populated `profiles`/`loaded`/`saveBlocked` *after* that yield — so a player who
  left mid-load had `onPlayerRemoving` run first against empty tables, and the
  load then **repopulated them for the life of the server**. The 60s autosave kept
  writing that orphaned snapshot over their real save. The load result is now
  discarded if the player has already left.
- **The 5s operations loop had no `pcall`.** It owns offline settlement, staff
  capacity recovery, satisfaction decay, dirt spawning and `lastSeenAt` freshness.
  One uncaught error from any single player's tick killed the thread and silently
  disabled all of that for **every** player on the server, permanently. Every
  comparable loop in the codebase was already protected; this one was not.

### Fixed — 2026-07-21 — persistence safety: a failed load no longer wipes the account
Found while verifying "does a returning player get their progress back".
- **A transient DataStore outage permanently erased accounts.** When all three
  `GetAsync` attempts failed, `loadAsync` returned a blank `defaultProfile()`
  and logged "NOT persisted this session" — but **nothing enforced that**.
  `saveAsync` had no idea the load had failed, so the next 60s autosave (or
  save-on-leave) wrote that blank straight over the player's real save. One
  DataStore blip = a wiped café, irreversibly. `loadAsync` now returns
  `(profile, safeToSave)` and users whose save could not be read are added to
  `saveBlocked`, which every write path skips. They can still play on the blank
  profile; it just never persists.
- **The DataStore name is now resolved at boot instead of hardcoded to `DEV`.**
  Two bugs in one: publishing would have filed live players into the DEV store,
  and — worse — once the place was published a Studio playtest would have read
  and overwritten PRODUCTION saves. Studio and unpublished servers are pinned to
  `DEV`; a live server resolves to `PROD`; an `Environment` attribute on the
  place overrides both (e.g. `STAGING`). Verified: Studio resolves to
  `DEV_PlayerProfiles_v1`.
- **Join no longer renders an empty café on a slow load.** `CafeService` waited
  a fixed 20s for the profile and then rendered regardless, which would draw a
  blank shop for a player who actually had saved furniture. It now waits while
  the player is still in the server (logging every 10s, hard cap 3 min) and
  bails without rendering rather than showing a wrong, empty café.
- **Capacity guard rail.** One café per player is the whole premise, but
  `MaxPlayers` lives on the Roblox dashboard and can be changed without touching
  this code. `CafeService.Start` now asserts the invariant out loud at boot,
  naming the exact numbers, instead of the surplus players silently arriving
  with nowhere to play.

### Added — 2026-07-21 — permanent street crowd: ambient pedestrians on the sidewalks
The boulevard now has a standing cast of NPCs so the neighbourhood reads as
alive instead of empty, and some of them wander into **any** open café — every
claimed plot, not just the local player's.
- **`PedestrianService`** keeps `Pedestrians.count` (16) walkers alive for the
  whole server session, split across the two sidewalks, in their own
  `workspace.Pedestrians` folder. They are pure set dressing: they never queue,
  order, tip, or touch satisfaction/Buzz, and nothing that scans
  `Customers`/`Staff` sees them.
- **Sidewalks only, by construction.** Street movement uses a direct
  `Humanoid:MoveTo` along a fixed lane — deliberately NOT PathfindingService,
  which happily routes an NPC diagonally across the road. Pathfinding is used
  only once a pedestrian is inside a café, where it has to route around
  furniture. A per-tick clamp snaps anyone shoved off the paving back into lane.
- **`Utilities/StreetMath`** holds the geometry as pure numbers so it is
  unit-testable: sidewalk A is Z [-18, 0], the road is Z [-42, -18], sidewalk B
  is Z [-60, -42]. The walkable lanes are Z [-10.5, -3.5] and [-56.5, -49.5] —
  inset to clear the café fronts AND the street decor, since CafeService puts
  mailboxes at Z -14 and hydrants/trees at Z -46/-44, right where a naive
  "walk down the middle of the pavement" would collide. Verified against the
  built world: measured sidewalks/road/decor match these numbers exactly.
- **`tests/StreetMath.spec.luau`** asserts the containment contract — lanes are
  strictly inside the paving, never overlap the road, and keep ≥3.5 studs from
  every café wall and decor prop.
- Cafés count as OPEN when the plot is claimed (unowned plots are shuttered and
  read CLOSED). Pedestrians only consider cafés fronting their own sidewalk, so
  a visit never means crossing the road, and `maxVisitorsPerCafe` (3) stops one
  café swallowing the crowd.
- `World.roadWidth` is now the single source of truth for the road/sidewalk
  split, shared by CafeService's tiling and StreetMath's lanes.
- `CafeService` door proximity now also counts the `Pedestrians` folder, so a
  passer-by no longer walks into a shut door.

### Fixed — 2026-07-21 — kitchen layout VERIFIED in Studio; counter fills its footprint, machine sits flush
Closes the one open item from the 2026-07-20 handoff, which had been set blind
and never visually confirmed. Measured live in Studio against the real assets
rather than reasoned about, since the previous pass was burned by mirrored
left/right intuition.
- **Left/right layout was already correct — no flip needed.** Ground truth: the
  player enters facing local +Z, and with Up = +Y that puts their RIGHT at LOW
  local X. Measured positions: espresso machine pivot at local X 18 (owner's
  RIGHT ✓), front door at local X 50.4 (owner's LEFT ✓), kitchen at cells 0-7
  (front-RIGHT corner ✓). `World.doorCenterFrac` and the seed `gridX` are now
  commented with this result so a future pass does not "fix" it backwards.
- **Counter now fills its 6-cell footprint** (`AssetManifest.counter.widen`
  2.1 → 2.56). The normalised body is 9.38 studs before the multiplier and the
  footprint is 24 studs, so 2.1 left it spanning only 19.7 — measured 24.02
  after the change.
- **Espresso machine no longer floats** (`DataService` seed `seed_coffee.liftY`
  3.5 → 2.43). `liftY` is the model's BOTTOM height and the counter worktop
  measures 2.43, so the machine had been hanging 1.07 studs in mid-air. The
  earlier 3.5 was derived from a bounding box polluted by the StockDisplay
  (top 5.28) rather than the worktop itself. Verified live: flush gap −0.004.
- Together these also fix the machine hanging off the counter's right end — it
  sat at the footprint edge (X 15.7) while the short counter only began at 18.1.

### Added — 2026-07-19 — graphics haul: last greybox items, real dirt, maid, warm walls
- **The 5 remaining greybox shop items now use real models**: Prep Station,
  Round Table (glass), Potted Plant, Floor Lamp, Round Rug.
- **Pivot normalization** (AssetLibraryService): furniture templates now get an
  axis-aligned pivot at their centre, so the loaded upright pose survives
  placement instead of inheriting a random part's rotation — this fixed the
  floor lamp (was lying down) and the rug (was standing on edge). Flat items
  (`flat = true`) rotate their thinnest axis vertical and scale by span.
  Verified live: every furniture piece upright/flat and sitting on the floor,
  no regressions to coffee machine / counter / chair / oven.
- **Dirt is a real spill mesh** now (owner pick), not the procedural brown
  splat, and the "DIRT! CLEAN ME" text is gone — the mesh is the signal.
- **Pia the cleaner uses the owner's maid rig** (14466134917). Re-verified: R15
  with 13/15 joints (only the ankles missing), which walks cleanly — so the
  walk gate was relaxed from 15 to 13 for R15. Live movement check: 4.1
  studs/step, no teleporting.
- **Warm plaster walls** replace the harsh orange (interior + facade); the red
  awning accent stays. **Neon "Coffee Cup" café sign** mounted on each café's
  exterior facade. Coffee drinks use the new coffee-cup prop.
- Rejected: the barista rig (4646109032 — no HumanoidRootPart/Head, 8 scripts);
  the wallpaper asset (13010827217 — "not authorized", won't load); the food
  mesh pack (mostly raw ingredients, poor café fit — kept the Retro pack).

### Added — 2026-07-19 — active café shift loop (idle → hands-on tycoon)
Turns unlimited automation into a finite, active-play loop where the owner is
the fastest way to keep the café healthy. (Built on the `codex` branch; dead
code cleaned, all gates + 51 TestEZ cases verified, runtime smoke-checked.)
- **Finite staff shift capacity** (`Config/Operations`, `CafeOperationsService`):
  Barista/Cook/Waiter/Cleaner each spend capacity while working and only
  recover while the owner is in-game; hands-on work restores a little. Offline
  automation drains capacity instead of running forever.
- **Persistent satisfaction + cleanliness**: a compact HUD health card (SAT /
  CLEAN / BARISTA / WAITER). Satisfaction decays while away; low cleanliness
  cuts patience and can make arrivals reject the café outright.
- **Visible dirt**: splats spawn on the floor (~18 s) with a "CLEAN ME" prompt;
  the owner can scrub for satisfaction, or Pia takes it after a grace window.
- **Angry emoji walkouts**: customers leave with a readable reason — long line,
  no empty chair, café too dirty, or order never came — each denting Buzz +
  satisfaction.
- **Physical order delivery** (`OrderService` rewrite): pick an order up at the
  kitchen pass, the plate visibly follows your hand, you can only carry one,
  and only the matching table completes the sale ("PERFECT DELIVERY!"); wrong
  table is corrected, not silently served.
- **Street approach**: customers spawn on the distant sidewalk and walk in
  along a real road network, not popping in at the door.
- **Sealed map**: a perimeter boundary plus a fall-watchdog that returns a
  strayed player to their own door instead of killing them; indoor jump cap.
- **Explicit economy** (`OperationsMath`, `OperationsController`, production
  menu): per-recipe batch time, production/min, waiter serve-capacity/min, the
  real bottleneck, and net coins/min after ingredients. Offline runs at 20×
  time for 1/20 earnings, shown clearly with an on-return summary.

### Added — 2026-07-19 — owner-approved graphics pack
- Replaced HUD letter badges with approved coin, reputation, level, Buzz,
  goals, cookbook, build, shop, and pantry images from the Simulator Icon Pack;
  the code-native glyphs remain available as fallbacks.
- Added tiled stone sidewalks, a modular two-lane road with straight/left/right
  modules, a warm wooden restaurant floor texture, and a bright cloud sky.
- The Retro Food Pack is loaded once, stripped of all five embedded scripts,
  and reduced to 14 explicitly selected recipe props for counters and plates.
- Rejected the American diner pack from the shipped build: it contains branded
  restaurant logos, 659 instances, and two embedded scripts, and is not a clean
  or original UI-icon source.
- Live-tested the approved graphics on desktop and iPhone 17 Pro landscape:
  all HUD/environment images loaded, 50 sanitised templates loaded with zero
  fallbacks, and the complete TestEZ suite passed 48/48 cases.

### Changed — 2026-07-19 — compact tycoon interface
- Rebuilt the runtime UI around a single resource capsule, a contextual order
  ticket, a small active-stock pill, and a collapsible edge action dock so the
  restaurant remains the visual focus.
- Landscape phones and short Studio windows now use narrow 41–44% side drawers
  instead of full-width mobile sheets. Desktop drawers leave at least 62% of
  the world visible in the tested laptop viewport.
- Pantry/production, shop, goals, cookbook, build, appliance picker, and visit
  panels now share one high-order modal layer, preventing tutorial and stock
  widgets from rendering over an open menu.
- Added an original Sunset Cafe theme with code-native icon fallbacks, 44px
  production controls, vibrant status colors, and blank approved-asset hooks.
  No third-party icon asset was inserted without owner approval.
- Live-tested in Studio on iPhone 16 Pro Max landscape and an average laptop.
  The iPhone stock pill used 226–344px depending on active menu count, open
  drawers left 55% of the world visible, and TestEZ passed 44/44 cases.

### Added — 2026-07-18 — continuous idle/tycoon production
- All 14 current products now have explicit batch time, yield, online shelf
  life, waiter cycle, appliance, and staff-role requirements.
- Placed coffee machines, stone ovens, and prep stations continuously produce
  enabled menu recipes toward player-controlled stock targets. Production
  pauses for missing appliances, missing staff, full targets, or ingredients.
- Inventory is now timestamped FIFO lots with atomic short reservations. A
  serving is removed before its payout, expired food is tracked as waste, and
  offline time is shifted out of expiry so absence never destroys stock.
- `PlayerData.staff` is authoritative. Mia produces drinks, Sam produces food,
  Noah limits automatic service to each recipe's cycle, and Pia remains the
  cleaner; staff levels improve role speed.
- Customer demand now scales from 1.2 to 2.8 visits/minute using Buzz, seating,
  and waiter capacity instead of overwhelming the kitchen every 3–10 seconds.
- Added an always-visible vibrant stock rail for every product plus a responsive
  Production Manager (four menu slots, target stock, P1–P3 priority), incoming
  batch/freshness timers, and a Business Pulse bottleneck message.
- Schema v2 migrates old numeric counter stock into fresh timestamped lots and
  seeds the four existing crew roles without losing old servings.
- Added deterministic FIFO/reservation/spoilage/balance tests and
  `docs/PRODUCTION_BALANCE.md`. Live TestEZ result: 44 passed, 0 failed.

### Fixed — 2026-07-18 — visible chair facing, vibrant café, human-scale walls
- Chairs now face the nearest table regardless of placement order, including
  saved layouts loaded from older builds.
- The imported wooden chair's native back is `-Z`, opposite the procedural
  chair convention. A measured 180° correction is now applied in the final
  placement transform, so the visible seat faces the table.
- The restaurant uses a brighter coral, honey-oak, cream, gold and teal palette.
- The front-right café corner is a real open kitchen with an L-shaped divider
  and dish pass. Customers queue on the dining side; Mia/Sam prepare inside;
  Noah collects plates outside; Pia's idle sweep stays out of the kitchen.
- Exterior walls are back to a human-scale 12 studs. Players use a 3-stud / 28
  power jump only while inside a café and regain the normal 7.2 / 50 outside;
  the private garden fence keeps its sealed collision boundary.
- Live MCP verification: four real chairs all faced inward, indoor/outdoor jump
  transitions passed, and a wall-directed jump from a 3.8-stud platform peaked
  at root Y 9.33 and remained inside the 12-stud wall.

### Added — 2026-07-17 — S2 CLOSED: feelings, regulars, combo + the Priorité 4 dressing haul
**The feelings layer (S2 finish, live-verified):**
- **Mood faces + patience bars** over every waiting customer (😊→😐→😠 with a
  draining colour bar), in the line AND at the window.
- **Storm-outs**: impatient customers flash red "−N 🔥", speed up and leave —
  line walkouts now also dent Buzz (they didn't before).
- **Regulars (persisted, max 8)**: diners are remembered by name; 35% of
  spawns are a returning regular ("💚 Zoe is back!") who orders their
  favourite dish — serving it pays +1 Buzz and a burst of hearts.
- **Personal-service COMBO**: chaining owner actions (serve orders, clean
  tables) within 45s pays escalating bonus coins ("COMBO ×4 +8 🪙") — an
  active owner visibly out-earns an idle one.
**The Priorité 4 graphics haul (20 assets adopted, live-verified):**
- 11 new buyable interior items (wall painting, menu board, hanging lamp,
  plant shelf, wall shelf, wall clock, curtains, diner booth, bar stool,
  coat rack, cake display) — wall pieces mount at height via liftY.
- **Gardens auto-dress**: hedges along the fences, flower patches, garden
  bench, lantern, real trees (the tree pack splits into 11 variants).
- **Street + plaza**: real lampposts (32), mailboxes, hydrants, trees, and
  the fancy plaza fountain — procedural fallback everywhere, redressed
  automatically when the async asset load lands.
- **Noah is the Butler** (R15, complete 15/15 skeleton, zero scripts). The
  maid kit was auto-rejected (13/15 joints — the limp gate works); Pia keeps
  her verified base until a complete maid rig is found. The 636-part
  trash-can joke asset was rejected for performance.

### Fixed — 2026-07-17 — LIVE-VERIFIED: the whole S2 stack, + 3 movement fixes it caught
Studio MCP reconnected; everything from the three S2 passes ran live. Confirmed
working: facade/door/garden/14-stud walls, 16/16 assets loaded, chair
auto-facing (deliberately wrong rotations corrected server-side), seated
customers' legs STILL, dish-icon bubbles, Barista/Cook role split ("🍳
Preparing…" → "🥪 Café Sandwich ✓"), waiter carry with real MealPlate, dirty
plate + owner Clean-up prompt + Pia's collect-carry-wash cycle, take-order
prompt present, cleaner idle sweeping. Movement was measured (max step per
0.4s across the crew) and three real bugs were caught and fixed:
- **NPCs no longer collide with NPCs or players** (collision groups in
  NpcNav): the waiter was body-blocked by queueing customers, timed out and
  teleported 23 studs. Verified after: everyone at walk speed, zero jumps.
- **Stuck-recovery hops to the blocked waypoint** and keeps walking instead
  of teleporting across the room to the final target.
- **Waiter walks to the stand-spot beside the station**, not to the plate on
  top of the collidable appliance (that unreachable target failed pathing
  into the teleport recovery), and the barista kit (139800912587260) turned
  out to have a 5/6-joint skeleton — it limped; the walk gate now requires a
  COMPLETE skeleton per rig type (R6=6, R15=15) and Mia moved to a verified
  walking base with her uniform apron. Final audit: max step ≤4.6 studs
  (= walk speed) for every staff member across service cycles.

### Added — 2026-07-16 — S2 third pass: work your own café + walk-verified rigs + taller walls
- **The owner can WORK the café** (the gameplay transformation): `E` on the
  ordering customer to **take the order** and serve it from stock (+2 Buzz
  "personal service"), `E` on a dirty plate to **clean the table** (+1 Buzz,
  races Pia — first one wins), tips collectible as before. All prompts are
  owner-validated server-side and reuse the existing grant paths (no dupes).
- **Rig walk policy**: AssetLibraryService now REJECTS any rig without a
  native HumanoidRootPart and a real Motor6D skeleton (the HRP-synthesis path
  is removed — it produced the sliding waiter). The broken waiter kit
  (154539270) is permanently rejected; **Noah and Pia now use walk-verified
  customer rig bases with role-coloured uniform aprons** (waiter navy,
  cleaner green) until dedicated rigs are shopped (list #63/#64).
- **Cleaner idle sweeping**: between wash-up jobs Pia walks to a spot and
  sweeps — every employee visibly does their job (docs/NPC_BEHAVIOR.md is the
  new per-NPC behaviour contract).
- **Walls raised 9 → 14 studs**: you can no longer hop out of the café even
  jumping from a countertop; the awning now hangs at door height instead of
  tracking the wall top.
- docs: NPC_BEHAVIOR.md (exact tasks/state machine per NPC + player actions),
  ASSET_SHOPPING_LIST.md "Priorité 4" (36 dressing objects: restaurant,
  garden, neighbourhood + walking-rig rules), parity map C6 row + progress.

### Added — 2026-07-16 — S2 service theater: defined staff roles + the full plate lifecycle
- **Every employee now has ONE defined job** (Café World parity C2/C3):
  **Mia · Barista** prepares drinks at the coffee machine, the new **Sam ·
  Cook** (the owner's chef rig, reassigned from cleaner) prepares food at the
  oven/prep station — both walk to their appliance and flash a bubble with the
  **dish icon** when it's ready; **Noah · Waiter** walks over, picks the plate
  up and carries it to the table (`StaffService.DeliverMeal` orchestration);
  **Pia · Cleaner** collects the emptied plate and carries it off to wash
  (+1 Buzz). Every stage degrades gracefully when staff are busy/missing, and
  the whole flow is post-payment theater — it can never touch the economy.
- **Visible meals**: the plate + real food prop sit ON the table in front of
  the diner (PlateFactory); after eating, food disappears and the EMPTY plate
  stays until washed. Customer want-bubbles show the dish icon + name
  (Config/Recipes gains per-recipe emoji icons).
- **Fixed — walls invisible from outside**: the camera now x-rays only the
  café your character is standing in; every other café keeps its full facade.
- **Fixed — furniture landing away from the click**: placement raycasts now
  hit ONLY your interior floor (walls/door/awning used to swallow clicks) and
  the GUI-inset coordinate mismatch on the click path is corrected
  (KNOWN_ISSUES "screen→grid raycast" resolved).
- **Chairs auto-face the nearest table** on placement (server-side, 1×1 seats).
- **Fixed — seated customers' legs kept moving**: NpcAnimator gains a seated
  mode (anchored roots never fire Running(0), so the walk cycle kept playing).
- **Fixed — the waiter teleported instead of walking**: all staff now use the
  same PathfindingService navigation as customers (shared NpcNav module);
  straight-line + teleport stays as the last-resort recovery only.
- NOT live-verified (Studio MCP still down; the adversarial review workflow
  also could not run — session limit); manual code-trace done, gates green —
  owner playtest checklist updated in KNOWN_ISSUES.md.

### Added — 2026-07-16 — S2 architecture: facade + auto-door, 3x interiors, private gardens
- **Every café is now a real building** (CafeService rework): a front facade
  with two windows and a centred **door that swings open automatically** for
  any approaching player/customer/staff and closes behind them (never
  collidable — nobody can ever be trapped; the wall gap is the navmesh route).
  The sign moved to the facade; walls are 9 studs (unjumpable) — the door is
  the way in AND out, which also fixes "I can't exit my own café".
- **Interiors are 3x bigger** (18×24 cells = 72×96 studs, was 12×12 = 48×48)
  and **tiered**: `PlayerData.expansionTier` (0–2) drives interior depth
  (24/28/32 cells). The shell (floors, side/back walls, garden) rebuilds per
  tier; `CafeService.RefreshTier` is the S4 buy-land hook, already functional.
- **Private garden** behind every café: fenced grass with a gate off the back
  wall (auto-door), stone path, tree and flower beds. Buying land (S4) will
  convert garden depth into interior depth, Café-World-style; ≥40 studs of
  garden always remain.
- **Proximity checks are rect-based** (`Grid.distanceToPlotRect`, unit-tested):
  distance-to-centre would have rejected cooking/serving at the front counters
  of the deep new plots. Serve/cook/compliment guards migrated.
- Queue moved INSIDE the café (through the front door); staff idle spots and
  trophy shelf repositioned (shelf now on the left wall — tier-independent);
  camera fades the new facade + shell walls and zooms out to 120; build
  preview + server placement clamp to the owner's tier (garden previews red).
- Seed kitchen moved off the doorway lane; new placement spec cases for
  per-tier bounds and rect distance.
- NOT yet live-verified: Studio MCP was disconnected this session — owner
  playtest checklist in KNOWN_ISSUES.md.

### Fixed — 2026-07-15 — S1 polish from playtest feedback (dimensions, walk, pathing)
- **Object dimensions**: switched furniture scaling from fit-to-footprint (which
  squashed long/tall pieces — the counter shrank to 23% and chairs to ~16%) to
  **target-height scaling with a footprint clamp + yaw fix**. Also multiply by
  the model's current scale (`ScaleTo(GetScale() * s)`) — imported Sketchfab
  models (e.g. the chair) carry a non-1 baked scale that made absolute ScaleTo
  shrink them. Verified live: counter 2.1×3.8×9.4, coffee 4.6×3.6×4.2, chair
  1.75×3.3×1.83 (was 0.4×0.7×0.4).
- **Natural NPC movement**: new `NpcAnimator` plays Roblox's default R6/R15
  walk+idle animations on real rigs (they had no Animator and slid); procedural
  chibis keep the hip waddle. Verified: customers now have a playing anim track.
- **No more walking through furniture**: customers navigate with
  **PathfindingService** (route around obstacles) instead of straight-line
  MoveTo, and walk-blocking furniture is now collidable so the navmesh sees it.
  Straight-line + teleport recovery kept as fallback. Verified: path test
  returns Success (12 waypoints); furniture 35–45 collidable parts.
- Waiter rig (154539270) now loads too via the HRP synthesis — **15/15 asset
  templates, 0 fallbacks**.

### Added — 2026-07-15 — Step S1: Creator Store asset pipeline (make it LOOK like a café)
- **AssetLibraryService + Config/AssetManifest**: loads owner-picked Creator
  Store models at boot, **strips every script** (BaseScript/ModuleScript/
  Remote/Bindable/Tool/Sound), rescales to grid footprints, caches templates
  in ServerStorage, and serves clones. Loads in the background; any asset that
  fails vetting or load simply falls back to the existing procedural greybox —
  the game never breaks.
- **Furniture** now renders real models when available (espresso machine, pizza
  oven scaled to footprint, counter+register, wooden chair) via BuildService,
  procedural builders retained as fallback.
- **Customers** wear real clothed R6/R15 rigs (4 appearance donors) with our
  name tag + order bubble + walk/queue/seat logic on top; waddle now bobs
  around each rig's own hip height. Procedural chibi kept as fallback.
- **Staff** (Mia/Noah/Pia) use real barista/waiter/cleaner rigs; fallback intact.
- **Food props**: counters and diner plates show real croissant/cake/sandwich/
  cup meshes by recipe category (coloured cylinders as fallback).
- 15 assets adopted, 7 rejected during live Studio vetting (IP-named, ripped,
  unauthorised, or duplicate/ragdoll rigs) — all logged in docs/ASSET_LICENSES.md.
  Parity map updated (D1, C4 advanced).
- **Live-verified in Studio** (playtest): real furniture renders (coffee machine
  45 parts/2 meshes, counter+register 35 parts), barista (Mia) + cleaner (Pia)
  as real rigs, four clothed customer rigs walking/queuing. Waiter (Noah)
  real-rig loading fixed by construction (HRP synthesis, gate-clean); its live
  confirmation is pending a clean Studio session — the start-page quirk (§5.3)
  blocked further playtests this session (even a `-task EditFile` CLI launch
  landed on Studio's home page). Owner: open the place from Studio's **Recent**
  list, press Play, confirm all three staff are real rigs.

### Changed — 2026-07-15 — Café World parity roadmap + Creator Store policy
- **docs/CAFE_WORLD_PARITY.md (new)**: complete feature map of the original
  Facebook game (Café World by Zynga) — 49 features across cooking, service/
  Buzz, staff, customisation, economy and social, each marked have/partial/
  missing/rejected and assigned to a roadmap step. Owner's top request.
- **docs/ASSET_SHOPPING_LIST.md (new)**: curated Creator Store shopping list
  (3 priorities, EN search terms, French Studio click paths, vetting
  checklist) + the AssetLibrary pipeline contract (manifest → InsertService
  load → script-strip → grid rescale → procedural fallback).
- **ROADMAP.md**: new 5-step session roadmap "Café World parity push"
  (S1 look-like-a-café asset pipeline → S2 customer feelings → S3
  preparation/menu/appliances → S4 floors/walls/expansion → S5 social café);
  supersedes phase order until shipped. HANDOFF §6 repointed.
- **docs/ART_DIRECTION.md**: 2026-07-15 addendum — vetted Creator Store
  models allowed (scripts stripped, licences logged, procedural fallback,
  cohesive low-poly family); UI stays original.

### Added — 2026-07-14 — Day 5: a neighbourhood worth visiting
- **Golden-hour lighting pass**: warm Mediterranean evening (Atmosphere, bloom,
  sun rays, colour-shifted ambient), lamp posts with warm point lights, trees.
- **Central plaza**: cobblestone circle, three-tier fountain, four benches with
  planters, and a Neighbourhood Board — the social heart of the street (§19).
- **Café visits** (SocialService + InteractionController): "Visit Café" prompt
  on every neighbour's doormat pad teleports you to their door; a compliment
  panel offers three predefined reactions (whitelist only, no free text). A
  compliment gives the owner +2 reputation, once per visitor per owner per
  session, validated for physical presence. "🏠 Go home" returns you.
- **Persistent learn-by-doing tutorial** (ProgressionService + rewritten
  TutorialController): six strictly-ordered steps (place furniture → brew →
  serve → buy → decorate → reach the plaza) tracked server-side in
  stats.tutorialStep; +25 coin completion gift, exactly once per profile.
  Funnel analytics: tutorial_started / step_completed / completed,
  first_cafe_visit, compliment_sent.
- Plot models now expose `plotIndex`; workspace exposes `PlazaCenter`.

### Added — 2026-07-14 — Day 3: customers you can see, coffee you can brew
- **Visible customer NPCs** (CustomerService rewrite): greybox walk-in customers
  spawn on the street, walk to the service spot, order with a recipe bubble,
  wait, react (😊 +coins / 😠 timeout), walk out. Teleport recovery for stuck
  NPCs; 120s patience cancels the order server-side (OrderService.CancelOrder).
- **Manual coffee-brew minigame**: ProximityPrompt on your own coffee machine
  opens a timing bar (Space/tap to stop). Shared constants in Config/Cooking.
- **Security hardening**: the client's `manualCook` claim argument is now
  IGNORED — the server judges the brew timing from its own clock
  (RecipeService sessions) and arms a one-shot bonus flag consumed at claim
  time. New remotes: FinishCooking. New CafeService.IsNearOwnPlot guard;
  plot models carry an `ownerUserId` attribute for client-side lookup.
- Verified live (NPC lifecycle, serve payout +tip/rep/xp exactly once,
  cancel path, customer cycling). Brew minigame verified by unit-level gates;
  live playtest pending the next Studio session.

### Fixed — 2026-07-13 — Day 1 live verification
- **Client boot**: `Main.client.luau` waited on `script:WaitForChild("Controllers")`, but `Controllers` is a sibling folder — no controllers or UI ever loaded. Now `script.Parent:WaitForChild("Controllers")`. Found in the first live playtest via MCP console read.
- StyLua formatting drift in test specs; repo now passes `stylua --check .`.
- Selene reported 55 `undefined_variable` errors for TestEZ globals in `tests/*.spec.luau`; added `testez.yml` standard library and switched `selene.toml` to `std = "roblox+testez"` (0 errors).
- `.gitignore`: ignore Studio `*.rbxlx.lock`/`*.rbxl.lock` files and local `.mcp.json`.

### Verified — 2026-07-13
- 21/21 unit specs pass inside Studio (MCP harness, live DataModel).
- Clean server boot (6 plots, 12 services) and client boot (6 controllers).
- E2E serve loop through real remotes: payout matches config, duplicate claim pays nothing.

### Added — 2026-07-13 — Day 1 scaffold
- Rojo project in strict Luau: toolchain manifests, CI, project mapping.
- Shared layer: type definitions, data-driven config (economy, 5 recipes, 7 furniture items, 3 customers, progression, staff), remotes registry, pure utilities (Grid, RateLimiter, RewardMath, Log).
- Server: service framework + DataService (persistence w/ in-memory fallback, autosave, migration hook), EconomyService, CafeService (greybox 6-plot street), BuildService (server-validated placement), OrderService (serve/claim with anti-double-claim + distance guard), CustomerService (order generator), RecipeService, ProgressionService, AnalyticsService, and Staff/Social/Monetization placeholders.
- Client: HUD (stats, order, serve, shop, toasts), grid-based BuildController with live preview, learn-by-doing TutorialController, placeholder controllers.
- Tests: TestEZ specs for economy payout, grid placement, and progression.
- Documentation set (design, architecture, security, tests, release, economy, analytics, licences).

### Published — 2026-07-14 — Social Cafe DEV is live (private)
- Experience published: universe 10501568035, place 85898641225605, Access: Private.
- Studio API Services enabled → real DataStore (`DEV_PlayerProfiles_v1`).
- **Persistence verified end-to-end**: furniture placed in session A loaded
  from DataStore in session B. MVP criterion #12 passed.
- Max players set to 30 via Creator Dashboard (Access Settings).

### Added — 2026-07-14 — Phase 1: the cook-ahead loop pivot
- **KitchenService**: stove batches on wall-clock time (overnight cooking
  works), counter stock, fresh-collect bonus (never spoilage — §35), Buzz
  0–105 driving customer arrival rate, sign scoreboard.
- Customers eat from counter stock automatically; waiting order-customers
  get auto-fed the moment a matching batch is collected.
- Stone Oven + Prep Station appliances (all 5 recipes now cookable),
  stove timers + steam visuals, cook/collect prompts + recipe picker,
  HUD Buzz meter, kitchen toasts.
- Verified live: batch cost/servings/fresh-bonus math exact, busy/early
  rejections, 7 customers fed from one batch, Buzz feedback loop spinning.

### Added — 2026-07-14 — Phase 2: the alive café
- **Seated dining**: fed customers leave the queue (line advances), walk to a
  free placed chair, sit facing it, eat from a plate of food with a happy
  bob, then head out — verified sitting exactly on the chair's grid cell.
- **Collectible tips**: seated diners can leave a tip coin (owner-only
  ProximityPrompt, server-validated) — the reward for owning chairs.
- **Juice**: coin bursts + floating text on batch collect and tip pickup;
  chibi waddle (hip-bounce) while NPCs walk.
- **Visible stock**: food stacks render on the counter as batches land and
  customers eat them down.
- **Charm pass**: striped awnings over every café front + warm interior
  glow at golden hour.

### Added — 2026-07-14 — Phase 3a: progression that grips
- **Recipe mastery**: every collected batch teaches the recipe; stars at
  5/15/40/100 cooks grant -5% cook time & batch cost per star, +1 serving
  at ★★, and a 1.5× fresh bonus at ★★★★ (pure Mastery module, 8-assertion
  spec). Star-up float text at the stove + toast.
- **Cookbook**: card list of all recipes — unlocked cards show live
  mastery-adjusted numbers, stars, and "next ★ at N"; locked cards tease
  as silhouettes with their unlock level. Gold names when mastered.
- **9 new original recipes** (14 total) laddered to Lv 9, including the
  8-hour Overnight Roast Blend (40 servings — start it before bed).
- **Level-up celebration**: full-screen star moment on level gain.
- Cook picker rows show mastery-adjusted costs.

### Added — 2026-07-15 — Phase 3b: daily goals, streak trophies, full crew
- **Daily goals** (GoalService): three goals roll each UTC day from a pool
  (serve customers / collect batches / earn coins / pick up tips / visit a
  neighbour); each pays coins instantly on completion, all three pay a
  bonus and advance the streak. Progress reported by Kitchen/Order/Economy/
  Customer/Social services via GoalService:Bump.
- **Streak trophy shelf**: milestones at 3/7/14/30 days mint PERMANENT
  trophies (bronze→diamond) rendered on a shelf in your café + coin bonus.
  A missed day restarts the counter only — the shelf never empties (§35).
- **Goals panel** (📋 button): progress bars, streak, trophy count, with
  goal/streak/trophy toasts.
- **Staff v2**: full crew of three per café — Mia (barista, rescues overdue
  orders), Noah (waiter, carries a tray to seated diners), Pia (cleaner,
  clears the dirty plates diners leave and earns +1 Buzz each).
- Diners now leave dirty plates behind; the waiter delivery and cleaner
  loops both use the same waddle-walk + teleport recovery as customers.

Live playtest of 3b happens via the owner's session (test-instance launch
hit a local Studio start-page quirk); all CI gates green.
