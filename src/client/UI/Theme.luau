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
		-- Phone sizes are tuned against the measured world-visibility floor
		-- (phone >=55%), not picked by eye: five dock plates plus a five-button
		-- rail plus three pills is a lot of furniture on a 560px screen.
		DockPlate = { Desktop = 72, Phone = 54 },
		DockGap = 10,
		RailPlate = { Desktop = 46, Phone = 40 },
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
