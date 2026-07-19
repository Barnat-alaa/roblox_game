--!strict
-- Compact active-stock dock and responsive Pantry/Production drawer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local Staff = require(Shared.Config.Staff)
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local InventoryController = {}
InventoryController.Name = "InventoryController"

local player = Players.LocalPlayer
local profile: any = nil
local ui: { [string]: any } = {}
local dockSlots: { any } = {}
local stockRows: { [string]: any } = {}
local productionRows: { [string]: any } = {}
local selectedTab = "Stock"
local selectedCategory = "All"

local function sortedRecipeIds(): { string }
	local ids = {}
	for id in Recipes do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local left, right = Recipes[a], Recipes[b]
		if left.requiredLevel == right.requiredLevel then
			return left.displayName < right.displayName
		end
		return left.requiredLevel < right.requiredLevel
	end)
	return ids
end

local RECIPE_IDS = sortedRecipeIds()

local function kitchen(): any
	return if profile and typeof(profile.kitchen) == "table" then profile.kitchen else {}
end

local function hasAppliance(recipeId: string): boolean
	if not profile then
		return false
	end
	local wanted = Recipes[recipeId].applianceId
	for _, placed in profile.placedFurniture or {} do
		if placed.catalogId == wanted then
			return true
		end
	end
	return false
end

local function hasRole(role: string): boolean
	if not profile then
		return false
	end
	for _, member in profile.staff or {} do
		local definition = Staff[member.typeId]
		if definition and definition.role == role then
			return true
		end
	end
	return false
end

local function incomingFor(recipeId: string): (number, number?)
	local quantity = 0
	local soonest: number? = nil
	for _, job in kitchen().jobs or {} do
		if job.recipeId == recipeId then
			quantity += math.max(0, tonumber(job.yield) or 0)
			local completesAt = tonumber(job.completesAt)
			if completesAt and (soonest == nil or completesAt < (soonest :: number)) then
				soonest = completesAt
			end
		end
	end
	return quantity, soonest
end

local function lotDetails(recipeId: string): (number, number?)
	local reserved = 0
	local expiry: number? = nil
	local recipeLots = (kitchen().lots or {})[recipeId]
	if typeof(recipeLots) == "table" then
		for _, lot in recipeLots do
			if (tonumber(lot.quantity) or 0) > 0 then
				reserved += math.max(0, tonumber(lot.reserved) or 0)
				local expiresAt = tonumber(lot.expiresAt)
				if expiresAt and (expiry == nil or expiresAt < (expiry :: number)) then
					expiry = expiresAt
				end
			end
		end
	end
	return reserved, expiry
end

local function shortTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return tostring(math.floor(seconds / 3600)) .. "h"
	elseif seconds >= 60 then
		return tostring(math.floor(seconds / 60)) .. "m"
	end
	return tostring(seconds) .. "s"
end

local function stateFor(recipeId: string): (string, Color3)
	local recipe = Recipes[recipeId]
	if not profile or profile.unlockedRecipes[recipeId] ~= true then
		return "LOCKED LV " .. tostring(recipe.requiredLevel), Theme.Colors.Muted
	end
	if not hasAppliance(recipeId) then
		return "NEEDS APPLIANCE", Theme.Colors.Berry
	end
	if not hasRole(recipe.staffRole) then
		return "NEEDS " .. string.upper(recipe.staffRole), Theme.Colors.Berry
	end
	local stock = tonumber((kitchen().stock or {})[recipeId]) or 0
	local target = tonumber((kitchen().targetStock or {})[recipeId]) or 0
	local incoming = incomingFor(recipeId)
	if (kitchen().menu or {})[recipeId] ~= true then
		return "OFF MENU", Theme.Colors.Muted
	elseif stock <= 0 and incoming <= 0 then
		return "OUT", Theme.Colors.Danger
	elseif incoming > 0 then
		return "COOKING", Theme.Colors.Mint
	elseif stock < math.max(1, target / 2) then
		return "LOW", Theme.Colors.Honey
	elseif target > 0 and stock > target then
		return "SURPLUS", Theme.Colors.Berry
	end
	return "FRESH", Theme.Colors.Mint
end

local function activeRecipeIds(): { string }
	local ids = {}
	if not profile then
		return ids
	end
	for _, id in RECIPE_IDS do
		if profile.unlockedRecipes[id] == true and (kitchen().menu or {})[id] == true then
			table.insert(ids, id)
		end
	end
	return ids
