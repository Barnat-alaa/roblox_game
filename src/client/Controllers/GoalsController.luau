--!strict
-- Daily goals presented as a compact cafe checklist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local GoalsController = {}
GoalsController.Name = "GoalsController"

local ui: { [string]: any } = {}

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
	for index, goal in daily.goals or {} do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 72)
		row.BackgroundColor3 = if goal.done
			then Color3.fromRGB(229, 248, 236)
			else Theme.Colors.Paper
		row.LayoutOrder = index
		row.ZIndex = 22
		Components.Corner(row, Theme.Radius.Medium)
		Components.Stroke(row, if goal.done then Theme.Colors.Mint else Theme.Colors.Line, 1, 0.3)
		row.Parent = ui.list

		local badge = Components.Icon(
			row,
			if goal.done then "OK" else tostring(index),
			nil,
			if goal.done then Theme.Colors.Mint else Theme.Colors.Honey,
			36
		)
		badge.Position = UDim2.fromOffset(10, 18)
		badge.ZIndex = 23
		local title = Components.Label(row, tostring(goal.text), 13, true)
		title.Size = UDim2.new(1, -116, 0, 32)
		title.Position = UDim2.fromOffset(56, 7)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextWrapped = true
		title.ZIndex = 23

		local count =
			Components.Label(row, tostring(goal.progress) .. "/" .. tostring(goal.target), 11, true)
		count.Size = UDim2.fromOffset(54, 24)
		count.Position = UDim2.new(1, -62, 0, 10)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextColor3 = Theme.Colors.Muted
		count.ZIndex = 23

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(1, -72, 0, 10)
		barBg.Position = UDim2.fromOffset(56, 52)
		barBg.BackgroundColor3 = Theme.Colors.PaperDark
		barBg.ZIndex = 23
		Components.Corner(barBg, 5)
		barBg.Parent = row
		local fraction = math.clamp(
			(tonumber(goal.progress) or 0) / math.max(1, tonumber(goal.target) or 1),
			0,
			1
		)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = if goal.done then Theme.Colors.Mint else Theme.Colors.Honey
		fill.BorderSizePixel = 0
		fill.ZIndex = 24
		Components.Corner(fill, 5)
		fill.Parent = barBg
	end

	local trophies = 0
	for _ in profile.trophies or {} do
		trophies += 1
	end
	ui.footer.Text =
		string.format("%d day streak     |     %d trophies", tonumber(daily.streak) or 0, trophies)
end

local function applyResponsive(mode: string, viewport: Vector2)
	local panel = ui.panel
	if not panel then
		return
	end
	if mode == "Phone" then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -8)
		panel.Size = UDim2.new(1, -16, 0.72, 0)
	elseif mode == "Compact" then
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -8, 0.5, 0)
		panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.41, 316, 350), viewport.Y - 16)
	else
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(430, 420)
	end
end

function GoalsController.Start(_self: any)
	local panel = Components.Panel(UIController.modalRoot(), "GoalsPanel")
	panel.Size = UDim2.fromOffset(430, 420)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"TODAY'S GOALS",
		"Small wins keep your cafe growing",
		Theme.Colors.Honey
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -112)
	list.Position = UDim2.fromOffset(10, 70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Honey
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	ui.list = list

	local footer = Components.Label(panel, "", 13, true)
	footer.Size = UDim2.new(1, -24, 0, 32)
	footer.Position = UDim2.new(0, 12, 1, -38)
	footer.BackgroundTransparency = 0
	footer.BackgroundColor3 = Theme.Colors.PaperDark
	footer.ZIndex = 21
	Components.Corner(footer, Theme.Radius.Pill)
	ui.footer = footer
	ui.panel = panel

	UIController.registerAction(
		"Goals",
		"Goals",
		Theme.Glyphs.Goals,
		Theme.Colors.Honey,
		10,
		function()
			UIController.togglePanel(panel)
			if panel.Visible then
				rebuild()
			end
		end
	)
	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)
	ResponsiveLayout.watch(applyResponsive)

	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "goal_done" then
			UIController.toast(tostring(msg.text) .. "  +$" .. tostring(msg.reward))
		elseif msg.kind == "streak_day" then
			UIController.toast(
				"Streak day " .. tostring(msg.streak) .. "  +$" .. tostring(msg.bonus)
			)
		elseif msg.kind == "trophy_earned" then
			UIController.toast(tostring(msg.days) .. "-day trophy earned")
		end
	end)
end

return GoalsController
