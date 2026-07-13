--!strict
-- Learn-by-doing onboarding (Day 5). The SERVER owns progress — the profile's
-- stats.tutorialStep advances through ProgressionService, strictly ordered.
-- This controller renders the hint for the NEXT step and reports a step only
-- when the player actually performs it (profile milestones, Notify events, or
-- plaza proximity). Safe to re-run: already-completed profiles show nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Tutorial = require(Shared.Config.Tutorial)

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local TutorialController = {}
TutorialController.Name = "TutorialController"

local hint: TextLabel? = nil
local latestProfile: any = nil
local sentIndex = 0
local sentAt = 0
local flags = { brew = false, buy = false, visited = false }

local function plazaClose(): boolean
	local centre = workspace:GetAttribute("PlazaCenter")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(centre) ~= "Vector3" or not (hrp and hrp:IsA("BasePart")) then
		return false
	end
	return (hrp.Position - centre).Magnitude <= 18
end

-- One detector per step id (see Config/Tutorial). Detection is intentionally
-- forgiving: doing something before its step still counts when reached.
local CONDITIONS: { [string]: () -> boolean } = {
	place_furniture = function()
		return latestProfile ~= nil and #latestProfile.placedFurniture >= 5
	end,
	brew = function()
		return flags.brew
	end,
	serve = function()
		return latestProfile ~= nil and latestProfile.stats.customersServed >= 1
	end,
	buy = function()
		return flags.buy
	end,
	place_decor = function()
		return latestProfile ~= nil and #latestProfile.placedFurniture >= 6
	end,
	plaza = function()
		return flags.visited or plazaClose()
	end,
}

local function evaluate()
	local label = hint
	if latestProfile == nil or label == nil then
		return
	end
	local stats = latestProfile.stats
	if stats.tutorialCompleted then
		label.Visible = false
		return
	end
	local stepIndex = (stats.tutorialStep or 0) + 1
	local step = Tutorial.steps[stepIndex]
	if step == nil then
		label.Visible = false
		return
	end
	label.Text = step.text
	label.Visible = true

	local condition = CONDITIONS[step.id]
	-- Re-send after 3s if the server hasn't advanced us (e.g. rate-limited).
	if condition and condition() and (sentIndex ~= stepIndex or os.clock() - sentAt > 3) then
		sentIndex = stepIndex
		sentAt = os.clock()
		Remotes.event("CompleteTutorialStep"):FireServer(stepIndex)
	end
end

function TutorialController.Start(_self: any)
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHint"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -160, 0, 46)
	label.Position = UDim2.new(0, 80, 1, -150)
	label.BackgroundColor3 = Color3.fromRGB(60, 45, 40)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.fromRGB(255, 246, 232)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextWrapped = true
	label.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = label
	label.Parent = gui
	hint = label

	UIController.subscribeProfile(function(profile)
		latestProfile = profile
		evaluate()
	end)

	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "cook_result" then
			flags.brew = true
		elseif msg.kind == "purchased" then
			flags.buy = true
		elseif msg.kind == "visited" then
			flags.visited = true
		elseif msg.kind == "tutorial_done" then
			UIController.toast(
				"🎉 Your café is officially open! +" .. tostring(msg.reward) .. " 🪙"
			)
		end
		evaluate()
	end)

	-- Low-frequency poll so proximity-based steps (plaza) complete on arrival.
	task.spawn(function()
		while true do
			task.wait(1)
			evaluate()
		end
	end)
end

return TutorialController
