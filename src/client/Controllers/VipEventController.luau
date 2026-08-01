--!strict
-- The scheduled VIP event countdown (P3). A pill under the gift timer in the
-- top-right shows the brainrot's PICTURE and the time until the next VIP event,
-- so the whole street can see it coming and get their café ready.
--
-- The server (VipService) owns the clock and the event; this only DISPLAYS the
-- `nextAt` it is told, ticking it down against workspace:GetServerTimeNow() so
-- every client agrees. It never asks for a VIP.
--
-- Placement: directly below SessionRewardController's gift pill, which sits at
-- top-right y=8 and is 38 tall — this takes y=54. Full modals are at a higher
-- DisplayOrder and cover it while open, as intended.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local VipEventController = {}
VipEventController.Name = "VipEventController"

local nextAt: number? = nil
local label: TextLabel? = nil
local pill: Frame? = nil
local portrait: ImageLabel? = nil

local function fmt(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VipEventHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15 -- same band as the gift pill; under the modals (20)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "VipTimer"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -6, 0, 36)
	frame.Size = UDim2.fromOffset(132, 32)
	frame.BackgroundColor3 = Theme.Colors.Berry
	frame.BackgroundTransparency = 0.06
	frame.Visible = false
	Components.Corner(frame, Theme.Radius.Pill)
	Components.Stroke(frame, Theme.Colors.White, 1.5, 0.4)
	frame.Parent = gui

	-- The brainrot's own picture, pulled straight off the asset via rbxthumb so
	-- there is no second image to upload or keep in sync.
	local image = Instance.new("ImageLabel")
	image.Name = "Portrait"
	image.BackgroundColor3 = Theme.Colors.White
	image.BackgroundTransparency = 0.25
	image.Size = UDim2.fromOffset(24, 24)
	image.Position = UDim2.fromOffset(4, 4)
	image.ScaleType = Enum.ScaleType.Fit
	Components.Corner(image, UDim.new(1, 0))
	image.Parent = frame
	portrait = image

	local text = Instance.new("TextLabel")
	text.Name = "TimerLabel"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -36, 1, 0)
	text.Position = UDim2.fromOffset(32, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Font = Theme.Font.Bold
	text.TextSize = 12
	text.TextColor3 = Theme.Colors.White
	text.Text = "VIP event"
	text.Parent = frame

	pill = frame
	label = text
end

-- A pop when the VIP actually lands, so the countdown resolves into something felt.
local function celebrate()
	if not pill then
		return
	end
	local frame = pill :: Frame
	frame.Visible = true
	local grow = TweenService:Create(
		frame,
		TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(146, 36) }
	)
	grow:Play()
	grow.Completed:Once(function()
		if pill == frame then
			TweenService:Create(frame, Theme.Motion.Settle, { Size = UDim2.fromOffset(132, 32) })
				:Play()
		end
	end)
end

function VipEventController.Start(_self: any)
	build()

	Remotes.event("VipEvent").OnClientEvent:Connect(function(msg: any)
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
			if typeof(msg.assetId) == "number" and portrait then
				(portrait :: ImageLabel).Image = "rbxthumb://type=Asset&id="
					.. tostring(msg.assetId)
					.. "&w=150&h=150"
			end
		elseif msg.kind == "arrived" then
			UIController.toast("⭐ The VIP went to " .. tostring(msg.cafe) .. "'s café!")
			celebrate()
		end
	end)

	-- Tick locally off the synced server clock.
	task.spawn(function()
		while true do
			if nextAt and label then
				local remaining = (nextAt :: number) - workspace:GetServerTimeNow()
				if remaining > 0.5 then
					(label :: TextLabel).Text = "VIP " .. fmt(remaining)
				else
					(label :: TextLabel).Text = "VIP now!"
				end
			end
			task.wait(0.25)
		end
	end)
end

return VipEventController
