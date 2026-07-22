--!strict
-- Tiny always-visible health card. It makes the four live pressures readable
-- without reopening a full-screen management panel.

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
	{ id = "Satisfaction", short = "SAT", color = Theme.Colors.Coral },
	{ id = "Cleanliness", short = "CLEAN", color = Theme.Colors.Mint },
	{ id = "Barista", short = "BARISTA", color = Theme.Colors.Honey },
	{ id = "Waiter", short = "WAITER", color = Theme.Colors.Blue },
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
		local value = math.clamp(valueFor(definition.id), 0, 100)
		row.fill.Size = UDim2.fromScale(value / 100, 1)
		row.value.Text = tostring(math.floor(value)) .. "%"
		row.fill.BackgroundColor3 = if value < 25
			then Theme.Colors.Danger
			elseif value < 55 then Theme.Colors.Honey
			else definition.color
	end
end

local function makeRow(parent: Instance, definition: any, order: number)
	local row = Instance.new("Frame")
	row.Name = definition.id
	row.Size = UDim2.new(0.5, -8, 0, 18)
	local column = (order - 1) % 2
	local line = math.floor((order - 1) / 2)
	row.Position = UDim2.new(column * 0.5, if column == 0 then 0 else 4, 0, line * 22)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local name = Components.Label(row, definition.short, 8, true)
	name.Size = UDim2.fromOffset(46, 18)
	name.TextColor3 = Theme.Colors.Cream
	name.TextXAlignment = Enum.TextXAlignment.Left
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, -82, 0, 7)
	back.Position = UDim2.fromOffset(48, 6)
	back.BackgroundColor3 = Theme.Colors.Roast
	back.BorderSizePixel = 0
	Components.Corner(back, 4)
	back.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = definition.color
	fill.BorderSizePixel = 0
	Components.Corner(fill, 4)
	fill.Parent = back
	local value = Components.Label(row, "0%", 8, true)
	value.Size = UDim2.fromOffset(32, 18)
	value.Position = UDim2.new(1, -32, 0, 0)
	value.TextColor3 = Theme.Colors.Cream
	value.TextXAlignment = Enum.TextXAlignment.Right
	ui.rows[definition.id] = { fill = fill, value = value }
end

local function applyResponsive(mode: string, viewport: Vector2)
	if not ui.card then
		return
	end
	-- Shared geometry: on narrow screens this card drops into the left column
	-- alongside the camera pad, which reads these same numbers to stay clear.
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

	local card = Instance.new("Frame")
	card.Name = "CafeHealth"
	card.Size = UDim2.fromOffset(304, 50)
	card.Position = UDim2.fromOffset(270, 62)
	card.BackgroundColor3 = Theme.Colors.Espresso
	card.BackgroundTransparency = 0.06
	Components.Corner(card, Theme.Radius.Medium)
	Components.Stroke(card, Theme.Colors.Cream, 1, 0.72)
	card.Parent = gui
	ui.card = card
	ui.rows = {}

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -12, 1, -6)
	list.Position = UDim2.fromOffset(6, 3)
	list.BackgroundTransparency = 1
	list.Parent = card
	for order, definition in DEFINITIONS do
		makeRow(list, definition, order)
	end

	UIController.subscribeProfile(function(newProfile)
		profile = newProfile
		update()
	end)
	ResponsiveLayout.watch(applyResponsive)
end

return OperationsController
