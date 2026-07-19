--!strict
-- Cook-ahead appliance prompts and responsive recipe picker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Kitchen = require(Shared.Config.Kitchen)
local Mastery = require(Shared.Utilities.Mastery)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)
local AudioController = require(script.Parent.AudioController)

local player = Players.LocalPlayer

local KitchenController = {}
KitchenController.Name = "KitchenController"

local ui: { [string]: any } = {}
local pickerTargetId: string? = nil

local function formatTime(seconds: number): string
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return tostring(seconds) .. "s"
end

local function closePicker()
	pickerTargetId = nil
	UIController.closePanel(ui.panel)
end

local function buildPicker()
	local panel = Components.Panel(UIController.modalRoot(), "CookPanel")
	panel.Size = UDim2.fromOffset(440, 480)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"START A FRESH BATCH",
		"Pick a recipe for this appliance",
		Theme.Colors.MintDark
	)
	close.Activated:Connect(closePicker)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Recipes"
	list.Size = UDim2.new(1, -20, 1, -78)
	list.Position = UDim2.fromOffset(10, 70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Mint
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	ui.panel = panel
	ui.list = list

	ResponsiveLayout.watch(function(mode, viewport)
		if mode == "Phone" then
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -8)
			panel.Size = UDim2.new(1, -16, 0.68, 0)
		elseif mode == "Compact" then
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -8, 0.5, 0)
			panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.43, 326, 360), viewport.Y - 16)
		else
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
			panel.Size = UDim2.fromOffset(440, 480)
		end
	end)
end

local function openPicker(applianceId: string, instanceId: string)
	pickerTargetId = instanceId
	local profile = UIController.getProfile()
	local unlocked = (profile and profile.unlockedRecipes) or {}
	local masteryMap = (profile and profile.recipeMastery) or {}

	ui.list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list
	local choices = {}
	for id, recipe in Recipes do
		if recipe.applianceId == applianceId and unlocked[id] == true then
			table.insert(choices, id)
		end
	end
	table.sort(choices, function(a, b)
		return Recipes[a].displayName < Recipes[b].displayName
	end)
	for order, id in choices do
		local recipe = Recipes[id]
		local entry = masteryMap[id]
		local masteryLevel = (entry and tonumber(entry.masteryLevel)) or 0
		local cost = Mastery.batchCost(
			recipe.ingredientCost * Kitchen.batchCostMultiplier,
			masteryLevel,
			Kitchen.masteryCostReductionPerStar
		)
		local row = Instance.new("TextButton")
		row.Name = id
		row.Size = UDim2.new(1, -6, 0, 76)
		row.BackgroundColor3 = Theme.Colors.Paper
		row.Font = Theme.Font.Bold
		row.TextSize = 13
		row.TextColor3 = Theme.Colors.Ink
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextWrapped = true
		row.Text = string.format(
			"      %s\n      $%d batch  |  %s  |  +%d servings",
			recipe.displayName,
			cost,
			formatTime(recipe.cookTime),
			recipe.servings
		)
		row.LayoutOrder = order
		row.ZIndex = 22
		Components.Corner(row, Theme.Radius.Medium)
		Components.Stroke(row, Theme.Colors.Line, 1, 0.35)
		local accent = Instance.new("Frame")
		accent.Size = UDim2.fromOffset(8, 56)
		accent.Position = UDim2.fromOffset(10, 10)
		accent.BackgroundColor3 = Components.CategoryColor(recipe.category)
		accent.ZIndex = 23
		Components.Corner(accent, 4)
		accent.Parent = row
		row.Activated:Connect(function()
			if pickerTargetId then
				Remotes.event("StartCook"):FireServer(pickerTargetId, id)
				AudioController.play("brew")
			end
			closePicker()
		end)
		row.Parent = ui.list
	end
	if #choices == 0 then
		UIController.toast("No recipes for this appliance yet - level up first")
		return
	end
	UIController.togglePanel(ui.panel)
end

local function attachPrompt(model: Model)
	if model:FindFirstChild("CookPrompt", true) then
		return
	end
	local anchor = model:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CookPrompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false

	local function refresh()
		local state = model:GetAttribute("cookState")
		if state == "cooking" then
			prompt.ActionText = "Cooking..."
			prompt.Enabled = false
		elseif state == "ready" then
			prompt.ActionText = "Collect"
			prompt.Enabled = true
		else
			prompt.ActionText = "Cook"
			prompt.Enabled = true
		end
		prompt.ObjectText = Furniture[model.Name] and Furniture[model.Name].displayName
			or "Appliance"
	end
	refresh()
	model:GetAttributeChangedSignal("cookState"):Connect(refresh)
	prompt.Triggered:Connect(function()
		local instanceId = model:GetAttribute("instanceId")
		if typeof(instanceId) ~= "string" then
			return
		end
		if model:GetAttribute("cookState") == "ready" then
			Remotes.event("CollectCook"):FireServer(instanceId)
			AudioController.play("serve")
		else
			openPicker(model.Name, instanceId)
		end
	end)
	prompt.Parent = anchor
end

local function isCookable(model: Instance): boolean
	if not model:IsA("Model") then
		return false
	end
	local definition = Furniture[model.Name]
	return definition ~= nil and definition.cookable == true
end

local function watchMyFurniture()
	local plotsFolder = workspace:WaitForChild("Plots", 30)
	if not plotsFolder then
		return
	end
	while true do
		for _, plot in plotsFolder:GetChildren() do
			if plot:GetAttribute("ownerUserId") == player.UserId then
				local furniture = plot:WaitForChild("Furniture", 10)
				if furniture then
					for _, child in furniture:GetChildren() do
						if isCookable(child) then
							attachPrompt(child :: Model)
						end
					end
					furniture.ChildAdded:Connect(function(child)
						if isCookable(child) then
							task.wait(0.1)
							attachPrompt(child :: Model)
						end
					end)
				end
				return
			end
		end
		task.wait(1)
	end
end

function KitchenController.Start(_self: any)
	buildPicker()
	task.spawn(watchMyFurniture)
end

return KitchenController
