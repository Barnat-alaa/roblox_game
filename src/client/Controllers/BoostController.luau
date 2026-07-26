--!strict
-- The active-boost HUD pills (docs/MONETISATION.md §Presentation: "2× Coins —
-- 43:12 left"). Making the boost VISIBLE is what makes it feel good. One small
-- top-right pill per active boost, counting down; reads the expiries the server
-- stamped on PlayerData.boosts (boost key → os.time() expiry). Purely a display —
-- EconomyService already applies the 2× while a boost is live.
--
-- Sits just below the session-gift pill (SessionRewardController), same top-right
-- lane. Full modals cover it (higher DisplayOrder), as intended.

local Players = game:GetService("Players")

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local BoostController = {}
BoostController.Name = "BoostController"

-- The boost keys EconomyService honours, with their pill styling.
local BOOSTS = {
	{ key = "coins", label = "2× Coins", color = Theme.Colors.Honey },
	{ key = "reputation", label = "2× Rep", color = Theme.Colors.Mint },
}

local pills: { [string]: { frame: Frame, label: TextLabel } } = {}

local function fmt(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BoostHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15 -- above the world HUD, below the modals (20)
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	for _, b in BOOSTS do
		local frame = Instance.new("Frame")
		frame.Name = "Boost_" .. b.key
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Size = UDim2.fromOffset(158, 34)
		frame.BackgroundColor3 = b.color
		frame.BackgroundTransparency = 0.06
		frame.Visible = false
		Components.Corner(frame, Theme.Radius.Pill)
		Components.Stroke(frame, Theme.Colors.White, 1.5, 0.4)
		frame.Parent = gui

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -16, 1, 0)
		text.Position = UDim2.fromOffset(12, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Font = Theme.Font.Bold
		text.TextSize = 14
		text.TextColor3 = Theme.Colors.Espresso
		text.Text = b.label
		text.Parent = frame

		pills[b.key] = { frame = frame, label = text }
	end
end

-- Stack whichever boosts are live, top-right, directly under the gift pill.
local function refresh()
	local profile = UIController.getProfile()
	local boosts = if profile and typeof(profile.boosts) == "table" then profile.boosts else {}
	local now = os.time()
	local slot = 0
	for _, b in BOOSTS do
		local pill = pills[b.key]
		if pill then
			local left = (tonumber(boosts[b.key]) or 0) - now
			if left > 0 then
				pill.frame.Position = UDim2.new(1, -10, 0, 52 + slot * 40)
				pill.frame.Visible = true
				pill.label.Text = b.label .. " · " .. fmt(left)
				slot += 1
			else
				pill.frame.Visible = false
			end
		end
	end
end

function BoostController.Start(_self: any)
	build()
	UIController.subscribeProfile(refresh)
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return BoostController
