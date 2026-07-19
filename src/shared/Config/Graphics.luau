--!strict
-- Owner-approved Creator Store graphics. Decal listings are addressed through
-- rbxthumb because their listing IDs are not raw image IDs; the simulator pack
-- exposes its underlying image IDs directly.

local function thumbnail(assetId: number): string
	return string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", assetId)
end

local Graphics = {
	SourceAssets = {
		SimulatorIcons = 99176447965360,
		RetroFood = 134670664555156,
		Coin = 6020249531,
		Sidewalk = 2922135969,
		RoadStraight = 17092935,
		RoadLeft = 17093010,
		RoadRight = 17092971,
		WoodFloor = 136501975130226,
		Sky = 4462186698,
	},
	UI = {
		Coin = thumbnail(6020249531),
		Reputation = "rbxassetid://17368097932", -- Simulator pack: star
		Level = "rbxassetid://17368045028", -- Simulator pack: upgrade arrow
		Buzz = "rbxassetid://15403144723", -- Simulator pack: fire
		Goals = "rbxassetid://17368118782", -- Simulator pack: quests
		Cookbook = "rbxassetid://127110909372919", -- Simulator pack: index
		Build = "rbxassetid://15403180857", -- Simulator pack: house
		Shop = "rbxassetid://17368188494", -- Simulator pack: shop
		Pantry = "rbxassetid://15402958715", -- Simulator pack: inventory
	},
	Surfaces = {
		Sidewalk = thumbnail(2922135969),
		RoadStraight = thumbnail(17092935),
		RoadLeft = thumbnail(17093010),
		RoadRight = thumbnail(17092971),
		WoodFloor = thumbnail(136501975130226),
		Sky = thumbnail(4462186698),
	},
}

return table.freeze(Graphics)
