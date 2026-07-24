--!strict
-- Compact HUD, action dock, order ticket, shop, and shared panel coordination.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local AssetManifest = require(Shared.Config.AssetManifest)
local Graphics = require(Shared.Config.Graphics)
local Furniture = require(Shared.Config.Furniture)
local Recipes = require(Shared.Config.Recipes)
local Ingredients = require(Shared.Config.Ingredients)

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
	out_of_ingredients = "Out of ingredients - restock at the market.",
	plan_full = "That staff member's hours are full - lower another product first.",
	busy_cooking = "It is mid-batch - collect the food first.",
	wrong_appliance = "That recipe needs a different appliance.",
	menu_full = "Your menu is full - switch one item off first.",
	not_in_stock = "No fresh servings are ready.",
	already_carrying = "Deliver the item in your hand before taking another.",
	go_to_pass = "Walk to the glowing kitchen pass to pick this order up.",
	pick_up_first = "Pick the order up from the kitchen pass first.",
	wrong_table = "Wrong table - follow the table number on the order ticket.",
}

-- One declaration per HUD button: zone, slot, shortcut key, badge, label and
-- accent all live here (docs/HUD_REDESIGN.md §3). Controllers attach behaviour
-- with UIController.registerAction(id, callback); a button with no callback
-- explains itself through its comingSoon toast.
type HudButtonDefinition = {
	id: string,
	zone: "Dock" | "Rail",
	order: number,
	key: Enum.KeyCode,
	badge: string,
	label: string,
	accent: Color3,
	comingSoon: string?,
	-- An always-on switch rather than a panel: shows its state through tint,
	-- never through the raised "panel open" treatment.
	toggle: boolean?,
}

local HUD_BUTTONS: { HudButtonDefinition } = {
	{
		id = "Build",
		zone = "Dock",
		order = 1,
		key = Enum.KeyCode.One,
		badge = "1",
		label = "Build",
		accent = Theme.Colors.Coral,
	},
	{
		id = "Cookbook",
		zone = "Dock",
		order = 2,
		key = Enum.KeyCode.Two,
		badge = "2",
		label = "Cookbook",
		accent = Theme.Colors.MintDark,
	},
	{
		id = "Staff",
		zone = "Dock",
		order = 3,
		key = Enum.KeyCode.Three,
		badge = "3",
		label = "Staff",
		accent = Theme.Colors.Blue,
		comingSoon = "Mia, Noah and Pia run themselves for now - staff management is on the way.",
	},
	{
		id = "Upgrades",
		zone = "Dock",
		order = 4,
		key = Enum.KeyCode.Four,
		badge = "4",
		label = "Upgrades",
		accent = Theme.Colors.Honey,
		comingSoon = "Appliance upgrades are on the way.",
	},
	{
		id = "Shop",
		zone = "Dock",
		order = 5,
		key = Enum.KeyCode.Five,
		badge = "5",
		label = "Shop",
		accent = Theme.Colors.Berry,
	},
	{
		id = "Market",
		zone = "Dock",
		order = 6,
		key = Enum.KeyCode.Six,
		badge = "6",
		label = "Market",
		accent = Theme.Colors.Roast,
	},
	{
		id = "Goals",
		zone = "Rail",
		order = 1,
		key = Enum.KeyCode.G,
		badge = "G",
		label = "Goals",
		accent = Theme.Colors.Honey,
	},
	{
		id = "Trophies",
		zone = "Rail",
		order = 2,
		key = Enum.KeyCode.T,
		badge = "T",
		label = "Trophies",
		accent = Theme.Colors.Honey,
	},
	{
		id = "Map",
		zone = "Rail",
		order = 3,
		key = Enum.KeyCode.M,
		badge = "M",
		label = "Map",
		accent = Theme.Colors.Mint,
		comingSoon = "Stroll the boulevard to visit neighbours - a street map is on the way.",
	},
	{
		id = "Music",
		zone = "Rail",
		order = 4,
		key = Enum.KeyCode.B,
		badge = "B",
		label = "Music",
		accent = Theme.Colors.Mint,
		toggle = true,
	},
	{
		id = "Settings",
		zone = "Rail",
		order = 5,
		key = Enum.KeyCode.V,
		badge = "V",
		label = "Settings",
		accent = Theme.Colors.Roast,
		comingSoon = "The settings panel is on the way.",
	},
}

-- Stat pills, bottom-left, stacked above the stock dock. Semantic colours are
-- kept from the previous HUD: coins gold, reputation mint, buzz coral.
type StatDefinition = {
	key: string,
	profileKey: string,
	accent: Color3,
	order: number,
}

