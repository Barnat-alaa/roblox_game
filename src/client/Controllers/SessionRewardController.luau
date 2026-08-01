--!strict
-- The session/playtime gift countdown (owner bug 1, 2026-07-26). A small pill in
-- the top-right corner ticks down to the player's next gift; a toast celebrates
-- each one as it lands. The server (SessionRewardService) owns the clock and the
-- grant — this only DISPLAYS the countdown it is told, and never asks for a gift.
--
-- Placement: FIRST in the shared right-edge column declared by Theme.Hud.Pills —
-- gift pill, VIP pill, order ticket, then the rail, each derived from the one
-- above it in ResponsiveLayout. Do not hand-position it; the corner is shared
-- with three other files. Full modals sit at a higher DisplayOrder and cover the
-- pill while open, as intended.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local SessionRewardController = {}
SessionRewardController.Name = "SessionRewardController"

local nextAt: number? = nil
local label: TextLabel? = nil
local pill: Frame? = nil

local function fmt(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function rewardText(reward: any): string
	local amount = tonumber(reward and reward.amount) or 0
	if reward and reward.kind == "reputation" then
		return "+" .. tostring(amount) .. " reputation"
	end
	return "+" .. tostring(amount) .. " coins"
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SessionRewardHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15 -- above the world HUD, below the modals (20)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- The gift and VIP pills were the only two HUDs that never set this, so they
	-- inherited CoreUISafeInsets and Roblox pushed them a topbar's height DOWN the
	-- screen. Their y=4 was landing near y=90 on a phone — level with the rail's
	-- first button, which they then covered. Every other HUD positions from the
	-- true top, and these two must agree or the corner cannot be shared.
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "GiftTimer"
	frame.AnchorPoint = Vector2.new(1, 0)
	-- Extreme top-right, first in the shared right-edge column (Theme.Hud.Pills).
	frame.Position = UDim2.new(1, -6, 0, Theme.Hud.Pills.Top)
	frame.Size = UDim2.fromOffset(Theme.Hud.Pills.Width, Theme.Hud.Pills.GiftHeight)
	frame.BackgroundColor3 = Theme.Colors.Honey
	frame.BackgroundTransparency = 0.06
	frame.Visible = false
	Components.Corner(frame, Theme.Radius.Pill)
	Components.Stroke(frame, Theme.Colors.White, 1.5, 0.4)
	frame.Parent = gui

	local text = Instance.new("TextLabel")
	text.Name = "TimerLabel"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -12, 1, 0)
	text.Position = UDim2.fromOffset(9, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Font = Theme.Font.Bold
	text.TextSize = 12
	text.TextColor3 = Theme.Colors.Espresso
	text.Text = "Next gift"
	text.Parent = frame

	pill = frame
	label = text
end

-- A quick pop so a landed gift is felt on the pill as well as the toast.
local function celebrate()
	if not pill then
		return
	end
	local frame = pill :: Frame
	frame.Visible = true
	frame.Size = UDim2.fromOffset(196, 38)
	local grow = TweenService:Create(
		frame,
		TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(146, 32) }
	)
	grow:Play()
	grow.Completed:Once(function()
		if pill == frame then
			TweenService:Create(frame, Theme.Motion.Settle, {
				Size = UDim2.fromOffset(Theme.Hud.Pills.Width, Theme.Hud.Pills.GiftHeight),
			}):Play()
		end
	end)
end

function SessionRewardController.Start(_self: any)
	build()

	Remotes.event("SessionReward").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "timer" then
			if typeof(msg.nextAt) == "number" then
				nextAt = msg.nextAt
				if pill then
					(pill :: Frame).Visible = true
				end
			end
		elseif msg.kind == "granted" then
			local reward = msg.reward
			local lead = if msg.reason == "connect"
				then "🎁 Welcome gift!"
				else "🎁 Playtime gift!"
			UIController.toast(lead .. "  " .. rewardText(reward))
			celebrate()
		end
	end)

	-- Tick the countdown locally off the synced server clock.
	task.spawn(function()
		while true do
			if nextAt and label then
				local remaining = (nextAt :: number) - workspace:GetServerTimeNow()
				if remaining > 0.5 then
					(label :: TextLabel).Text = "Gift " .. fmt(remaining)
				else
					(label :: TextLabel).Text = "Gift ready!"
				end
			end
			task.wait(0.25)
		end
	end)
end

return SessionRewardController