end

local function categoryMatches(recipeId: string): boolean
	if selectedCategory == "All" then
		return true
	elseif selectedCategory == "Food" then
		return Recipes[recipeId].category == "Sandwich"
	end
	return Recipes[recipeId].category == selectedCategory
end

local function updateFilters()
	for id, row in stockRows do
		row.frame.Visible = selectedTab == "Stock" and categoryMatches(id)
	end
	for id, row in productionRows do
		row.frame.Visible = selectedTab == "Production" and categoryMatches(id)
	end
	ui.stockList.Visible = selectedTab == "Stock"
	ui.productionList.Visible = selectedTab == "Production"
	for tab, button in ui.mainTabs do
		button.BackgroundColor3 = if tab == selectedTab
			then Theme.Colors.Coral
			else Theme.Colors.PaperDark
		button.TextColor3 = if tab == selectedTab then Theme.Colors.White else Theme.Colors.Ink
	end
	for category, button in ui.categoryTabs do
		button.BackgroundColor3 = if category == selectedCategory
			then Components.CategoryColor(if category == "Food" then "Sandwich" else category)
			else Theme.Colors.PaperDark
		button.TextColor3 = if category == selectedCategory
			then Theme.Colors.White
			else Theme.Colors.Ink
	end
end

local function updatePulse()
	if not profile or not ui.pulse then
		return
	end
	local low, cooking, ready = 0, 0, 0
	for _, id in activeRecipeIds() do
		local stock = tonumber((kitchen().stock or {})[id]) or 0
		local incoming = incomingFor(id)
		if stock <= 0 then
			low += 1
		else
			ready += stock
		end
		if incoming > 0 then
			cooking += 1
		end
	end
	if not hasRole("Waiter") then
		ui.pulse.Text = "HIRE A WAITER"
		ui.pulse.TextColor3 = Theme.Colors.Berry
	elseif low > 0 then
		ui.pulse.Text = string.format("%d LOW  |  %d COOKING", low, cooking)
		ui.pulse.TextColor3 = Theme.Colors.Coral
	else
		ui.pulse.Text = string.format("%d READY  |  %d COOKING", ready, cooking)
		ui.pulse.TextColor3 = Theme.Colors.Mint
	end
end

