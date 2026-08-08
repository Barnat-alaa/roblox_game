--!strict
-- Shared visual language for the Social Cafe interface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Graphics = require(ReplicatedStorage.Shared.Config.Graphics)

local Theme = {
	Colors = {
		Espresso = Color3.fromRGB(55, 35, 31),
		Roast = Color3.fromRGB(91, 57, 47),
		Cream = Color3.fromRGB(255, 247, 229),
		Paper = Color3.fromRGB(255, 252, 244),
		PaperDark = Color3.fromRGB(239, 224, 199),
		Coral = Color3.fromRGB(237, 96, 76),
		CoralDark = Color3.fromRGB(194, 67, 57),
		Mint = Color3.fromRGB(65, 178, 145),
		MintDark = Color3.fromRGB(37, 128, 106),
		Honey = Color3.fromRGB(247, 185, 63),
		Berry = Color3.fromRGB(197, 69, 101),
		Blue = Color3.fromRGB(82, 142, 189),
		Ink = Color3.fromRGB(55, 43, 47),
		Muted = Color3.fromRGB(130, 116, 112),
		Line = Color3.fromRGB(213, 190, 159),
		White = Color3.fromRGB(255, 255, 255),
		Danger = Color3.fromRGB(224, 76, 76),
	},
	CategoryColors = {
		All = Color3.fromRGB(91, 57, 47),
		Coffee = Color3.fromRGB(174, 101, 58),
		Tea = Color3.fromRGB(65, 178, 145),
		Pastry = Color3.fromRGB(247, 185, 63),
		Sandwich = Color3.fromRGB(237, 96, 76),
		Appliance = Color3.fromRGB(82, 142, 189),
		Seating = Color3.fromRGB(174, 101, 58),
		Decoration = Color3.fromRGB(65, 178, 145),
	},
	Glyphs = {
		Coin = "$",
		Money = "$",
		Reputation = "R",
		Level = "L",
		Buzz = "B",
		Coffee = "CF",
		Tea = "TE",
		Pastry = "PA",
		Sandwich = "FO",
		Goals = "GO",
		Cookbook = "CB",
		Build = "BU",
		Shop = "SH",
		Market = "MK",
		Store = "R$",
		Staff = "CR",
		Upgrades = "UP",
		Trophies = "TR",
		Map = "MP",
		Music = "MU",
		MusicOff = "MX",
		Settings = "OP",
		Pantry = "ST",
		Clock = "T",
		Fresh = "F",
		Auto = "A",
		Warning = "!",
		Close = "X",
	},
	Radius = {
		Small = 8,
		Medium = 12,
		Large = 18,
		Pill = 999,
	},
	Font = {
		Regular = Enum.Font.Gotham,
		Medium = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
		Black = Enum.Font.GothamBlack,
	},
	Motion = {
		Fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Panel = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Settle = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Count = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
	-- The chunky icon HUD (docs/HUD_REDESIGN.md). Every size, scale, and tint
	-- the dock, rail, and stat pills use lives here - controllers hold no
	-- layout literals.
	Hud = {
		-- Mobile baselines (2026-08-01). One source of truth so every surface
		-- agrees rather than each controller inventing its own number.
		--   TouchTarget — the minimum tappable square. 44 is the size both Apple
		--     and Google publish as the floor for a reliable finger press; below
		--     it, mis-taps climb sharply.
		TouchTarget = 44,
		-- Phone sizes are tuned against the measured world-visibility floor
		-- (phone >=55%), not picked by eye: six dock plates plus a five-button
		-- rail plus three pills is a lot of furniture on a 560px screen.
		--
		-- 2026-08-01: phone plates came down again (54 -> 46 dock, 40 -> 38 rail)
		-- now that names FLASH on tap instead of sitting pinned open under every
		-- button. The caption row was most of what made the dock tall. Both stay
		-- at or above TouchTarget (44) where they are the tap target; the rail's
		-- 38 is deliberate — its buttons are secondary and it is the widest thing
		-- on the right edge.
		DockPlate = { Desktop = 72, Phone = 46 },
		DockGap = 8,
		RailPlate = { Desktop = 46, Phone = 38 },
		RailPlateMin = 30,
		RailGap = 10,
		-- Viewports shorter than this get phone-sized plates and pills even when
		-- ResponsiveLayout calls them "Compact" - that is where landscape phones
		-- land, and desktop-sized chunky buttons swallow those screens.
		ShortViewport = 480,
		LabelHeight = 20,
		LabelTextSize = 12,
		LabelTextSizeTouch = 10,
		LabelBackgroundTransparency = 0.15,
		BadgeSize = 22,
		BadgeTextSize = 12,
		BadgeSizeBeside = 18,
		BadgeTextSizeBeside = 10,
		HoverScale = 1.1,
		PressScale = 0.94,
		StatPopScale = 1.08,
		PlateTint = Color3.fromRGB(255, 240, 214),
		PlateTintActive = Color3.fromRGB(255, 252, 240),
		IconTint = Color3.fromRGB(72, 45, 38),
		IconRatio = 0.62,
		StrokeTransparency = 0.55,
		StrokeTransparencyActive = 0.05,
		StatChip = {
			Width = { Desktop = 128, Phone = 92 },
			Height = { Desktop = 36, Phone = 28 },
			Gap = 6,
			Disc = { Desktop = 28, Phone = 24 },
			BackgroundTransparency = 0.15,
			ValueTextSize = { Desktop = 15, Phone = 13 },
		},
		StockDockHeight = { Desktop = 78, Compact = 56 },
		-- On a phone the stock dock turns VERTICAL: a narrow column of stacked
		-- dish slots instead of a wide, short strip (owner 2026-08-01: "make the
		-- pantry and production less wide and more length"). Narrow is the point —
		-- it frees the whole bottom edge for the six menu buttons.
		-- Header is two rows on a phone (status line, then a full-width PANTRY
		-- button) so the button is never squeezed against the status text.
		-- `Slots` CAPS how many dishes the dock shows: it is a glance widget, not
		-- the inventory, and reserving four slots left a block of empty black
		-- whenever fewer were active (owner 2026-08-01: "make it less lengthy").
		-- Shrunk 2026-08-06 (owner: the bottom-left is where a thumb naturally puts
		-- the joystick, and the dock was sitting on it). 132x110 -> 104x84, which
		-- is a quarter off each axis and hands the corner back to the stick.
		-- It can also be collapsed outright now — see HudToggleController.
		StockDockPhone = { Width = 104, SlotHeight = 26, Header = 32, Slots = 2 },
		-- The extreme top-right is ONE column, in this order: gift pill, VIP pill,
		-- order ticket, rail. It is declared here rather than inside each
		-- controller because those four pieces live in four different files, and
		-- the only way they never land on each other is by deriving from one set
		-- of numbers — `hudLayout` starts the ticket at `PillsBottom` + 8 and the
		-- rail below the ticket.
		Pills = { Top = 4, Gap = 4, Width = 132, GiftHeight = 28, VipHeight = 32 },
		EdgeMargin = 10,
	},
	-- Catalogue item pictures (shop rows, build rows, cookbook cards).
	Thumbnail = {
		RowSize = 56,
		CardSize = 46,
		Plate = Color3.fromRGB(247, 238, 220),
		-- Roblox has no GUI blur (BlurEffect is a Lighting post-process on the
		-- 3D world), and rbxthumb only serves 150px and 420px, so there is no
		-- low-resolution source to upscale either. A locked item is therefore
		-- blurred by compositing the same picture at many small offsets.
		-- Measured: 20 blurred rows = 260 ImageLabels, still 61 fps.
		Blur = { Samples = 14, Radius = 7, Transparency = 0.85 },
		VeilColor = Color3.fromRGB(55, 35, 31),
		VeilTransparency = 0.58,
		LockTextSize = 13,
	},
	-- Approved Creator Store images, with code-drawn glyphs retained as the
	-- automatic fallback if Roblox cannot fetch an image.
	Images = Graphics.UI,
}

return table.freeze(Theme)