local STAT_DEFINITIONS: { StatDefinition } = {
	{ key = "Money", profileKey = "coins", accent = Theme.Colors.Honey, order = 1 },
	{ key = "Reputation", profileKey = "reputation", accent = Theme.Colors.Mint, order = 2 },
	{ key = "Buzz", profileKey = "buzz", accent = Theme.Colors.Coral, order = 3 },
}

local UIController = {}
UIController.Name = "UIController"
UIController.onBuildToggle = nil :: (() -> ())?

local profile: any = nil
local lastLevel: number? = nil
local currentOrderId: string? = nil
local carriedOrderId: string? = nil
local pendingOrders: { [string]: any } = {}
local profileListeners: { (any) -> () } = {}
local actionCallbacks: { [string]: () -> () } = {}
local actionHandles: { [string]: Components.IconButtonHandle } = {}
local actionActive: { [string]: boolean } = {}
local actionIconOverride: { [string]: { image: string?, glyph: string? } } = {}
local ui: { [string]: any } = {}
local activePanel: Frame? = nil
local shopRows: { [string]: any } = {}
local shopCategory = "All"
local touchMode = false
local builtKey: string? = nil

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
	for _, def in STAT_DEFINITIONS do
		local chip = ui.stats[def.key]
		if chip then
			local target = math.floor(tonumber(profile[def.profileKey]) or 0)
			if chip.shown == nil then
				-- First fill after join or a rebuild: no animation to play yet.
				chip.shown = target
				chip.counter.Value = target
				chip.value.Text = tostring(target)
			elseif chip.shown ~= target then
				chip.shown = target
				if chip.tween then
					chip.tween:Cancel()
				end
				local tween =
					TweenService:Create(chip.counter, Theme.Motion.Count, { Value = target })
				chip.tween = tween
				tween:Play()
				chip.scale.Scale = Theme.Hud.StatPopScale
				TweenService:Create(chip.scale, Theme.Motion.Fast, { Scale = 1 }):Play()
			end
		end
	end
	for id, row in shopRows do
		local def = Furniture[id]
		local level = tonumber(profile.level) or 1
		local levelLocked = level < def.requiredLevel
		local canBuy = not levelLocked and (tonumber(profile.coins) or 0) >= def.price
		row.buy.BackgroundColor3 = if canBuy then Theme.Colors.Coral else Theme.Colors.Muted
		row.buy.Text = if levelLocked then "LV " .. tostring(def.requiredLevel) else "BUY"
		-- Blur the picture only while the item is level-locked. Merely being
		-- short of coins is not a mystery - you can see what you are saving for.
		if row.locked ~= levelLocked then
			row.locked = levelLocked
			row.thumbnail.setLocked(levelLocked, "LV " .. tostring(def.requiredLevel))
		end
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

local function displayOrder(order: any)
	currentOrderId = tostring(order.orderId)
	local recipe = Recipes[tostring(order.recipeId)]
	ui.orderName.Text = (tostring(order.tableLabel or "TABLE") .. "  •  ")
		.. (if recipe then recipe.displayName else tostring(order.recipeId))
	ui.orderTicket.Visible = true
	ui.serve.Visible = true
	ui.serve.Text = "PICK UP AT PASS"
end

local function showNextOrder()
	if carriedOrderId and pendingOrders[carriedOrderId] then
		local carried = pendingOrders[carriedOrderId]
		currentOrderId = carriedOrderId
		ui.orderName.Text = "CARRY TO " .. tostring(carried.tableLabel or "THE TABLE")
		ui.orderTicket.Visible = true
		ui.serve.Visible = false
		return
	end
	local best: any = nil
	for _, order in pendingOrders do
		if
			best == nil
			or (tonumber(order.createdAtClock) or 0) < (tonumber(best.createdAtClock) or 0)
		then
			best = order
		end
	end
	if best then
		displayOrder(best)
	else
		currentOrderId = nil
		ui.orderTicket.Visible = false
		ui.serve.Visible = false
	end
end

local function showOrder(order: any)
	if typeof(order) ~= "table" or typeof(order.orderId) ~= "string" then
		return
	end
	pendingOrders[order.orderId] = order
	showNextOrder()
end

local function clearOrder(orderId: string?)
	if orderId then
		pendingOrders[orderId] = nil
		if carriedOrderId == orderId then
			carriedOrderId = nil
		end
	else
		pendingOrders = {}
		carriedOrderId = nil
	end
	showNextOrder()
end

