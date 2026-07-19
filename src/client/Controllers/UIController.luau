--!strict
-- Compact HUD, action dock, order ticket, shop, and shared panel coordination.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Furniture = require(Shared.Config.Furniture)
local Recipes = require(Shared.Config.Recipes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local FRIENDLY_ERROR = {
	not_owned = "You do not own that item.",
	insufficient_coins = "Not enough coins.",
	level_locked = "Reach a higher level first.",
	out_of_bounds = "That does not fit on your plot.",
	overlap = "Something is already there.",
	too_many_objects = "Your cafe is full.",
	too_far = "Get closer to your counter.",
	not_rotatable = "That item cannot rotate.",
	plot_empty = "Nobody owns that cafe yet.",
	stove_busy = "That appliance is already cooking.",
	not_ready = "Not ready yet - give it a moment.",
	cant_afford_ingredients = "Not enough coins for ingredients.",
	busy_cooking = "It is mid-batch - collect the food first.",
	wrong_appliance = "That recipe needs a different appliance.",
	menu_full = "Your menu is full - switch one item off first.",
	not_in_stock = "No fresh servings are ready.",
}

type ActionDefinition = {
	id: string,
	label: string,
	glyph: string,
	color: Color3,
	order: number,
	callback: () -> (),
}

local UIController = {}
UIController.Name = "UIController"
UIController.onBuildToggle = nil :: (() -> ())?

local profile: any = nil
local lastLevel: number? = nil
local currentOrderId: string? = nil
local profileListeners: { (any) -> () } = {}
local actions: { [string]: ActionDefinition } = {}
local ui: { [string]: any } = {}
local activePanel: Frame? = nil
local shopRows: { [string]: any } = {}
local shopCategory = "All"
local actionExpanded = false

local function configureGui(gui: ScreenGui, order: number)
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
end

local function ensureModalRoot(): ScreenGui
	if ui.modalGui and ui.modalGui.Parent then
		return ui.modalGui
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("CafeModals")
	local modalGui: ScreenGui
	if existing and existing:IsA("ScreenGui") then
		modalGui = existing
	else
		modalGui = Instance.new("ScreenGui")
		modalGui.Name = "CafeModals"
		configureGui(modalGui, 20)
		modalGui.Parent = playerGui
	end
	ui.modalGui = modalGui
	return modalGui
end

function UIController.modalRoot(): ScreenGui
	return ensureModalRoot()
end

function UIController.getProfile(): any
	return profile
end

function UIController.subscribeProfile(cb: (any) -> ())
	table.insert(profileListeners, cb)
	if profile then
		cb(profile)
	end
end

function UIController.closePanel(panel: Frame?)
	local target = panel or activePanel
	if target then
		Components.SetPanelVisible(target, false)
	end
	if target == activePanel then
		activePanel = nil
	end
end

function UIController.togglePanel(panel: Frame)
	if panel.Visible then
		UIController.closePanel(panel)
		return
	end
	if activePanel and activePanel ~= panel then
		Components.SetPanelVisible(activePanel, false)
	end
	activePanel = panel
	Components.SetPanelVisible(panel, true)
end

function UIController.toast(text: string)
	if not ui.toast then
		return
	end
	ui.toast.Text = text
	ui.toast.Visible = true
	ui.toast.BackgroundTransparency = 0.08
	local token = os.clock()
	ui.toastToken = token
	task.delay(2.6, function()
		if ui.toastToken == token and ui.toast then
			local tween = TweenService:Create(ui.toast, Theme.Motion.Fast, {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			})
			tween:Play()
			tween.Completed:Wait()
			if ui.toastToken == token then
				ui.toast.Visible = false
				ui.toast.TextTransparency = 0
			end
		end
	end)
end

local function updateStats()
	if not profile or not ui.stats then
		return
	end
	ui.stats.Coins.Text = tostring(math.floor(tonumber(profile.coins) or 0))
	ui.stats.Reputation.Text = tostring(math.floor(tonumber(profile.reputation) or 0))
	ui.stats.Level.Text = tostring(math.floor(tonumber(profile.level) or 1))
	ui.stats.Buzz.Text = tostring(math.floor(tonumber(profile.buzz) or 0))
	for id, row in shopRows do
		local def = Furniture[id]
		local level = tonumber(profile.level) or 1
		local canBuy = level >= def.requiredLevel and (tonumber(profile.coins) or 0) >= def.price
		row.buy.BackgroundColor3 = if canBuy then Theme.Colors.Coral else Theme.Colors.Muted
		row.buy.Text = if level < def.requiredLevel
			then "LV " .. tostring(def.requiredLevel)
			else "BUY"
	end
end

local function celebrateLevel(level: number)
	if not ui.gui then
		return
	end
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.34)
	card.Size = UDim2.fromOffset(90, 38)
	card.BackgroundColor3 = Theme.Colors.Honey
	card.ZIndex = 100
	Components.Corner(card, Theme.Radius.Large)
	Components.Stroke(card, Theme.Colors.Cream, 2, 0.05)
	local label = Components.Label(card, "LEVEL " .. tostring(level) .. "!", 24, true)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Theme.Colors.Espresso
	label.ZIndex = 101
	card.Parent = ui.gui
	TweenService:Create(
		card,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(310, 84) }
	):Play()
	task.delay(1.5, function()
		local fade = TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		local textFade = TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 })
		fade:Play()
		textFade:Play()
		fade.Completed:Wait()
		card:Destroy()
	end)