local function updateDock()
	local active = activeRecipeIds()
	local compact = ResponsiveLayout.isCompact()
	if compact then
		ui.dock.Size = UDim2.fromOffset(math.clamp(132 + #active * 62, 226, 344), 56)
	end
	local slotCount = math.max(1, #active)
	for index, slot in dockSlots do
		local id = active[index]
		slot.frame.Visible = id ~= nil
		slot.frame.Size = if compact
			then UDim2.new(1 / slotCount, -5, 1, 0)
			else UDim2.new(0.25, -5, 1, 0)
		if id then
			local recipe = Recipes[id]
			local stock = tonumber((kitchen().stock or {})[id]) or 0
			local state, stateColor = stateFor(id)
			slot.recipeId = id
			slot.name.Text = recipe.displayName
			slot.count.Text = tostring(stock)
			slot.dot.BackgroundColor3 = stateColor
			slot.state.Text = state
			slot.icon.Text = Components.CategoryGlyph(recipe.category)
			slot.icon.BackgroundColor3 = Components.CategoryColor(recipe.category)
		end
	end
	ui.empty.Visible = #active == 0
	updatePulse()
end

local function updateStockRow(recipeId: string)
	local row = stockRows[recipeId]
	if not row then
		return
	end
	local unlocked = profile and profile.unlockedRecipes[recipeId] == true
	local stock = tonumber((kitchen().stock or {})[recipeId]) or 0
	local reserved, expiry = lotDetails(recipeId)
	local incoming, completesAt = incomingFor(recipeId)
	local state, color = stateFor(recipeId)
	row.count.Text = tostring(stock)
	row.state.Text = state
	row.state.BackgroundColor3 = color
	row.frame.BackgroundTransparency = if unlocked then 0 else 0.22
	if not unlocked then
		row.detail.Text = "Unlock at level " .. tostring(Recipes[recipeId].requiredLevel)
	elseif incoming > 0 and completesAt then
		row.detail.Text = "+"
			.. tostring(incoming)
			.. " ready in "
			.. shortTime(completesAt - os.time())
	elseif expiry then
		row.detail.Text = "Fresh for " .. shortTime(expiry - os.time())
	elseif reserved > 0 then
		row.detail.Text = tostring(reserved) .. " reserved for service"
	else
		row.detail.Text = "No active batch"
	end
end

local function updateProductionRow(recipeId: string)
	local row = productionRows[recipeId]
	if not row then
		return
	end
	local unlocked = profile and profile.unlockedRecipes[recipeId] == true
	local active = unlocked and (kitchen().menu or {})[recipeId] == true
	local target = tonumber((kitchen().targetStock or {})[recipeId]) or 0
	local priority = tonumber((kitchen().priorities or {})[recipeId]) or 1
	local state, stateColor = stateFor(recipeId)
	row.toggle.Text = if not unlocked then "LOCKED" elseif active then "AUTO ON" else "AUTO OFF"
	row.toggle.BackgroundColor3 = if active then Theme.Colors.Mint else Theme.Colors.Muted
	row.target.Text = tostring(target)
	row.priority.Text = "P" .. tostring(priority)
	row.status.Text = state
	row.status.TextColor3 = stateColor
	row.minus.Active = unlocked
	row.plus.Active = unlocked
	row.priority.Active = unlocked
end

local function updateAll()
	updateDock()
	for _, id in RECIPE_IDS do
		updateStockRow(id)
		updateProductionRow(id)
	end
end

local function makeDockSlot(parent: Instance, order: number)
	local frame = Instance.new("Frame")
	frame.Name = "Slot" .. tostring(order)
	frame.Size = UDim2.new(0.25, -5, 1, 0)
	frame.BackgroundColor3 = Theme.Colors.Paper
	frame.LayoutOrder = order
	frame.Visible = false
	Components.Corner(frame, Theme.Radius.Small)
	Components.Stroke(frame, Theme.Colors.Line, 1, 0.45)
	frame.Parent = parent
	local icon = Components.Label(frame, "", 9, true)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.Position = UDim2.fromOffset(5, 5)
	icon.BackgroundTransparency = 0
	icon.TextColor3 = Theme.Colors.White
	Components.Corner(icon, 14)
	local name = Components.Label(frame, "", 10, true)
	name.Size = UDim2.new(1, -44, 0, 18)
	name.Position = UDim2.fromOffset(38, 3)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local count = Components.Label(frame, "0", 16, true)
	count.Size = UDim2.fromOffset(34, 22)
	count.Position = UDim2.new(1, -38, 0, 19)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(7, 7)
	dot.Position = UDim2.fromOffset(38, 27)
	dot.BackgroundColor3 = Theme.Colors.Muted
	Components.Corner(dot, 4)
	dot.Parent = frame
	local state = Components.Label(frame, "", 8, true)
	state.Size = UDim2.new(1, -70, 0, 14)
	state.Position = UDim2.fromOffset(48, 23)
	state.TextColor3 = Theme.Colors.Muted
	state.TextXAlignment = Enum.TextXAlignment.Left
	local slot =
		{ frame = frame, icon = icon, name = name, count = count, dot = dot, state = state }
	table.insert(dockSlots, slot)
	frame.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UIController.togglePanel(ui.drawer)
		end
	end)
end

local function makeStockRow(parent: Instance, recipeId: string, order: number)
	local recipe = Recipes[recipeId]
	local row = Instance.new("Frame")
	row.Name = recipeId
	row.Size = UDim2.new(1, -6, 0, 72)
	row.BackgroundColor3 = Theme.Colors.Paper
	row.LayoutOrder = order
	row.ZIndex = 22
	Components.Corner(row, Theme.Radius.Medium)
	Components.Stroke(row, Theme.Colors.Line, 1, 0.4)
	row.Parent = parent
	local color = Components.CategoryColor(recipe.category)
	local icon = Components.Icon(row, Components.CategoryGlyph(recipe.category), nil, color, 42)
	icon.Position = UDim2.fromOffset(10, 15)
	icon.ZIndex = 23
	local name = Components.Label(row, recipe.displayName, 14, true)
	name.Size = UDim2.new(1, -190, 0, 22)
	name.Position = UDim2.fromOffset(62, 10)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 23
	local detail = Components.Label(row, "", 11, false)
	detail.Size = UDim2.new(1, -170, 0, 20)
	detail.Position = UDim2.fromOffset(62, 37)
	detail.TextColor3 = Theme.Colors.Muted
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.ZIndex = 23
	local count = Components.Label(row, "0", 24, true)
	count.Size = UDim2.fromOffset(52, 32)
	count.Position = UDim2.new(1, -60, 0, 7)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.ZIndex = 23
	local state = Components.Label(row, "", 9, true)
	state.Size = UDim2.fromOffset(96, 20)
	state.Position = UDim2.new(1, -104, 1, -26)
	state.BackgroundTransparency = 0
	state.TextColor3 = Theme.Colors.White
	state.ZIndex = 23
	Components.Corner(state, Theme.Radius.Pill)
	stockRows[recipeId] = { frame = row, count = count, detail = detail, state = state }
end

local function makeProductionRow(parent: Instance, recipeId: string, order: number)
	local recipe = Recipes[recipeId]
	local row = Instance.new("Frame")
	row.Name = recipeId
	row.Size = UDim2.new(1, -6, 0, 100)
	row.BackgroundColor3 = Theme.Colors.Paper
	row.LayoutOrder = order
	row.ZIndex = 22
	Components.Corner(row, Theme.Radius.Medium)
	Components.Stroke(row, Theme.Colors.Line, 1, 0.4)
	row.Parent = parent
	local name = Components.Label(row, recipe.displayName, 14, true)
	name.Size = UDim2.new(1, -126, 0, 22)
	name.Position = UDim2.fromOffset(12, 8)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 23
	local meta = Components.Label(
		row,
		string.format(
			"+%d / %s  |  %s",
			recipe.productionYield,
			shortTime(recipe.productionTime),
			recipe.staffRole
		),
		10,
		false
	)
	meta.Size = UDim2.new(1, -126, 0, 18)
	meta.Position = UDim2.fromOffset(12, 29)
	meta.TextColor3 = Theme.Colors.Muted
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.ZIndex = 23
	local status = Components.Label(row, "", 9, true)
	status.Size = UDim2.fromOffset(104, 20)
	status.Position = UDim2.new(1, -114, 0, 9)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.ZIndex = 23
	local toggle = Components.Button(row, "AUTO OFF", Theme.Colors.Muted, UDim2.fromOffset(88, 44))
	toggle.Position = UDim2.fromOffset(10, 52)
	toggle.TextSize = 10
	toggle.ZIndex = 23
	toggle.Activated:Connect(function()
		if profile and profile.unlockedRecipes[recipeId] == true then
			local active = (kitchen().menu or {})[recipeId] == true
			Remotes.event("SetMenuRecipe"):FireServer(recipeId, not active)
		end
	end)
	local minus = Components.Button(row, "-", Theme.Colors.Coral, UDim2.fromOffset(44, 44))
	minus.Position = UDim2.fromOffset(104, 52)
	minus.TextSize = 18
	minus.ZIndex = 23
	minus.Activated:Connect(function()
		local current = tonumber((kitchen().targetStock or {})[recipeId]) or 0
		Remotes.event("SetTargetStock"):FireServer(recipeId, current - recipe.productionYield)
	end)
	local target = Components.Label(row, "0", 15, true)
	target.Size = UDim2.fromOffset(52, 44)
	target.Position = UDim2.fromOffset(152, 52)
	target.BackgroundTransparency = 0
	target.BackgroundColor3 = Theme.Colors.PaperDark
	Components.Corner(target, Theme.Radius.Small)
	target.ZIndex = 23
	local plus = Components.Button(row, "+", Theme.Colors.Mint, UDim2.fromOffset(44, 44))
	plus.Position = UDim2.fromOffset(208, 52)
	plus.TextSize = 18
	plus.ZIndex = 23
	plus.Activated:Connect(function()
		local current = tonumber((kitchen().targetStock or {})[recipeId]) or 0
		Remotes.event("SetTargetStock"):FireServer(recipeId, current + recipe.productionYield)
	end)
	local priority = Components.Button(row, "P1", Theme.Colors.Honey, UDim2.fromOffset(52, 44))
	priority.Position = UDim2.new(1, -60, 0, 52)
	priority.TextColor3 = Theme.Colors.Espresso
	priority.ZIndex = 23
	priority.Activated:Connect(function()
		local current = tonumber((kitchen().priorities or {})[recipeId]) or 1
		Remotes.event("SetProductionPriority"):FireServer(recipeId, (current % 3) + 1)
	end)
	productionRows[recipeId] = {
		frame = row,
		name = name,
		meta = meta,
		status = status,
		toggle = toggle,
		minus = minus,
		target = target,
		plus = plus,
		priority = priority,
	}
end

local function buildDrawer(gui: ScreenGui)
	local drawer = Components.Panel(gui, "PantryDrawer")
	drawer.Size = UDim2.fromOffset(500, 590)
	drawer.Position = UDim2.new(1, -263, 0.5, 0)
	drawer.Visible = false
	local _, close = Components.PanelHeader(
		drawer,
		"PANTRY & PRODUCTION",
		"Balance fresh stock, menu demand, and staff output",
		Theme.Colors.Coral
	)
	close.Activated:Connect(function()
		UIController.closePanel(drawer)
	end)

	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -24, 0, 40)
	tabs.Position = UDim2.fromOffset(12, 72)
	tabs.BackgroundTransparency = 1
	tabs.ZIndex = 21
	tabs.Parent = drawer
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabs
	ui.mainTabs = {}
	for order, tabName in { "Stock", "Production" } do
		local button = Components.Button(
			tabs,
			if tabName == "Stock" then "FRESH STOCK" else "AUTO PRODUCTION",
			Theme.Colors.PaperDark,
			UDim2.new(0.5, -4, 1, 0)
		)
		button.LayoutOrder = order
		button.TextColor3 = Theme.Colors.Ink
		button.ZIndex = 22
		button.Activated:Connect(function()
			selectedTab = tabName
			updateFilters()
		end)
		ui.mainTabs[tabName] = button
	end

	local categories = Instance.new("Frame")
	categories.Size = UDim2.new(1, -24, 0, 34)
	categories.Position = UDim2.fromOffset(12, 120)
	categories.BackgroundTransparency = 1
	categories.ZIndex = 21
	categories.Parent = drawer
	local categoryLayout = Instance.new("UIListLayout")
	categoryLayout.FillDirection = Enum.FillDirection.Horizontal
	categoryLayout.Padding = UDim.new(0, 5)
	categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
	categoryLayout.Parent = categories
	ui.categoryTabs = {}
	for order, category in { "All", "Coffee", "Tea", "Pastry", "Food" } do
		local button = Components.Button(
			categories,
			category,
			Theme.Colors.PaperDark,
			UDim2.new(0.2, -4, 1, 0)
		)
		button.LayoutOrder = order
		button.TextColor3 = Theme.Colors.Ink
		button.TextSize = 11
		button.ZIndex = 22
		button.Activated:Connect(function()
			selectedCategory = category
			updateFilters()
		end)
		ui.categoryTabs[category] = button
	end

	local function makeList(name: string): ScrollingFrame
		local list = Instance.new("ScrollingFrame")
		list.Name = name
		list.Size = UDim2.new(1, -20, 1, -160)
		list.Position = UDim2.fromOffset(10, 160)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.ScrollBarImageColor3 = Theme.Colors.Coral
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.ZIndex = 21
		list.Parent = drawer
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		return list
	end
	ui.stockList = makeList("StockList")
	ui.productionList = makeList("ProductionList")
	for order, recipeId in RECIPE_IDS do
		makeStockRow(ui.stockList, recipeId, order)
		makeProductionRow(ui.productionList, recipeId, order)
	end
	ui.drawer = drawer
	updateFilters()
end

local function applyResponsive(mode: string, viewport: Vector2)
	if not ui.dock then
		return
	end
	local phone = mode == "Phone"
	local compact = mode ~= "Desktop"
	ui.dock.Size = if phone
		then UDim2.fromOffset(math.max(260, viewport.X - 82), 56)
		elseif compact then UDim2.fromOffset(math.min(344, viewport.X - 120), 56)
		else UDim2.fromOffset(500, 78)
	ui.dock.Position = UDim2.new(0, 10, 1, -10)
	ui.dock.AnchorPoint = Vector2.new(0, 1)
	ui.dockHeader.Size = UDim2.new(1, -8, 0, if compact then 18 else 25)
	ui.slots.Position = UDim2.fromOffset(5, if compact then 20 else 30)
	ui.slots.Size = UDim2.new(1, -10, 1, if compact then -24 else -35)
	for _, slot in dockSlots do
		slot.state.Visible = not compact
		slot.name.TextSize = if compact then 9 else 10
		slot.count.TextSize = if compact then 14 else 16
	end
	for _, row in productionRows do
		if compact then
			row.name.Size = UDim2.new(1, -210, 0, 22)
			row.status.Position = UDim2.new(1, -170, 0, 9)
			row.priority.Position = UDim2.new(1, -60, 0, 8)
		else
			row.name.Size = UDim2.new(1, -126, 0, 22)
			row.status.Position = UDim2.new(1, -114, 0, 9)
			row.priority.Position = UDim2.new(1, -60, 0, 52)
		end
	end
	local drawer = ui.drawer
	if phone then
		drawer.AnchorPoint = Vector2.new(0.5, 1)
		drawer.Position = UDim2.new(0.5, 0, 1, -8)
		drawer.Size = UDim2.new(1, -16, 0.72, 0)
	elseif compact then
		drawer.AnchorPoint = Vector2.new(1, 0.5)
		drawer.Position = UDim2.new(1, -8, 0.5, 0)
		drawer.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.44, 336, 368), viewport.Y - 16)
	else
		drawer.AnchorPoint = Vector2.new(0.5, 0.5)
		drawer.Position = UDim2.new(1, -263, 0.5, 0)
		drawer.Size = UDim2.fromOffset(500, math.min(590, viewport.Y - 24))
	end
	if profile then
		updateDock()
	end
