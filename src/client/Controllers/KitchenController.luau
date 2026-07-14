--!strict
-- Cook-ahead kitchen client (Phase 1): "Cook" / "Collect" prompts on YOUR
-- OWN appliances plus a recipe-picker panel. The server owns everything —
-- this controller only asks (StartCook / CollectCook) and presents state
-- from the model's `cookState` attribute, which KitchenService maintains.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Kitchen = require(Shared.Config.Kitchen)

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

-- ————— recipe picker panel —————

local function buildPicker()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KitchenGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "CookPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(320, 300)
	panel.BackgroundColor3 = Color3.fromRGB(245, 235, 218)
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 34)
	title.Position = UDim2.fromOffset(10, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(55, 42, 38)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "🍳 What shall we cook?"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(30, 30)
	close.Position = UDim2.new(1, -38, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(200, 100, 70)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = Color3.fromRGB(255, 250, 242)
	close.Text = "✕"
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close
	close.Activated:Connect(function()
		panel.Visible = false
		pickerTargetId = nil
	end)
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -56)
	list.Position = UDim2.fromOffset(10, 46)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	ui.panel = panel
	ui.list = list
end

local function openPicker(applianceId: string, instanceId: string)
	pickerTargetId = instanceId
	local profile = UIController.getProfile()
	local unlocked = (profile and profile.unlockedRecipes) or {}

	ui.list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list

	local order = 0
	for id, recipe in Recipes do
		if recipe.applianceId == applianceId and unlocked[id] == true then
			order += 1
			local cost = recipe.ingredientCost * Kitchen.batchCostMultiplier
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, -6, 0, 52)
			row.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
			row.Font = Enum.Font.GothamMedium
			row.TextSize = 14
			row.TextColor3 = Color3.fromRGB(55, 42, 38)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = string.format(
				"  %s\n  🪙%d · ⏱ %s · %d servings",
				recipe.displayName,
				cost,
				formatTime(recipe.cookTime),
				recipe.servings
			)
			row.LayoutOrder = order
			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 10)
			rowCorner.Parent = row
			row.Activated:Connect(function()
				if pickerTargetId then
					Remotes.event("StartCook"):FireServer(pickerTargetId, id)
					AudioController.play("brew")
				end
				ui.panel.Visible = false
				pickerTargetId = nil
			end)
			row.Parent = ui.list
		end
	end
	ui.panel.Visible = order > 0
	if order == 0 then
		UIController.toast("No recipes for this appliance yet — level up!")
	end
end

-- ————— appliance prompts —————

local function attachPrompt(model: Model)
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
			prompt.ActionText = "Cooking…"
			prompt.Enabled = false
		elseif state == "ready" then
			prompt.ActionText = "Collect"
			prompt.ObjectText = Furniture[model.Name] and Furniture[model.Name].displayName or ""
			prompt.Enabled = true
		else
			prompt.ActionText = "Cook"
			prompt.ObjectText = Furniture[model.Name] and Furniture[model.Name].displayName or ""
			prompt.Enabled = true
		end
	end
	refresh()
	model:GetAttributeChangedSignal("cookState"):Connect(refresh)

	prompt.Triggered:Connect(function()
		local instanceId = model:GetAttribute("instanceId")
		if typeof(instanceId) ~= "string" then
			return
		end
		local state = model:GetAttribute("cookState")
		if state == "ready" then
			Remotes.event("CollectCook"):FireServer(instanceId)
			AudioController.play("serve")
		else
			openPicker(model.Name, instanceId)
		end
	end)
	prompt.Parent = anchor
end

local function isCookable(model: Instance): boolean
	local def = Furniture[model.Name]
	return model:IsA("Model") and def ~= nil and def.cookable == true
end

local function watchMyFurniture()
	local plotsFolder = workspace:WaitForChild("Plots", 30)
	if not plotsFolder then
		return
	end
	-- Find my plot (ownerUserId attribute), then watch its furniture folder.
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
							task.wait(0.1) -- let attributes replicate
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
