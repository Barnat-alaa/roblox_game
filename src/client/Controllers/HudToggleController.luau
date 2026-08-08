--!strict
-- Collapse-the-pantry tab.
--
-- REWORKED 2026-08-06 on owner feedback, on two counts:
--
-- 1. It used to hide the WHOLE HUD. It now hides only the pantry/stock dock —
--    "make it just hide the pantry inventory". Everything else stays put.
-- 2. It used to sit on the RIGHT edge at DisplayOrder 25, which is ABOVE the
--    modal layer, so whenever a panel was open the tab floated directly over
--    that panel's close button: two buttons stacked on the same pixels, and
--    tapping "close" hit the wrong one. It now lives at the bottom-LEFT beside
--    the thing it collapses, where nothing else is competing for the space.
--
-- Bottom-left is also where a thumb rests on a phone, so the tab doubles as the
-- way to clear the corner for the joystick when the pantry is in the way.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudToggleController = {}
HudToggleController.Name = "HudToggleController"

-- Only the pantry/stock dock. Everything else — the stat pills, the action
-- dock, the rail, timers — stays exactly where it was (owner 2026-08-06).
local MANAGED = { "InventoryHUD" }

local hidden = false
local chevron: Frame? = nil

local function applyState()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, name in MANAGED do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = not hidden
		end
	end
	-- The chevron points the way the HUD will go: right to dismiss, left to
	-- bring it back.
	if chevron then
		TweenService:Create(chevron :: Frame, Theme.Motion.Fast, {
			Rotation = if hidden then 180 else 0,
		}):Play()
	end
end

function HudToggleController.Start(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudToggleHud"
	gui.ResetOnSpawn = false
	-- BELOW the modal layer (20) now. It used to sit at 25, above panels, which
	-- is what put it on top of every panel's close button.
	gui.DisplayOrder = 12
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "HudToggle"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0, 1)
	button.BackgroundColor3 = Theme.Colors.Espresso
	button.BackgroundTransparency = 0.4
	button.Size = UDim2.fromOffset(Theme.Hud.TouchTarget, Theme.Hud.TouchTarget)
	Components.Corner(button, Theme.Radius.Pill)
	Components.Stroke(button, Theme.Colors.Cream, 1, 0.7)
	button.Parent = gui

	-- Drawn from bars rather than a glyph, like the camera arrows: no font can
	-- fail to render it.
	local holder = Instance.new("Frame")
	holder.Name = "Chevron"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(20, 20)
	holder.Parent = button
	for index, tilt in { 38, -38 } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromOffset(4, 13)
		bar.AnchorPoint = Vector2.new(0.5, if index == 1 then 1 else 0)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.BackgroundColor3 = Theme.Colors.Cream
		bar.BackgroundTransparency = 0.1
		bar.BorderSizePixel = 0
		bar.Rotation = -tilt
		Components.Corner(bar, 2)
		bar.Parent = holder
	end
	chevron = holder

	button.Activated:Connect(function()
		hidden = not hidden
		applyState()
	end)

	-- Bottom-left, tucked against the pantry's right edge so it reads as that
	-- panel's own collapse tab rather than a floating control. When the pantry is
	-- hidden it stays exactly where it is — otherwise there would be no way back.
	ResponsiveLayout.watch(function(mode, viewport)
		local stockWidth = select(1, ResponsiveLayout.stockDockSize(mode, viewport))
		local margin = Theme.Hud.EdgeMargin
		button.Size = UDim2.fromOffset(Theme.Hud.TouchTarget, Theme.Hud.TouchTarget)
		button.Position = UDim2.new(0, margin + stockWidth + 6, 1, -margin)
	end)

	-- Re-assert on respawn: these ScreenGuis have ResetOnSpawn = false, but the
	-- state is cheap to reapply and this keeps the tab honest if one is rebuilt.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(1)
		applyState()
	end)
end

return HudToggleController
