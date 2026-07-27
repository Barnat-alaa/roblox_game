--!strict
-- Café-health strip: four slim pills (satisfaction, cleanliness, barista, waiter)
-- at the EXTREME top-centre (owner request 2026-07-27), so the live pressures read
-- at a glance without ever covering the café or dishes below. Each pill is a
-- rounded capsule whose coloured fill grows to the value, with an icon + %.

local Players = game:GetService("Players")

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local OperationsController = {}
OperationsController.Name = "OperationsController"

local player = Players.LocalPlayer
local ui: { [string]: any } = {}
local profile: any = nil

local DEFINITIONS = {
	{ id = "Satisfaction", icon = "😊", color = Theme.Colors.Coral },
	{ id = "Cleanliness", icon = "✨", color = Theme.Colors.Mint },
	{ id = "Barista", icon = "☕", color = Theme.Colors.Honey },
	{ id = "Waiter", icon = "🍽️", color = Theme.Colors.Blue },
}

local function valueFor(id: string): number
	local operations = profile and profile.operations
	if typeof(operations) ~= "table" then
		return 0
	end
	if id == "Satisfaction" then
		return tonumber(operations.satisfaction) or 0
	elseif id == "Cleanliness" then
		return tonumber(operations.cleanliness) or 0
	end
	return tonumber((operations.staffCapacity or {})[id]) or 0
end

local function update()
	if not profile then
		return
	end
	for _, definition in DEFINITIONS do
		local row = ui.rows[definition.id]
		if row then
			local value = math.clamp(valueFor(definition.id), 0, 100)
			row.fill.Size = UDim2.fromScale(value / 100, 1)
			row.label.Text = definition.icon .. " " .. tostring(math.floor(value)) .. "%"
			row.fill.BackgroundColor3 = if value < 25
				then Theme.Colors.Danger
				elseif value < 55 then Theme.Colors.Honey
				else definition.color
		end
	end
end

local function makePill(parent: Instance, definition: any, index: number)
	local pill = Instance.new("Frame")
	pill.Name = definition.id
	pill.Size = UDim2.new(0.25, -4, 1, 0)
	pill.Position = UDim2.new((index - 1) * 0.25, 2, 0, 0)
	pill.BackgroundColor3 = Theme.Colors.Espresso
	pill.BackgroundTransparency = 0.28
	pill.BorderSizePixel = 0
	pill.ZIndex = 6
	pill.ClipsDescendants = true
	Components.Corner(pill, Theme.Radius.Pill)
	pill.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = definition.color
	fill.BackgroundTransparency = 0.3
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	Components.Corner(fill, Theme.Radius.Pill)
	fill.Parent = pill

	local label = Components.Label(pill, definition.icon .. " 0%", 12, true)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Theme.Colors.White
	label.TextStrokeTransparency = 0.6
	label.ZIndex = 8
	label.Parent = pill

	ui.rows[definition.id] = { fill = fill, label = label }
end

local function applyResponsive(mode: string, viewport: Vector2)
	if not ui.card then
		return
	end
	local layout = ResponsiveLayout.hudLayout(mode :: ResponsiveLayout.Mode, viewport)
	ui.card.Size = UDim2.fromOffset(layout.healthWidth, layout.healthHeight)
	ui.card.Position = UDim2.fromOffset(layout.healthLeft, layout.healthTopFromTop)
end

function OperationsController.Start(_self: any)
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("OperationsHUD")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OperationsHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
	gui.Parent = playerGui

	-- A transparent positioning frame; the four pills carry their own backgrounds.
	local card = Instance.new("Frame")
	card.Name = "CafeHealth"
	card.Size = UDim2.fromOffset(360, 30)
	card.Position = UDim2.fromOffset(0, 6)
	card.BackgroundTransparency = 1
	card.Parent = gui
	ui.card = card
	ui.rows = {}

	for index, definition in DEFINITIONS do
		makePill(card, definition, index)
	end

	UIController.subscribeProfile(function(newProfile)
		profile = newProfile
		update()
	end)
	ResponsiveLayout.watch(applyResponsive)
end

return OperationsController