end

local function setProfile(newProfile: any)
	profile = newProfile
	updateStats()
	local level = profile and tonumber(profile.level)
	if level and lastLevel and level > lastLevel then
		celebrateLevel(level)
	end
	if level then
		lastLevel = level
	end
	for _, cb in profileListeners do
		task.spawn(cb, profile)
	end
end

local function showOrder(order: any)
	currentOrderId = order.orderId
	local recipe = Recipes[tostring(order.recipeId)]
	ui.orderName.Text = if recipe then recipe.displayName else tostring(order.recipeId)
	ui.orderTicket.Visible = true
	ui.serve.Visible = true
end

local function clearOrder()
	currentOrderId = nil
	ui.orderTicket.Visible = false
	ui.serve.Visible = false
end

local function createStat(
	parent: Instance,
	key: string,
	glyph: string,
	color: Color3,
	order: number
)
	local chip = Instance.new("Frame")
	chip.Name = key
	chip.Size = UDim2.fromOffset(78, 34)
	chip.BackgroundColor3 = Theme.Colors.Roast
	chip.BackgroundTransparency = 0.18
	chip.LayoutOrder = order
	Components.Corner(chip, Theme.Radius.Pill)
	chip.Parent = parent
	local icon = Components.Icon(chip, glyph, Theme.Images[key], color, 24)
	icon.Position = UDim2.fromOffset(5, 5)
	local value = Components.Label(chip, "0", 14, true)
	value.Size = UDim2.new(1, -34, 1, 0)
	value.Position = UDim2.fromOffset(31, 0)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = Theme.Colors.Cream
	ui.stats[key] = value
end

local function actionList(): { ActionDefinition }
	local ordered = {}
	for _, action in actions do
		table.insert(ordered, action)
	end
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)
	return ordered
end

local function renderActions()
	if not ui.actionList then
		return
	end
	for _, child in ui.actionList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local compact = ResponsiveLayout.isCompact()
	for _, action in actionList() do
		local button = Components.Button(
			ui.actionList,
			if compact then "" else action.label,
			action.color,
			if compact then UDim2.fromOffset(44, 44) else UDim2.fromOffset(78, 44),
			action.glyph,
			Theme.Images[action.id]
		)
		button.Name = action.id .. "Action"
		button.LayoutOrder = action.order
		button.TextSize = if compact then 11 else 12
		button.Visible = not compact or actionExpanded
		button.Activated:Connect(action.callback)
	end
end

function UIController.registerAction(
	id: string,
	label: string,
	glyph: string,
	color: Color3,
	order: number,
	callback: () -> ()
)
	actions[id] = {
		id = id,
		label = label,
		glyph = glyph,
		color = color,
		order = order,
		callback = callback,
	}
	renderActions()
end

local function setShopCategory(category: string)
	shopCategory = category
	for id, row in shopRows do
		row.frame.Visible = category == "All" or Furniture[id].category == category
	end
	for name, button in ui.shopTabs or {} do
		button.BackgroundColor3 = if name == category
			then Theme.Colors.Coral
			else Theme.Colors.PaperDark
		button.TextColor3 = if name == category then Theme.Colors.White else Theme.Colors.Ink
	end
end

local function sortedFurnitureIds(): { string }
	local ids = {}
	for id in Furniture do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local left, right = Furniture[a], Furniture[b]
		if left.category == right.category then
			if left.requiredLevel == right.requiredLevel then
				return left.displayName < right.displayName
			end
			return left.requiredLevel < right.requiredLevel
		end
		return left.category < right.category
	end)
	return ids
end

