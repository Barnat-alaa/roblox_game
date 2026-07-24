--!strict
-- The Market — buy ingredients in bulk AND see your pantry inventory, in one
-- panel (owner request). Each row is an ingredient: its icon, how many you own,
-- its rarity, and bulk-buy buttons (x25 / x50 / x100 / x250 / Max) with the
-- price. Locked ingredients show blurred with their unlock level, exactly like
-- the shop and cookbook. Server-authoritative: buttons only REQUEST a buy
-- (MarketBuyIngredient); EconomyService decides and MarketMath prices — the same
-- MarketMath the buttons preview with, so the shown price is the charged price.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ingredients = require(Shared.Config.Ingredients)
local Economy = require(Shared.Config.Economy)
local MarketMath = require(Shared.Utilities.MarketMath)
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local MarketController = {}
MarketController.Name = "MarketController"

local ui: { [string]: any } = {}

local RARITY_COLOR: { [string]: Color3 } = {
	common = Theme.Colors.Muted,
	uncommon = Theme.Colors.Blue,
	rare = Theme.Colors.Berry,
}

local function sortedIngredientIds(): { string }
	local ids = {}
	for id in Ingredients do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local A, B = Ingredients[a], Ingredients[b]
		if A.unlockLevel ~= B.unlockLevel then
			return A.unlockLevel < B.unlockLevel
		end
		return A.displayName < B.displayName
	end)
	return ids
end

-- Largest quantity (capped) the player can afford at MarketMath prices.
local function maxAffordable(ingredientId: string, coins: number): number
	local lo, hi = 0, Economy.maxIngredientBuy
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if MarketMath.costFor(ingredientId, mid) <= coins then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

local function buy(ingredientId: string, qty: number)
	if qty <= 0 then
		return
	end
	Remotes.event("MarketBuyIngredient"):FireServer({ ingredientId = ingredientId, qty = qty })
end