local function createStat(parent: Instance, def: StatDefinition, phone: boolean)
	local spec = Theme.Hud.StatChip
	local width = if phone then spec.Width.Phone else spec.Width.Desktop
	local height = if phone then spec.Height.Phone else spec.Height.Desktop
	local discPx = if phone then spec.Disc.Phone else spec.Disc.Desktop
	local pad = math.floor((height - discPx) / 2)
	local chip = Instance.new("Frame")
	chip.Name = def.key
	chip.Size = UDim2.fromOffset(width, height)
	chip.BackgroundColor3 = Theme.Colors.Espresso
	chip.BackgroundTransparency = spec.BackgroundTransparency
	chip.LayoutOrder = def.order
	Components.Corner(chip, Theme.Radius.Pill)
	chip.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = chip
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, pad, 0.5, 0)
	disc.Size = UDim2.fromOffset(discPx, discPx)
	disc.BackgroundColor3 = def.accent
	Components.Corner(disc, Theme.Radius.Pill)
	Components.Gradient(disc, def.accent:Lerp(Theme.Colors.White, 0.25), def.accent, 90)
	disc.Parent = chip
	-- Full-colour pill art replaces the disc entirely rather than sitting on it:
	-- a coloured sticker on a coloured circle reads as two competing shapes.
	local fullColour = (Graphics.UIFullColour :: any)[def.key] == true
	if fullColour then
		disc.BackgroundTransparency = 1
		for _, child in disc:GetChildren() do
			if child:IsA("UIGradient") then
				child:Destroy()
			end
		end
	end
	local icon = Components.Icon(
		disc,
		Theme.Glyphs[def.key],
		Theme.Images[def.key],
		def.accent,
		if fullColour then discPx else discPx - 8,
		if fullColour then nil else Theme.Colors.White
	)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local value = Components.Label(
		chip,
		"0",
		if phone then spec.ValueTextSize.Phone else spec.ValueTextSize.Desktop,
		true
	)
	value.Size = UDim2.new(1, -(pad + discPx + 8 + pad), 1, 0)
	value.Position = UDim2.fromOffset(pad + discPx + 8, 0)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = Theme.Colors.Cream
	local counter = Instance.new("NumberValue")
	counter.Changed:Connect(function(current: number)
		value.Text = tostring(math.floor(current + 0.5))
	end)
	counter.Parent = chip
	ui.stats[def.key] = { value = value, counter = counter, scale = scale, shown = nil }
end

local function buildStats(phone: boolean)
	if not ui.statChips then
		return
	end
	for _, child in ui.statChips:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	ui.stats = {}
	for _, def in STAT_DEFINITIONS do
		createStat(ui.statChips, def, phone)
	end
	updateStats()
end

local function hudDefinition(id: string): HudButtonDefinition?
	for _, def in HUD_BUTTONS do
		if def.id == id then
			return def
		end
	end
	return nil
end

local function pressAction(id: string)
	local callback = actionCallbacks[id]
	if callback then
		callback()
		return
	end
	local def = hudDefinition(id)
	if def and def.comingSoon then
		UIController.toast(def.comingSoon)
	end
end

local function buildZone(zone: "Dock" | "Rail", parent: Frame, plate: number)
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local dock = zone == "Dock"
	for _, def in HUD_BUTTONS do
		if def.zone == zone then
			local override = actionIconOverride[def.id]
			local handle = Components.IconButton(parent, {
				name = def.label,
				glyph = if override and override.glyph
					then override.glyph
					else Theme.Glyphs[def.id],
				icon = if override then override.image else Theme.Images[def.id],
				accent = def.accent,
				size = plate,
				shape = if dock then "Square" else "Round",
				-- Letter badges are shortcut hints; they mean nothing without a
				-- keyboard. The 1-5 number badges stay: they are part of the
				-- dock's look.
				badge = if not dock and touchMode then nil else def.badge,
				badgePlacement = if dock then "Corner" else "Beside",
				fullColour = (Graphics.UIFullColour :: any)[def.id] == true,
				labelSide = if dock then "Bottom" else "Left",
				-- No hover on touch, so every name is pinned instead.
				alwaysShowLabel = touchMode,
				liftEnabled = not touchMode,
				persistentToggle = def.toggle == true,
				layoutOrder = def.order,
			})
			handle.button.Activated:Connect(function()
				pressAction(def.id)
			end)
			if actionActive[def.id] then
				handle.setActive(true)
			end
			actionHandles[def.id] = handle
		end
	end
end

