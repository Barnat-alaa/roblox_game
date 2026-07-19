--!strict
-- Responsive build catalogue with server-authoritative placement.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Grid = require(Shared.Utilities.Grid)
local World = require(Shared.Config.World)
local Furniture = require(Shared.Config.Furniture)
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local BuildController = {}
BuildController.Name = "BuildController"

local active = false
local selectedId: string? = nil
local selectedCategory = "All"
local rotation = 0
local previewPart: Part? = nil
local ui: { [string]: any } = {}

local function getOrigin(): CFrame?
	local origin = player:GetAttribute("PlotOrigin")
	return if typeof(origin) == "CFrame" then origin else nil
end

local function ownPlotFloor(): BasePart?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("ownerUserId") == player.UserId then
			local shell = plot:FindFirstChild("Shell")
			local floor = shell and shell:FindFirstChild("Floor")
			if floor and floor:IsA("BasePart") then
				return floor
			end
		end
	end
	return nil
end

-- Expects viewport coordinates. InputObject coordinates are converted in Start.
local function raycastCell(viewportPosition: Vector2): (number?, number?)
	local origin = getOrigin()
	local camera = workspace.CurrentCamera
	if not origin or not camera then
		return nil, nil
	end
	local ray = camera:ViewportPointToRay(viewportPosition.X, viewportPosition.Y)
	local params = RaycastParams.new()
	local floor = ownPlotFloor()
	if floor then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { floor }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude: { Instance } = {}
		if player.Character then
			table.insert(exclude, player.Character)
		end
		if previewPart then
			table.insert(exclude, previewPart)
		end
		params.FilterDescendantsInstances = exclude
	end
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not result then
		return nil, nil
	end
	return Grid.worldToCell(origin, result.Position)
end