local function rebuild()
	local profile = UIController.getProfile()
	if not profile or not ui.list then
		return
	end
	ui.list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list

	local level = tonumber(profile.level) or 1
	local coins = tonumber(profile.coins) or 0
	local pantry = profile.pantry or {}
	local lowThreshold = tonumber(Economy.lowIngredientThreshold) or 5
	local outCount = 0

	for order, id in sortedIngredientIds() do
		local def = Ingredients[id]
		local locked = level < def.unlockLevel
		local owned = math.floor(tonumber(pantry[id]) or 0)
		-- Stock state drives the critical warning (CORE_LOOP_SPEC §3b). Locked
		-- ingredients you can't use yet never read as "OUT".
		local stockState = "ok"
		if not locked then
			if owned <= 0 then
				stockState = "out"
				outCount += 1
			elseif owned <= lowThreshold then
				stockState = "low"
			end
		end

		local card = Instance.new("Frame")
		card.Name = id
		card.Size = UDim2.new(1, -6, 0, 96)
		card.BackgroundColor3 = if locked then Color3.fromRGB(78, 65, 61) else Theme.Colors.Paper
		card.LayoutOrder = order
		card.ZIndex = 22
		Components.Corner(card, Theme.Radius.Medium)
		Components.Stroke(card, if locked then Theme.Colors.Roast else Theme.Colors.Line, 1, 0.25)
		card.Parent = ui.list

		local accent = RARITY_COLOR[def.rarity] or Theme.Colors.Muted
		local thumb = Components.ItemThumbnail(card, {
			glyph = def.icon,
			size = Theme.Thumbnail.CardSize,
			accent = accent,
			locked = locked,
			lockLabel = "LV " .. tostring(def.unlockLevel),
		})
		thumb.root.Position = UDim2.fromOffset(10, 10)
		thumb.root.ZIndex = 23

		local title = Components.Label(card, def.displayName, 14, true)
		title.Size = UDim2.new(1, -168, 0, 22)
		title.Position = UDim2.fromOffset(68, 8)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = if locked then Theme.Colors.Cream else Theme.Colors.Ink
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.ZIndex = 23

		-- Rarity + how many you own = the inventory, right here on the buy row;
		-- turns orange when low, red when out, so you know to restock.
		local subText = string.format("%s  •  Owned: %d", def.rarity, owned)
		local subColor = if locked then Theme.Colors.PaperDark else Theme.Colors.Muted
		if stockState == "out" then
			subText = "⚠ OUT — buy now"
			subColor = Theme.Colors.Danger
		elseif stockState == "low" then
			subText = string.format("⚠ Low — %d left", owned)
			subColor = Theme.Colors.Coral
		end
		local sub = Components.Label(card, subText, 11, stockState ~= "ok")
		sub.Size = UDim2.new(1, -168, 0, 18)
		sub.Position = UDim2.fromOffset(68, 30)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = subColor
		sub.ZIndex = 23

		-- Owned count as a pill on the right (the at-a-glance inventory number),
		-- colour-coded to the stock state.
		local ownedPill = Components.Label(card, "x" .. tostring(owned), 13, true)
		ownedPill.Size = UDim2.fromOffset(70, 26)
		ownedPill.Position = UDim2.new(1, -80, 0, 10)
		ownedPill.BackgroundTransparency = 0
		ownedPill.BackgroundColor3 = if stockState == "out"
			then Theme.Colors.Danger
			elseif stockState == "low" then Theme.Colors.Honey
			elseif owned > 0 then accent
			else Theme.Colors.PaperDark
		ownedPill.TextColor3 = if stockState == "out" or owned > 0
			then Theme.Colors.White
			else Theme.Colors.Muted
		ownedPill.ZIndex = 23
		Components.Corner(ownedPill, Theme.Radius.Pill)

		if locked then
			local hint =
				Components.Label(card, "Unlock at level " .. tostring(def.unlockLevel), 12, true)
			hint.Size = UDim2.new(1, -78, 0, 30)
			hint.Position = UDim2.fromOffset(68, 56)
			hint.TextXAlignment = Enum.TextXAlignment.Left
			hint.TextColor3 = Theme.Colors.Cream
			hint.ZIndex = 23
		else
			local buttonRow = Instance.new("Frame")
			buttonRow.Size = UDim2.new(1, -78, 0, 32)
			buttonRow.Position = UDim2.fromOffset(68, 56)
			buttonRow.BackgroundTransparency = 1
			buttonRow.ZIndex = 22
			buttonRow.Parent = card
			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.Padding = UDim.new(0, 4)
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Parent = buttonRow

			local tiers = {}
			for _, t in Economy.bulkTiers do
				table.insert(tiers, t)
			end
			for slot, tier in tiers do
				local cost = MarketMath.costFor(id, tier)
				local affordable = cost <= coins
				local button = Components.Button(
					buttonRow,
					string.format("x%d\n$%d", tier, cost),
					if affordable then accent else Theme.Colors.PaperDark,
					UDim2.new(0.2, -4, 1, 0)
				)
				button.LayoutOrder = slot
				button.TextSize = 11
				button.TextColor3 = if affordable then Theme.Colors.White else Theme.Colors.Muted
				button.ZIndex = 23
				button.Activated:Connect(function()
					buy(id, tier)
				end)
			end

			-- Max: everything the player can afford right now.
			local maxQty = maxAffordable(id, coins)
			local maxCost = MarketMath.costFor(id, maxQty)
			local maxButton = Components.Button(
				buttonRow,
				if maxQty > 0 then string.format("MAX\n$%d", maxCost) else "MAX",
				if maxQty > 0 then Theme.Colors.MintDark else Theme.Colors.PaperDark,
				UDim2.new(0.2, -4, 1, 0)
			)
			maxButton.LayoutOrder = #tiers + 1
			maxButton.TextSize = 11
			maxButton.TextColor3 = if maxQty > 0 then Theme.Colors.White else Theme.Colors.Muted
			maxButton.ZIndex = 23
			maxButton.Activated:Connect(function()
				local p = UIController.getProfile()
				if p then
					buy(id, maxAffordable(id, tonumber(p.coins) or 0))
				end
			end)
		end
	end

	-- Critical banner at the top of the list when anything is out of stock.
	if outCount > 0 then
		local banner = Instance.new("Frame")
		banner.Name = "OutOfStockBanner"
		banner.Size = UDim2.new(1, -6, 0, 34)
		banner.BackgroundColor3 = Theme.Colors.Danger
		banner.LayoutOrder = 0
		banner.ZIndex = 24
		Components.Corner(banner, Theme.Radius.Medium)
		banner.Parent = ui.list
		local plural = if outCount == 1 then "" else "s"
		local label = Components.Label(
			banner,
			string.format("⚠ %d ingredient%s OUT — restock below", outCount, plural),
			13,
			true
		)
		label.Size = UDim2.fromScale(1, 1)
		label.TextColor3 = Theme.Colors.White
		label.ZIndex = 25
	end
end

local function applyResponsive(mode: string, viewport: Vector2)
	local panel = ui.panel
	if not panel then
		return
	end
	if mode == "Phone" then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -8)
		panel.Size = UDim2.new(1, -16, 0.74, 0)
	elseif mode == "Compact" then
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -8, 0.5, 0)
		panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.46, 360, 420), viewport.Y - 16)
	else
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(540, 580)
	end
end

function MarketController.Start(_self: any)
	local panel = Components.Panel(UIController.modalRoot(), "MarketPanel")
	panel.Size = UDim2.fromOffset(540, 580)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"MARKET",
		"Buy ingredients in bulk — and your pantry",
		Theme.Colors.Roast
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -80)
	list.Position = UDim2.fromOffset(10, 72)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Roast
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	ui.list = list
	ui.panel = panel

	UIController.registerAction("Market", function()
		UIController.togglePanel(panel)
		if panel.Visible then
			rebuild()
		end
	end)
	UIController.bindActionPanel("Market", panel)
	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)
	ResponsiveLayout.watch(applyResponsive)
end

return MarketController