local function buildShop(parent: Instance)
	local panel = Components.Panel(parent, "ShopPanel")
	panel.Size = UDim2.fromOffset(450, 540)
	panel.Position = UDim2.new(1, -238, 0.5, 0)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"CAFE MARKET",
		"Furniture, appliances, and decor",
		Theme.Colors.Berry
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -24, 0, 38)
	tabs.Position = UDim2.fromOffset(12, 72)
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 21
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	ui.shopTabs = {}
	for order, category in { "All", "Appliance", "Seating", "Decoration" } do
		local tab = Components.Button(
			tabs,
			if category == "Decoration" then "Decor" else category,
			Theme.Colors.PaperDark,
			UDim2.new(0.25, -5, 1, 0)
		)
		tab.LayoutOrder = order
		tab.TextColor3 = Theme.Colors.Ink
		tab.ZIndex = 22
		tab.Activated:Connect(function()
			setShopCategory(category)
		end)
		ui.shopTabs[category] = tab
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.Size = UDim2.new(1, -20, 1, -122)
	list.Position = UDim2.fromOffset(10, 116)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Coral
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for order, id in sortedFurnitureIds() do
		local def = Furniture[id]
		local row = Instance.new("Frame")
		row.Name = id
		row.Size = UDim2.new(1, -6, 0, 68)
		row.BackgroundColor3 = Theme.Colors.Paper
		row.LayoutOrder = order
		row.ZIndex = 22
		Components.Corner(row, Theme.Radius.Medium)
		Components.Stroke(row, Theme.Colors.Line, 1, 0.35)
		row.Parent = list
		local color = Components.CategoryColor(def.category)
		local icon = Components.Icon(row, Components.CategoryGlyph(def.category), nil, color, 42)
		icon.Position = UDim2.fromOffset(10, 13)
		icon.ZIndex = 23
		local name = Components.Label(row, def.displayName, 14, true)
		name.Size = UDim2.new(1, -170, 0, 24)
		name.Position = UDim2.fromOffset(62, 9)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 23
		local detail = Components.Label(
			row,
			string.format("%s  |  Lv %d  |  $%d", def.category, def.requiredLevel, def.price),
			11,
			false
		)
		detail.Size = UDim2.new(1, -170, 0, 20)
		detail.Position = UDim2.fromOffset(62, 35)
		detail.TextColor3 = Theme.Colors.Muted
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.ZIndex = 23
		local buy = Components.Button(row, "BUY", Theme.Colors.Coral, UDim2.fromOffset(82, 42))
		buy.Position = UDim2.new(1, -92, 0.5, -21)
		buy.ZIndex = 23
		buy.Activated:Connect(function()
			Remotes.event("PurchaseItem"):FireServer(id)
		end)
		shopRows[id] = { frame = row, buy = buy }
	end
	ui.shopPanel = panel
	setShopCategory(shopCategory)
end

local function applyResponsive(mode: string, viewport: Vector2)
	if not ui.statBar then
		return
	end
	local phone = mode == "Phone"
	local compact = mode ~= "Desktop"
	ui.statBar.Size = if compact
		then UDim2.fromOffset(math.min(viewport.X - 82, 292), 42)
		else UDim2.fromOffset(352, 46)
	ui.statBar.Position = if viewport.X >= 700
		then UDim2.fromOffset(270, 8)
		else UDim2.fromOffset(10, 52)
	for _, chip in ui.statChips:GetChildren() do
		if chip:IsA("Frame") then
			chip.Size = if compact then UDim2.new(0.25, -4, 0, 32) else UDim2.fromOffset(78, 34)
		end
	end
	ui.orderTicket.Size = if compact
		then UDim2.fromOffset(math.min(230, viewport.X - 150), 42)
		else UDim2.fromOffset(280, 48)
	ui.orderTicket.Position = if viewport.X < 1000
		then UDim2.new(1, -10, 0, 58)
		else UDim2.new(1, -10, 0, 9)
	ui.orderTicket.AnchorPoint = Vector2.new(1, 0)
	ui.actionDock.AnchorPoint = Vector2.new(1, 1)
	ui.actionDock.Position = UDim2.new(1, -12, 1, if compact then -96 else -12)
	ui.actionDock.Size = if compact
		then UDim2.fromOffset(if actionExpanded then 252 else 54, 48)
		else UDim2.fromOffset(334, 48)
	ui.actionMenu.Visible = compact
	ui.actionMenu.Text = if actionExpanded then "X" else "MENU"
	ui.actionList.Position = UDim2.fromOffset(0, 2)
	ui.actionList.Size = if compact then UDim2.new(1, -58, 1, -4) else UDim2.fromScale(1, 1)
	ui.actionMenu.Position = UDim2.new(1, -52, 0, 2)
	renderActions()
	local shop = ui.shopPanel
	if phone then
		shop.AnchorPoint = Vector2.new(0.5, 1)
		shop.Position = UDim2.new(0.5, 0, 1, -8)
		shop.Size = UDim2.new(1, -16, 0.74, 0)
	elseif compact then
		shop.AnchorPoint = Vector2.new(1, 0.5)
		shop.Position = UDim2.new(1, -8, 0.5, 0)
		shop.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.43, 326, 360), viewport.Y - 16)
	else
		shop.AnchorPoint = Vector2.new(0.5, 0.5)
		shop.Position = UDim2.new(1, -238, 0.5, 0)
		shop.Size = UDim2.fromOffset(450, math.min(540, viewport.Y - 24))
	end
	ui.serve.Size = if compact then UDim2.fromOffset(142, 46) else UDim2.fromOffset(170, 50)
	ui.serve.Position = UDim2.new(0.5, 0, 1, if viewport.X < 1000 then -126 else -18)
