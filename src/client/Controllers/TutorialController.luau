--!strict
-- Lightweight learn-by-doing onboarding. Shows one hint at a time and advances
-- as the player's profile hits milestones. Client-only for the MVP; persisting
-- tutorialCompleted server-side is a Day-5 task (CompleteTutorialStep remote).

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local UIController = require(script.Parent.UIController)

local TutorialController = {}
TutorialController.Name = "TutorialController"

local steps: { { text: string, done: (any) -> boolean } } = {
	{
		text = "👋 Welcome! Tap 🔨 Build, pick a chair or table, and tap the floor to place it.",
		done = function(p)
			return #p.placedFurniture > 2
		end,
	},
	{
		text = "☕ A customer is arriving — tap the green Serve button when their order appears.",
		done = function(p)
			return p.stats.customersServed >= 1
		end,
	},
	{
		text = "🛒 Tap Shop, buy a decoration, then place it in Build to make the café yours.",
		done = function(p)
			return #p.placedFurniture > 3
		end,
	},
}

local current = 1

function TutorialController.Start(_self: any)
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHint"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -160, 0, 46)
	hint.Position = UDim2.new(0, 80, 1, -150)
	hint.AnchorPoint = Vector2.new(0, 0)
	hint.BackgroundColor3 = Color3.fromRGB(60, 45, 40)
	hint.BackgroundTransparency = 0.12
	hint.TextColor3 = Color3.fromRGB(255, 246, 232)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 15
	hint.TextWrapped = true
	hint.Text = steps[1].text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = hint
	hint.Parent = gui

	UIController.subscribeProfile(function(profile)
		while current <= #steps and steps[current].done(profile) do
			current += 1
		end
		if current > #steps then
			hint.Visible = false
		else
			hint.Text = steps[current].text
			hint.Visible = true
		end
	end)
end

return TutorialController
