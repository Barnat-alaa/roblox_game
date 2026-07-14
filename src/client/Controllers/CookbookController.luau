--!strict
-- The Cookbook (Phase 3): every recipe as a card — unlocked ones show your
-- mastery stars and live (mastery-adjusted) numbers; locked ones tease as
-- dark silhouettes with their unlock level. Pure presentation over the
-- profile snapshot + shared configs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local Kitchen = require(Shared.Config.Kitchen)
local Mastery = require(Shared.Utilities.Mastery)

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local CookbookController = {}
CookbookController.Name = "CookbookController"

local ui: { [string]: any } = {}

local CREAM = Color3.fromRGB(245, 235, 218)
local DARK = Color3.fromRGB(55, 42, 38)
local GOLD = Color3.fromRGB(235, 185, 90)

local function formatTime(seconds: number): string
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return tostring(seconds) .. "s"
end

local APPLIANCE_EMOJI: { [string]: string } = {
	coffee_machine = "☕",
	oven = "🔥",
	prep_station = "🔪",
}

local function rebuild()
	local profile = UIController.getProfile()
	if not profile or not ui.list then
		return
	end
	ui.list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list

	local unlockedSet = profile.unlockedRecipes or {}
	local masteryMap = profile.recipeMastery or {}

	-- Sort: unlocked first, both groups by required level.
	local ordered = {}
	for id, recipe in Recipes do
		table.insert(ordered, { id = id, recipe = recipe, unlocked = unlockedSet[id] == true })
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

	for order, item in ordered do
		local recipe = item.recipe
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -6, 0, 64)
		card.BackgroundColor3 = if item.unlocked
			then Color3.fromRGB(255, 250, 240)
			else Color3.fromRGB(70, 60, 55)
		card.LayoutOrder = order
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -16, 0, 26)
		title.Position = UDim2.fromOffset(10, 6)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 16
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -16, 0, 24)
		sub.Position = UDim2.fromOffset(10, 32)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.TextSize = 13
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Parent = card

		if item.unlocked then
			local entry = masteryMap[item.id]
			local level = (entry and tonumber(entry.masteryLevel)) or 0
			local cooked = (entry and tonumber(entry.timesCooked)) or 0
			local starCount = #recipe.masteryThresholds
			local stars = string.rep("★", level)
				.. string.rep("☆", math.max(0, starCount - level))

			local effTime =
				Mastery.cookTime(recipe.cookTime, level, Kitchen.masteryTimeReductionPerStar)
			local effCost = Mastery.batchCost(
				recipe.ingredientCost * Kitchen.batchCostMultiplier,
				level,
				Kitchen.masteryCostReductionPerStar
			)
			local effServings =
				Mastery.servings(recipe.servings, level, Kitchen.masteryBonusServingAt)

			title.TextColor3 = if level >= #recipe.masteryThresholds then GOLD else DARK
			title.Text = (APPLIANCE_EMOJI[recipe.applianceId] or "🍳")
				.. " "
				.. recipe.displayName
				.. "   "
				.. stars

			local nextAt: number? = nil
			for _, t in recipe.masteryThresholds do
				if cooked < t then
					nextAt = t
					break
				end
			end
			sub.TextColor3 = Color3.fromRGB(120, 100, 90)
			sub.Text = string.format(
				"🪙%d · ⏱ %s · %d servings · cooked %d×%s",
				effCost,
				formatTime(effTime),
				effServings,
				cooked,
				if nextAt then string.format("  (next ★ at %d)", nextAt) else "  (MASTERED)"
			)
		else
			title.TextColor3 = Color3.fromRGB(180, 165, 155)
			title.Text = "🔒 ？？？"
			sub.TextColor3 = Color3.fromRGB(160, 145, 135)
			sub.Text = string.format(
				"Unlocks at Lv %d · %d reputation",
				recipe.requiredLevel,
				recipe.requiredReputation
			)
		end

		card.Parent = ui.list
	end
end

function CookbookController.Start(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CookbookGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Toggle button, stacked above the Build/Shop action bar.
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(132, 48)
	btn.Position = UDim2.new(1, -144, 1, -192)
	btn.BackgroundColor3 = Color3.fromRGB(90, 130, 90)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(255, 250, 242)
	btn.Text = "📖 Cookbook"
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = btn
	btn.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 420)
	panel.BackgroundColor3 = CREAM
	panel.Visible = false
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = DARK
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "📖 Cookbook"
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
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -56)
	list.Position = UDim2.fromOffset(10, 46)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	ui.list = list
	ui.panel = panel

	btn.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			rebuild()
		end
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	-- Live refresh while open (mastery/unlocks change as you play).
	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)
end

return CookbookController