local function updatePreview()
	if not active or not selectedId then
		if previewPart then
			previewPart.Parent = nil
		end
		return
	end
	local definition = Furniture[selectedId]
	local origin = getOrigin()
	if not definition or not origin then
		return
	end
	local gridX, gridY = raycastCell(UserInputService:GetMouseLocation())
	if not gridX or not gridY then
		return
	end
	if not previewPart then
		local part = Instance.new("Part")
		part.Name = "BuildPreview"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.35
		part.Material = Enum.Material.SmoothPlastic
		previewPart = part
	end
	local preview = previewPart :: Part
	preview.Size = Vector3.new(
		definition.width * Grid.CELL_SIZE - 0.2,
		definition.height,
		definition.depth * Grid.CELL_SIZE - 0.2
	)
	preview.CFrame = Grid.cellToWorld(
		origin,
		gridX,
		gridY,
		definition.width,
		definition.depth,
		rotation,
		definition.height
	)
	local tier = tonumber(player:GetAttribute("ExpansionTier")) or 0
	local depthCells = World.interiorDepthTiers[math.clamp(tier + 1, 1, #World.interiorDepthTiers)]
	local fits =
		Grid.inBounds(gridX, gridY, definition.width, definition.depth, rotation, nil, depthCells)
	preview.Color = if fits then Theme.Colors.Mint else Theme.Colors.Danger
	preview.Parent = workspace
end

local function tryPlace(screenPosition: Vector2)
	if not active or not selectedId then
		return
	end
	local gridX, gridY = raycastCell(screenPosition)
	if not gridX or not gridY then
		return
	end
	Remotes.event("PlaceFurniture"):FireServer({
		catalogId = selectedId,
		gridX = gridX,
		gridY = gridY,
		rotation = rotation,
	})
end

local function setCategoryButtons(activeButton: TextButton?)
	for _, child in ui.categories:GetChildren() do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = if child == activeButton
				then Theme.Colors.Coral
				else Theme.Colors.PaperDark
			child.TextColor3 = if child == activeButton
				then Theme.Colors.White
				else Theme.Colors.Ink
		end
	end
end

local function refreshCatalogue()
	if not ui.list then
		return
	end
	for _, child in ui.list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local profile = UIController.getProfile()
	if not profile then
		return
	end
	local ids = {}
	for id, count in profile.inventory do
		local definition = Furniture[id]
		if
			count > 0
			and definition
			and (selectedCategory == "All" or definition.category == selectedCategory)
		then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Furniture[a].displayName < Furniture[b].displayName
	end)
	for order, id in ids do
		local count = profile.inventory[id]
		local definition = Furniture[id]
		local selected = selectedId == id
		local button = Instance.new("TextButton")
		button.Name = id
		button.Size = UDim2.new(1, -6, 0, 58)
		button.LayoutOrder = order
		button.BackgroundColor3 = if selected then Theme.Colors.Mint else Theme.Colors.Paper
		button.TextColor3 = if selected then Theme.Colors.White else Theme.Colors.Ink
		button.Font = Theme.Font.Bold
		button.TextSize = 13
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextWrapped = true
		button.Text = string.format(
			"      %s\n      %s  |  %dx%d cells  |  x%d",
			definition.displayName,
			definition.category,
			definition.width,
			definition.depth,
			count
		)
		button.ZIndex = 22
		Components.Corner(button, Theme.Radius.Medium)
		Components.Stroke(button, Theme.Colors.Line, 1, 0.35)
		local accent = Instance.new("Frame")
		accent.Size = UDim2.fromOffset(8, 42)
		accent.Position = UDim2.fromOffset(10, 8)
		accent.BackgroundColor3 = Components.CategoryColor(definition.category)
		accent.ZIndex = 23
		Components.Corner(accent, 4)
		accent.Parent = button
		button.Activated:Connect(function()
			selectedId = id
			refreshCatalogue()
		end)
		button.Parent = ui.list
	end
	ui.empty.Visible = #ids == 0
end

local function leaveBuildMode()
	active = false
	selectedId = nil
	if previewPart then
		previewPart.Parent = nil
	end
end

local function toggle()
	if active then
		leaveBuildMode()
		UIController.closePanel(ui.panel)
	else
		active = true
		UIController.togglePanel(ui.panel)
		refreshCatalogue()
	end
end

local function buildPanel()
	local panel = Components.Panel(UIController.modalRoot(), "BuildPanel")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Size = UDim2.fromOffset(320, 520)
	panel.Position = UDim2.new(0, 12, 0.5, 0)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"BUILD MODE",
		"Choose an item, then tap the cafe floor",
		Theme.Colors.Coral
	)
	close.Activated:Connect(toggle)

	local categories = Instance.new("Frame")
	categories.Size = UDim2.new(1, -20, 0, 36)
	categories.Position = UDim2.fromOffset(10, 72)
	categories.BackgroundTransparency = 1
	categories.ZIndex = 21
	categories.Parent = panel
	local categoryLayout = Instance.new("UIListLayout")
	categoryLayout.FillDirection = Enum.FillDirection.Horizontal
	categoryLayout.Padding = UDim.new(0, 5)
	categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
	categoryLayout.Parent = categories
	ui.categories = categories
	local firstButton: TextButton? = nil
	for order, category in { "All", "Appliance", "Seating", "Decoration" } do
		local button = Components.Button(
			categories,
			if category == "Decoration" then "Decor" else category,
			Theme.Colors.PaperDark,
			UDim2.new(0.25, -4, 1, 0)
		)
		button.LayoutOrder = order
		button.TextColor3 = Theme.Colors.Ink
		button.TextSize = 10
		button.ZIndex = 22
		if category == "All" then
			firstButton = button
		end
		button.Activated:Connect(function()
			selectedCategory = category
			setCategoryButtons(button)
			refreshCatalogue()
		end)
	end
	setCategoryButtons(firstButton)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -176)
	list.Position = UDim2.fromOffset(8, 116)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Coral
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	ui.list = list
	local empty = Components.Label(list, "No owned items here. Visit the Shop first.", 12, true)
	empty.Size = UDim2.new(1, -12, 0, 60)
	empty.TextWrapped = true
	empty.TextColor3 = Theme.Colors.Muted
	empty.Visible = false
	empty.ZIndex = 22
	ui.empty = empty

	local rotateButton =
		Components.Button(panel, "ROTATE", Theme.Colors.Blue, UDim2.new(0.5, -14, 0, 44), "R")
	rotateButton.Position = UDim2.new(0, 10, 1, -52)
	rotateButton.ZIndex = 22
	rotateButton.Activated:Connect(function()
		rotation = (rotation + 1) % 4
	end)
	local doneButton =
		Components.Button(panel, "DONE", Theme.Colors.Mint, UDim2.new(0.5, -14, 0, 44), "OK")
	doneButton.Position = UDim2.new(0.5, 4, 1, -52)
	doneButton.ZIndex = 22
	doneButton.Activated:Connect(toggle)
	ui.panel = panel

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and active then
			leaveBuildMode()
		end
	end)
	ResponsiveLayout.watch(function(mode, viewport)
		if mode == "Phone" then
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -8)
			panel.Size = UDim2.new(1, -16, 0.7, 0)
		elseif mode == "Compact" then
			panel.AnchorPoint = Vector2.new(0, 0.5)
			panel.Position = UDim2.new(0, 8, 0.5, 0)
			panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.39, 300, 324), viewport.Y - 16)
		else
			panel.AnchorPoint = Vector2.new(0, 0.5)
			panel.Position = UDim2.new(0, 12, 0.5, 0)
			panel.Size = UDim2.fromOffset(320, 520)
		end
	end)
end

function BuildController.Start(_self: any)
	buildPanel()
	UIController.onBuildToggle = toggle
	UIController.registerAction(
		"Build",
		"Build",
		Theme.Glyphs.Build,
		Theme.Colors.Coral,
		30,
		toggle
	)
	UIController.subscribeProfile(function()
		if active then
			refreshCatalogue()
		end
	end)
	RunService.RenderStepped:Connect(updatePreview)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local inset = GuiService:GetGuiInset()
			tryPlace(Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y))
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
		end
	end)
end

return BuildController
