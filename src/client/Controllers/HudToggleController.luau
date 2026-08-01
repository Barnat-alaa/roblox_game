--!strict
-- Hide-the-HUD tab (owner request 2026-08-01: "you can even add a sort of sliding
-- button to hide them in the phone").
--
-- One small chevron pinned to the right edge. Tap it and the whole interface
-- slides away, leaving the café and nothing else; tap it again and everything
-- comes back exactly as it was. It is the fastest way to actually look at the
-- thing you have been decorating, and on a phone it doubles as the escape hatch
-- when the HUD feels crowded.
--
-- What stays visible when hidden is deliberate:
--   • the tab itself, or there would be no way back;
--   • the camera arrows, so you can still turn and look around;
--   • the attack banner, because being robbed must never be silently missed;
--   • open panels, since hiding the HUD should not cancel what you were doing.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudToggleController = {}
HudToggleController.Name = "HudToggleController"

-- Every ScreenGui the tab controls. Anything not listed here is unaffected,
-- which is how the exceptions above are expressed.
local MANAGED = {
	"HUD",
	"InventoryHUD",
	"OperationsHUD",
	"SessionRewardHud",
	"BoostHud",
	"VipEventHud",
	"TutorialHint",
}

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
	-- Above the modals so the tab is always reachable, below the attack banner.
	gui.DisplayOrder = 25
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "HudToggle"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(1, 0.5)
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

	-- Sits on the right edge, ABOVE the rail's vertical run so it never covers a
	-- rail button; the rail is centred, so the upper third is clear.
	ResponsiveLayout.watch(function(_mode, viewport)
		button.Position = UDim2.new(1, -Theme.Hud.EdgeMargin, 0, math.floor(viewport.Y * 0.2))
	end)

	-- Re-assert on respawn: these ScreenGuis have ResetOnSpawn = false, but the
	-- state is cheap to reapply and this keeps the tab honest if one is rebuilt.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(1)
		applyState()
	end)
end

return HudToggleController