function UIController.registerAction(id: string, callback: () -> ())
	actionCallbacks[id] = callback
end

function UIController.setActionActive(id: string, active: boolean)
	actionActive[id] = active
	local handle = actionHandles[id]
	if handle then
		handle.setActive(active)
	end
end

-- Keeps a HUD button's raised/bright state in sync with its panel, however
-- the panel gets opened or closed.
function UIController.bindActionPanel(id: string, panel: Frame)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		UIController.setActionActive(id, panel.Visible)
	end)
	UIController.setActionActive(id, panel.Visible)
end

function UIController.setActionIcon(id: string, image: string?, glyph: string?)
	actionIconOverride[id] = { image = image, glyph = glyph }
	local handle = actionHandles[id]
	if handle then
		handle.setIcon(image, glyph)
	end
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

-- Every catalogue id has a Creator Store model, so the row can show the real
-- item. Returns nil for anything unmapped, which falls back to the glyph badge.
local function assetIdFor(catalogId: string): number?
	local entry = (AssetManifest.furniture :: any)[catalogId]
	return if entry then entry.assetId else nil
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
		local thumbnail = Components.ItemThumbnail(row, {
			assetId = assetIdFor(id),
			size = Theme.Thumbnail.RowSize,
			glyph = Components.CategoryGlyph(def.category),
			accent = color,
		})
		thumbnail.root.Position = UDim2.fromOffset(8, 6)
		thumbnail.root.ZIndex = 23
		local name = Components.Label(row, def.displayName, 14, true)
		name.Size = UDim2.new(1, -170, 0, 24)
		name.Position = UDim2.fromOffset(72, 9)
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
		detail.Position = UDim2.fromOffset(72, 35)
		detail.TextColor3 = Theme.Colors.Muted
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.ZIndex = 23
		local buy = Components.Button(row, "BUY", Theme.Colors.Coral, UDim2.fromOffset(82, 42))
		buy.Position = UDim2.new(1, -92, 0.5, -21)
		buy.ZIndex = 23
		buy.Activated:Connect(function()
			Remotes.event("PurchaseItem"):FireServer(id)
		end)
		shopRows[id] = { frame = row, buy = buy, thumbnail = thumbnail, locked = nil }
	end
	ui.shopPanel = panel
	setShopCategory(shopCategory)
end