end

function InventoryController.Start(_self: any)
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("InventoryHUD")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
	gui.Parent = playerGui

	local dock = Instance.new("Frame")
	dock.Name = "StockDock"
	dock.AnchorPoint = Vector2.new(0, 1)
	dock.Position = UDim2.new(0, 10, 1, -10)
	dock.Size = UDim2.fromOffset(500, 78)
	dock.BackgroundColor3 = Theme.Colors.Espresso
	dock.BackgroundTransparency = 0.04
	Components.Corner(dock, Theme.Radius.Large)
	Components.Stroke(dock, Theme.Colors.Honey, 1, 0.28)
	Components.Gradient(dock, Theme.Colors.Espresso, Theme.Colors.Roast, 0)
	dock.Parent = gui
	ui.dock = dock

	local header = Instance.new("Frame")
	header.Name = "Pulse"
	header.Size = UDim2.new(1, -8, 0, 25)
	header.Position = UDim2.fromOffset(4, 3)
	header.BackgroundTransparency = 1
	header.Parent = dock
	ui.dockHeader = header
	local pulse = Components.Label(header, "LOADING STOCK", 10, true)
	pulse.Size = UDim2.new(1, -92, 1, 0)
	pulse.Position = UDim2.fromOffset(8, 0)
	pulse.TextXAlignment = Enum.TextXAlignment.Left
	pulse.TextColor3 = Theme.Colors.Cream
	ui.pulse = pulse
	local pantry = Components.Button(
		header,
		"PANTRY",
		Theme.Colors.Coral,
		UDim2.fromOffset(82, 22),
		Theme.Glyphs.Pantry,
		Theme.Images.Pantry
	)
	pantry.Position = UDim2.new(1, -84, 0, 0)
	pantry.TextSize = 9
	pantry.Activated:Connect(function()
		UIController.togglePanel(ui.drawer)
	end)

	local slots = Instance.new("Frame")
	slots.Name = "ActiveMenuStock"
	slots.Size = UDim2.new(1, -10, 1, -35)
	slots.Position = UDim2.fromOffset(5, 30)
	slots.BackgroundTransparency = 1
	slots.Parent = dock
	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Horizontal
	slotsLayout.Padding = UDim.new(0, 6)
	slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotsLayout.Parent = slots
	ui.slots = slots
	for index = 1, 4 do
		makeDockSlot(slots, index)
	end
	local empty = Components.Label(slots, "Open Pantry to choose up to four menu items", 11, true)
	empty.Size = UDim2.fromScale(1, 1)
	empty.TextColor3 = Theme.Colors.Cream
	empty.Visible = true
	ui.empty = empty

	buildDrawer(UIController.modalRoot())
	UIController.subscribeProfile(function(newProfile)
		profile = newProfile
		updateAll()
	end)
	ResponsiveLayout.watch(applyResponsive)

	-- One lightweight clock updates only countdown labels and status values.
	task.spawn(function()
		while gui.Parent ~= nil do
			task.wait(1)
			if profile then
				updateDock()
				for _, id in RECIPE_IDS do
					updateStockRow(id)
				end
			end
		end
	end)
end

return InventoryController
