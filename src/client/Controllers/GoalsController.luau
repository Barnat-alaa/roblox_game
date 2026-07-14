--!strict
-- Daily goals panel (Phase 3b): three rotating goals with progress bars,
-- the current streak, and the trophy count. Pure presentation over the
-- profile snapshot; GoalService owns all state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local GoalsController = {}
GoalsController.Name = "GoalsController"

local ui: { [string]: any } = {}

local CREAM = Color3.fromRGB(245, 235, 218)
local DARK = Color3.fromRGB(55, 42, 38)

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

	local daily = profile.daily or {}
	local goals = daily.goals or {}

	for index, goal in goals do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 58)
		row.BackgroundColor3 = if goal.done
			then Color3.fromRGB(220, 240, 215)
			else Color3.fromRGB(255, 250, 240)
		row.LayoutOrder = index
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -16, 0, 24)
		title.Position = UDim2.fromOffset(10, 6)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 15
		title.TextColor3 = DARK
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = (if goal.done then "✅ " else "▫️ ") .. tostring(goal.text)
		title.Parent = row

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, -20, 0, 12)
		barBg.Position = UDim2.fromOffset(10, 36)
		barBg.BackgroundColor3 = Color3.fromRGB(220, 208, 190)
		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 6)
		bgCorner.Parent = barBg
		barBg.Parent = row

		local frac = math.clamp(
			(tonumber(goal.progress) or 0) / math.max(1, tonumber(goal.target) or 1),
			0,
			1
		)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(frac, 0, 1, 0)
		fill.BackgroundColor3 = if goal.done
			then Color3.fromRGB(110, 180, 100)
			else Color3.fromRGB(235, 170, 80)
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 6)
		fillCorner.Parent = fill
		fill.Parent = barBg

		local count = Instance.new("TextLabel")
		count.AnchorPoint = Vector2.new(1, 0)
		count.Size = UDim2.fromOffset(80, 24)
		count.Position = UDim2.new(1, -10, 0, 6)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamMedium
		count.TextSize = 13
		count.TextColor3 = Color3.fromRGB(120, 100, 90)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Text = tostring(goal.progress) .. "/" .. tostring(goal.target)
		count.Parent = row

		row.Parent = ui.list
	end

	local trophies = 0
	for _ in profile.trophies or {} do
		trophies += 1
	end
	ui.footer.Text = string.format(
		"🔥 Streak: %d day%s      🏆 Trophies: %d",
		tonumber(daily.streak) or 0,
		if (tonumber(daily.streak) or 0) == 1 then "" else "s",
		trophies
	)
end

function GoalsController.Start(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GoalsGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Toggle button, stacked above the Cookbook button.
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(132, 48)
	btn.Position = UDim2.new(1, -144, 1, -248)
	btn.BackgroundColor3 = Color3.fromRGB(235, 170, 80)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(255, 250, 242)
	btn.Text = "📋 Goals"
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = btn
	btn.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(340, 300)
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
	title.Text = "📋 Today's Goals"
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
	end)
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -92)
	list.Position = UDim2.fromOffset(10, 46)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	ui.list = list

	local footer = Instance.new("TextLabel")
	footer.Size = UDim2.new(1, -20, 0, 30)
	footer.Position = UDim2.new(0, 10, 1, -38)
	footer.BackgroundTransparency = 1
	footer.Font = Enum.Font.GothamBold
	footer.TextSize = 15
	footer.TextColor3 = DARK
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Text = ""
	footer.Parent = panel
	ui.footer = footer
	ui.panel = panel

	btn.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			rebuild()
		end
	end)

	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)

	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "goal_done" then
			UIController.toast(
				"✅ " .. tostring(msg.text) .. "  +" .. tostring(msg.reward) .. " 🪙"
			)
		elseif msg.kind == "streak_day" then
			UIController.toast(
				"🔥 Streak day "
					.. tostring(msg.streak)
					.. "!  +"
					.. tostring(msg.bonus)
					.. " 🪙"
			)
		elseif msg.kind == "trophy_earned" then
			UIController.toast(
				"🏆 " .. tostring(msg.days) .. "-day trophy!  +" .. tostring(msg.bonus) .. " 🪙"
			)
		end
	end)
end

return GoalsController