end

function UIController.Start(_self: any)
	local playerGui = player:WaitForChild("PlayerGui")
	local modalRoot = ensureModalRoot()
	local old = playerGui:FindFirstChild("HUD")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	configureGui(gui, 5)
	gui.Parent = playerGui
	ui.gui = gui

	local statBar = Instance.new("Frame")
	statBar.Name = "BusinessCapsule"
	statBar.Size = UDim2.fromOffset(352, 46)
	statBar.Position = UDim2.fromOffset(10, 8)
	statBar.BackgroundColor3 = Theme.Colors.Espresso
	statBar.BackgroundTransparency = 0.04
	Components.Corner(statBar, Theme.Radius.Large)
	Components.Stroke(statBar, Theme.Colors.Roast, 1, 0.1)
	Components.Gradient(statBar, Theme.Colors.Espresso, Theme.Colors.Roast, 0)
	statBar.Parent = gui
	ui.statBar = statBar

	local chips = Instance.new("Frame")
	chips.Name = "Stats"
	chips.Size = UDim2.new(1, -10, 1, 0)
	chips.Position = UDim2.fromOffset(5, 0)
	chips.BackgroundTransparency = 1
	chips.Parent = statBar
	local statLayout = Instance.new("UIListLayout")
	statLayout.FillDirection = Enum.FillDirection.Horizontal
	statLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statLayout.Padding = UDim.new(0, 6)
	statLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statLayout.Parent = chips
	ui.stats = {}
	ui.statChips = chips
	createStat(chips, "Coins", Theme.Glyphs.Coin, Theme.Colors.Honey, 1)
	createStat(chips, "Reputation", Theme.Glyphs.Reputation, Theme.Colors.Mint, 2)
	createStat(chips, "Level", Theme.Glyphs.Level, Theme.Colors.Blue, 3)
	createStat(chips, "Buzz", Theme.Glyphs.Buzz, Theme.Colors.Coral, 4)

	local ticket = Instance.new("Frame")
	ticket.Name = "OrderTicket"
	ticket.AnchorPoint = Vector2.new(0.5, 0)
	ticket.Size = UDim2.fromOffset(280, 48)
	ticket.Position = UDim2.new(0.5, 0, 0, 10)
	ticket.BackgroundColor3 = Theme.Colors.Paper
	ticket.Visible = false
	Components.Corner(ticket, Theme.Radius.Medium)
	Components.Stroke(ticket, Theme.Colors.Coral, 2, 0.05)
	ticket.Parent = gui
	local orderTag = Components.Label(ticket, "ORDER", 10, true)
	orderTag.Size = UDim2.fromOffset(54, 22)
	orderTag.Position = UDim2.fromOffset(8, 13)
	orderTag.BackgroundTransparency = 0
	orderTag.BackgroundColor3 = Theme.Colors.Coral
	orderTag.TextColor3 = Theme.Colors.White
	Components.Corner(orderTag, Theme.Radius.Pill)
	local orderName = Components.Label(ticket, "", 15, true)
	orderName.Size = UDim2.new(1, -76, 1, 0)
	orderName.Position = UDim2.fromOffset(70, 0)
	orderName.TextXAlignment = Enum.TextXAlignment.Left
	orderName.TextTruncate = Enum.TextTruncate.AtEnd
	ui.orderTicket = ticket
	ui.orderName = orderName

	local toast = Components.Label(gui, "", 14, true)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Size = UDim2.new(0.82, 0, 0, 38)
	toast.Position = UDim2.new(0.5, 0, 0, 66)
	toast.BackgroundTransparency = 0.08
	toast.BackgroundColor3 = Theme.Colors.Espresso
	toast.TextColor3 = Theme.Colors.Cream
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 90
	local toastCap = Instance.new("UISizeConstraint")
	toastCap.MaxSize = Vector2.new(520, 38)
	toastCap.Parent = toast
	Components.Corner(toast, Theme.Radius.Pill)
	ui.toast = toast

	local serve =
		Components.Button(gui, "SERVE", Theme.Colors.Mint, UDim2.fromOffset(170, 50), "GO")
	serve.Name = "ServeAction"
	serve.AnchorPoint = Vector2.new(0.5, 1)
	serve.Position = UDim2.new(0.5, 0, 1, -14)
	serve.TextSize = 16
	serve.Visible = false
	serve.Activated:Connect(function()
		if currentOrderId then
			Remotes.event("ClaimOrder"):FireServer(currentOrderId, false)
		end
	end)
	ui.serve = serve

	local actionDock = Instance.new("Frame")
	actionDock.Name = "ActionDock"
	actionDock.AnchorPoint = Vector2.new(1, 1)
	actionDock.Size = UDim2.fromOffset(334, 48)
	actionDock.Position = UDim2.new(1, -12, 1, -12)
	actionDock.BackgroundColor3 = Theme.Colors.Espresso
	actionDock.BackgroundTransparency = 0.08
	Components.Corner(actionDock, Theme.Radius.Large)
	Components.Stroke(actionDock, Theme.Colors.Cream, 1, 0.7)
	actionDock.Parent = gui
	local actionListFrame = Instance.new("Frame")
	actionListFrame.Name = "Actions"
	actionListFrame.Size = UDim2.fromScale(1, 1)
	actionListFrame.BackgroundTransparency = 1
	actionListFrame.Parent = actionDock
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Padding = UDim.new(0, 6)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionListFrame
	local actionMenu =
		Components.Button(actionDock, "MENU", Theme.Colors.Roast, UDim2.fromOffset(50, 44))
	actionMenu.Name = "MenuToggle"
	actionMenu.Visible = false
	actionMenu.TextSize = 10
	actionMenu.Activated:Connect(function()
		actionExpanded = not actionExpanded
		local camera = workspace.CurrentCamera
		if camera then
			applyResponsive(ResponsiveLayout.mode(camera.ViewportSize), camera.ViewportSize)
		end
	end)
	ui.actionDock = actionDock
	ui.actionList = actionListFrame
	ui.actionMenu = actionMenu

	buildShop(modalRoot)
	UIController.registerAction(
		"Shop",
		"Shop",
		Theme.Glyphs.Shop,
		Theme.Colors.Berry,
		40,
		function()
			UIController.togglePanel(ui.shopPanel)
		end
	)

	Remotes.event("ProfileUpdated").OnClientEvent:Connect(setProfile)
	Remotes.event("OrderCreated").OnClientEvent:Connect(showOrder)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "served" then
			clearOrder()
			UIController.toast("Sale complete  +$" .. tostring(msg.coins))
		elseif msg.kind == "recipe_unlocked" then
			UIController.toast("New recipe unlocked: " .. tostring(msg.recipe))
		elseif msg.kind == "mastery_up" then
			UIController.toast(tostring(msg.recipe) .. " mastery reached " .. tostring(msg.stars))
		elseif msg.kind == "cook_started" then
			UIController.toast(tostring(msg.recipe) .. " is cooking")
		elseif msg.kind == "cook_collected" then
			UIController.toast(
				"Collected " .. tostring(msg.servings) .. " " .. tostring(msg.recipe)
			)
		elseif msg.kind == "purchased" then
			UIController.toast("Purchased - open Build to place it")
		elseif msg.kind == "order_cancelled" then
			clearOrder()
			UIController.toast("The customer left")
		elseif msg.kind == "order_fed_from_stock" then
			clearOrder()
			UIController.toast("The waiter served from fresh stock")
		elseif msg.kind == "visitor" then
			UIController.toast(tostring(msg.name) .. " is visiting your cafe")
		elseif msg.kind == "compliment" then
			UIController.toast(
				tostring(msg.from) .. ": " .. tostring(msg.text) .. "  +2 reputation"
			)
		elseif msg.kind == "error" then
			UIController.toast(FRIENDLY_ERROR[msg.reason] or tostring(msg.reason))
		end
	end)

	ResponsiveLayout.watch(applyResponsive)
	renderActions()
	task.spawn(function()
		local snapshot: any = nil
		local ok = pcall(function()
			snapshot = Remotes.func("RequestProfile"):InvokeServer()
		end)
		if ok and snapshot then
			setProfile(snapshot)
		end
	end)
end

return UIController
