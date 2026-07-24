--!strict
-- Recipe collection with mastery, unlock hints, and category filters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Graphics = require(Shared.Config.Graphics)
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Ingredients = require(Shared.Config.Ingredients)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local CookbookController = {}
CookbookController.Name = "CookbookController"

local ui: { [string]: any } = {}
local selectedCategory = "All"
local cards: { [string]: Frame } = {}

-- The machine + ingredients a recipe needs — the only info the cookbook shows
-- now (owner: "only the associated ingredients and machines you need").
local function machineName(applianceId: string): string
	local def = Furniture[applianceId]
	return if def then def.displayName else applianceId
end

local function ingredientsText(recipe: any): string
	local needs = recipe.ingredients
	if typeof(needs) ~= "table" or next(needs) == nil then
		return "No ingredients needed"
	end
	local ids = {}
	for id in needs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return a < b
	end)
	local parts = {}
	for _, id in ids do
		local def = Ingredients[id]
		local name = if def then def.displayName else id
		local icon = if def then def.icon .. " " else ""
		table.insert(parts, string.format("%s%s x%d", icon, name, needs[id]))
	end
	return table.concat(parts, "   ")
end

local function categoryMatches(recipeId: string): boolean
	if selectedCategory == "All" then
		return true
	elseif selectedCategory == "Food" then
		return Recipes[recipeId].category == "Sandwich"
	end
	return Recipes[recipeId].category == selectedCategory
end

local function applyFilter()
	for id, card in cards do
		card.Visible = categoryMatches(id)
	end
	for category, button in ui.categoryTabs or {} do
		button.BackgroundColor3 = if category == selectedCategory
			then Components.CategoryColor(if category == "Food" then "Sandwich" else category)
			else Theme.Colors.PaperDark
		button.TextColor3 = if category == selectedCategory
			then Theme.Colors.White
			else Theme.Colors.Ink
	end
end

local function sortedRecipes(profile: any): { any }
	local ordered = {}
	for id, recipe in Recipes do
		table.insert(ordered, {
			id = id,
			recipe = recipe,
			unlocked = (profile.unlockedRecipes or {})[id] == true,
		})
	end
	table.sort(ordered, function(a, b)
		if a.unlocked ~= b.unlocked then
			return a.unlocked
		end
		if a.recipe.requiredLevel ~= b.recipe.requiredLevel then
			return a.recipe.requiredLevel < b.recipe.requiredLevel
		end
		return a.recipe.displayName < b.recipe.displayName
	end)
	return ordered
end

local function rebuild()
	local profile = UIController.getProfile()
	if not profile or not ui.list then
		return
	end
	ui.list:ClearAllChildren()
	cards = {}
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list

	for order, item in sortedRecipes(profile) do
		local recipe = item.recipe
		local card = Instance.new("Frame")
		card.Name = item.id
		card.Size = UDim2.new(1, -6, 0, 92)
		card.BackgroundColor3 = if item.unlocked
			then Theme.Colors.Paper
			else Color3.fromRGB(78, 65, 61)
		card.LayoutOrder = order
		card.ZIndex = 22
		Components.Corner(card, Theme.Radius.Medium)
		Components.Stroke(
			card,
			if item.unlocked then Theme.Colors.Line else Theme.Colors.Roast,
			1,
			0.25
		)
		card.Parent = ui.list
		cards[item.id] = card

		local color = Components.CategoryColor(recipe.category)
		-- Each dish has its own icon; a locked recipe shows that same picture
		-- blurred rather than a bare "?".
		local thumbnail = Components.ItemThumbnail(card, {
			image = (Graphics.Dishes :: any)[item.id],
			size = Theme.Thumbnail.CardSize,
			glyph = Components.CategoryGlyph(recipe.category),
			accent = color,
			locked = not item.unlocked,
			lockLabel = "LV " .. tostring(recipe.requiredLevel),
		})
		thumbnail.root.Position = UDim2.fromOffset(10, 18)
		thumbnail.root.ZIndex = 23
		local title = Components.Label(
			card,
			if item.unlocked then recipe.displayName else "SECRET RECIPE",
			14,
			true
		)
		title.Size = UDim2.new(1, -160, 0, 24)
		title.Position = UDim2.fromOffset(68, 8)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = if item.unlocked then Theme.Colors.Ink else Theme.Colors.Cream
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.ZIndex = 23

		local detail = Components.Label(card, "", 11, false)
		detail.Size = UDim2.new(1, -82, 0, 54)
		detail.Position = UDim2.fromOffset(68, 32)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextYAlignment = Enum.TextYAlignment.Top
		detail.TextWrapped = true
		detail.TextColor3 = if item.unlocked then Theme.Colors.Muted else Theme.Colors.PaperDark
		detail.ZIndex = 23

		if item.unlocked then
			-- Only what the owner asked for: the machine + the ingredients needed.
			detail.RichText = true
			detail.Text = string.format(
				"<b>Machine:</b> %s\n<b>Needs:</b> %s",
				machineName(recipe.applianceId),
				ingredientsText(recipe)
			)
		else
			detail.Text = string.format(
				"Unlock at level %d with %d reputation",
				recipe.requiredLevel,
				recipe.requiredReputation
			)
		end
	end
	applyFilter()
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
		panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.44, 338, 378), viewport.Y - 16)
	else
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(520, 570)
	end
end

function CookbookController.Start(_self: any)
	local panel = Components.Panel(UIController.modalRoot(), "CookbookPanel")
	panel.Size = UDim2.fromOffset(520, 570)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"CAFE COOKBOOK",
		"What each dish needs: machine + ingredients",
		Theme.Colors.MintDark
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local categories = Instance.new("Frame")
	categories.Size = UDim2.new(1, -24, 0, 36)
	categories.Position = UDim2.fromOffset(12, 72)
	categories.BackgroundTransparency = 1
	categories.ZIndex = 21
	categories.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = categories
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
			applyFilter()
		end)
		ui.categoryTabs[category] = button
	end

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -122)
	list.Position = UDim2.fromOffset(10, 116)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Mint
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	ui.list = list
	ui.panel = panel

	UIController.registerAction("Cookbook", function()
		UIController.togglePanel(panel)
		if panel.Visible then
			rebuild()
		end
	end)
	UIController.bindActionPanel("Cookbook", panel)
	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)
	ResponsiveLayout.watch(applyResponsive)
end

return CookbookController
