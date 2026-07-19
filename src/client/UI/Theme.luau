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
	},
	-- Approved Creator Store images, with code-drawn glyphs retained as the
	-- automatic fallback if Roblox cannot fetch an image.
	Images = Graphics.UI,
}

return table.freeze(Theme)