local function applyResponsive(mode: string, viewport: Vector2)
	if not ui.dock then
		return
	end
	local phone = mode == "Phone"
	local compact = mode ~= "Desktop"
	local margin = Theme.Hud.EdgeMargin
	local layout = ResponsiveLayout.hudLayout(mode :: ResponsiveLayout.Mode, viewport)

	-- Rebuild the plates only when a size actually changed, so ordinary window
	-- drags do not throw away every button and its state.
	local key = string.format("%s|%d|%d", mode, layout.dockPlate, layout.railPlate)
	if builtKey ~= key then
		builtKey = key
		buildZone("Dock", ui.dock, layout.dockPlate)
		buildZone("Rail", ui.rail, layout.railPlate)
		buildStats(layout.phoneSized)
	end

	ui.statChips.Position = UDim2.new(0, margin, 1, -layout.chipsBottom)
	ui.statChips.Size = UDim2.fromOffset(layout.chipWidth, layout.chipsHeight)

	ui.dock.Size = UDim2.fromOffset(layout.dockWidth, layout.dockPlate)
	ui.dock.Position = UDim2.new(0.5, layout.dockOffsetX, 1, -layout.dockBottom)

	ui.orderTicket.Size = if compact
		then UDim2.fromOffset(math.min(230, viewport.X - 150), layout.ticketHeight)
		else UDim2.fromOffset(280, layout.ticketHeight)
	ui.orderTicket.Position = UDim2.new(1, -10, 0, layout.ticketTop)
	ui.orderTicket.AnchorPoint = Vector2.new(1, 0)

	ui.rail.Size = UDim2.fromOffset(layout.railPlate, layout.railHeight)
	local railTop = layout.railTopFromTop
	if railTop then
		ui.rail.AnchorPoint = Vector2.new(1, 0)
		ui.rail.Position = UDim2.new(1, -margin, 0, railTop)
	else
		ui.rail.AnchorPoint = Vector2.new(1, 0.5)
		ui.rail.Position = UDim2.new(1, -margin, 0.5, 0)
	end
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
	ui.serve.Size = if compact
		then UDim2.fromOffset(142, layout.serveHeight)
		else UDim2.fromOffset(170, layout.serveHeight)
	ui.serve.Position = UDim2.new(0.5, layout.dockOffsetX, 1, -layout.serveBottom)
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

	touchMode = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

	local chips = Instance.new("Frame")
	chips.Name = "StatStack"
	chips.AnchorPoint = Vector2.new(0, 1)
	chips.BackgroundTransparency = 1
	chips.Parent = gui
	local statLayout = Instance.new("UIListLayout")
	statLayout.FillDirection = Enum.FillDirection.Vertical
	statLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	statLayout.Padding = UDim.new(0, Theme.Hud.StatChip.Gap)
	statLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statLayout.Parent = chips
	ui.stats = {}
	ui.statChips = chips

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

	local serve = Components.Button(
		gui,
		"PICK UP AT PASS",
		Theme.Colors.Mint,
		UDim2.fromOffset(170, 50),
		"GO"
	)
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

	local dock = Instance.new("Frame")
	dock.Name = "ActionDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.BackgroundTransparency = 1
	dock.Parent = gui
	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, Theme.Hud.DockGap)
	dockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dockLayout.Parent = dock
	ui.dock = dock

	local rail = Instance.new("Frame")
	rail.Name = "ActionRail"
	rail.BackgroundTransparency = 1
	rail.Parent = gui
	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	railLayout.Padding = UDim.new(0, Theme.Hud.RailGap)
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Parent = rail
	ui.rail = rail

	buildShop(modalRoot)
	UIController.registerAction("Shop", function()
		UIController.togglePanel(ui.shopPanel)
	end)
	UIController.bindActionPanel("Shop", ui.shopPanel)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		for _, def in HUD_BUTTONS do
			if def.key == input.KeyCode then
				pressAction(def.id)
				break
			end
		end
	end)

	Remotes.event("ProfileUpdated").OnClientEvent:Connect(setProfile)
	Remotes.event("OrderCreated").OnClientEvent:Connect(showOrder)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "served" then
			clearOrder(if typeof(msg.orderId) == "string" then msg.orderId else nil)
			UIController.toast("Sale complete  +$" .. tostring(msg.coins))
		elseif msg.kind == "order_picked_up" then
			carriedOrderId = tostring(msg.orderId)
			showNextOrder()
			UIController.toast("Order in hand - deliver it to " .. tostring(msg.tableLabel))
		elseif msg.kind == "offline_summary" then
			UIController.toast(
				"While away: +$"
					.. tostring(msg.earnings)
					.. " at 1/"
					.. tostring(msg.multiplier)
					.. " speed  •  Satisfaction -"
					.. tostring(msg.satisfactionLost)
			)
		elseif msg.kind == "no_plot" then
			-- Every café on this server is taken. Say so plainly instead of
			-- leaving the player poking at a build mode that silently does
			-- nothing; they are queued and get one as soon as somebody leaves.
			UIController.toast(
				"All cafés on this server are taken - you're #"
					.. tostring(msg.queued)
					.. " in line. Rejoin for a new server, or wait for one to free up."
			)
		elseif msg.kind == "plot_assigned" then
			UIController.toast("A café just opened up - it's yours! Welcome in.")
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
		elseif msg.kind == "ingredient_bought" then
			local def = (Ingredients :: any)[msg.item]
			local name = if def then def.displayName else tostring(msg.item)
			UIController.toast(
				"Bought " .. tostring(msg.qty) .. "x " .. name .. "  -$" .. tostring(msg.cost)
			)
		elseif msg.kind == "order_cancelled" then
			clearOrder(if typeof(msg.orderId) == "string" then msg.orderId else nil)
			UIController.toast("The customer left")
		elseif msg.kind == "order_fed_from_stock" then
			clearOrder(if typeof(msg.orderId) == "string" then msg.orderId else nil)
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

	-- Roblox generates an asset's preview server-side the first time anyone asks
	-- for it, which measured several seconds. Warm every catalogue picture in
	-- the background so the shop and build lists are never a wall of blanks the
	-- first time they open.
	task.spawn(function()
		local warm = {}
		local function stage(content: string)
			local image = Instance.new("ImageLabel")
			image.Image = content
			image.Visible = false
			image.Parent = gui
			table.insert(warm, image)
		end
		for _, entry in AssetManifest.furniture :: any do
			stage(Graphics.ItemThumbnail(entry.assetId))
		end
		for _, content in Graphics.Dishes :: any do
			stage(content)
		end
		pcall(function()
			ContentProvider:PreloadAsync(warm)
		end)
		for _, image in warm do
			image:Destroy()
		end
	end)

	ResponsiveLayout.watch(applyResponsive)
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
