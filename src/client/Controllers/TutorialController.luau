--!strict
-- Learn-by-doing onboarding as a small minimizable task card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Tutorial = require(Shared.Config.Tutorial)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local TutorialController = {}
TutorialController.Name = "TutorialController"

local ui: { [string]: any } = {}
local latestProfile: any = nil
local sentIndex = 0
local sentAt = 0
local minimized = false
local flags = { brew = false, buy = false, visited = false }

local function plazaClose(): boolean
	local centre = workspace:GetAttribute("PlazaCenter")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(centre) ~= "Vector3" or not (root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - centre).Magnitude <= 18
end

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

local function applyMinimized()
	ui.card.Size = if minimized then UDim2.fromOffset(52, 46) else UDim2.fromOffset(360, 72)
	ui.step.Visible = not minimized
	ui.text.Visible = not minimized
	ui.minimize.Text = if minimized then "?" else "-"
	ui.minimize.Position = if minimized then UDim2.fromOffset(6, 5) else UDim2.new(1, -38, 0, 8)
end

local function evaluate()
	if latestProfile == nil or not ui.card then
		return
	end
	local stats = latestProfile.stats
	if stats.tutorialCompleted then
		ui.card.Visible = false
		return
	end
	local stepIndex = (stats.tutorialStep or 0) + 1
	local step = Tutorial.steps[stepIndex]
	if step == nil then
		ui.card.Visible = false
		return
	end
	ui.step.Text = "STEP " .. tostring(stepIndex) .. "/" .. tostring(#Tutorial.steps)
	ui.text.Text = step.text
	ui.card.Visible = true
	local condition = CONDITIONS[step.id]
	if condition and condition() and (sentIndex ~= stepIndex or os.clock() - sentAt > 3) then
		sentIndex = stepIndex
		sentAt = os.clock()
		Remotes.event("CompleteTutorialStep"):FireServer(stepIndex)
	end
end

function TutorialController.Start(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.Name = "TutorialCard"
	card.AnchorPoint = Vector2.new(0, 1)
	card.Size = UDim2.fromOffset(360, 72)
	card.Position = UDim2.new(0, 10, 1, -98)
	card.BackgroundColor3 = Theme.Colors.Cream
	card.Visible = false
	Components.Corner(card, Theme.Radius.Large)
	Components.Stroke(card, Theme.Colors.Honey, 2, 0.15)
	Components.Gradient(card, Theme.Colors.Paper, Theme.Colors.Cream, 90)
	card.Parent = gui
	local accent = Instance.new("Frame")
	accent.Size = UDim2.fromOffset(7, 52)
	accent.Position = UDim2.fromOffset(8, 10)
	accent.BackgroundColor3 = Theme.Colors.Honey
	Components.Corner(accent, 4)
	accent.Parent = card
	local step = Components.Label(card, "", 10, true)
	step.Size = UDim2.new(1, -70, 0, 18)
	step.Position = UDim2.fromOffset(24, 8)
	step.TextColor3 = Theme.Colors.Coral
	step.TextXAlignment = Enum.TextXAlignment.Left
	local body = Components.Label(card, "", 12, true)
	body.Size = UDim2.new(1, -72, 0, 38)
	body.Position = UDim2.fromOffset(24, 26)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local minimize = Components.Button(card, "-", Theme.Colors.Roast, UDim2.fromOffset(32, 32))
	minimize.Position = UDim2.new(1, -38, 0, 8)
	minimize.TextSize = 16
	minimize.Activated:Connect(function()
		minimized = not minimized
		applyMinimized()
	end)
	ui.card = card
	ui.step = step
	ui.text = body
	ui.minimize = minimize

	ResponsiveLayout.watch(function(mode, viewport)
		if mode == "Phone" and not minimized then
			card.Size = UDim2.fromOffset(math.min(viewport.X - 82, 340), 54)
			card.Position = UDim2.new(0, 10, 1, -72)
			accent.Size = UDim2.fromOffset(7, 38)
			accent.Position = UDim2.fromOffset(8, 8)
			step.Position = UDim2.fromOffset(24, 4)
			body.Position = UDim2.fromOffset(24, 20)
			body.Size = UDim2.new(1, -72, 0, 30)
			body.TextSize = 10
		else
			if mode == "Compact" and not minimized then
				card.Size = UDim2.fromOffset(math.clamp(viewport.X - 420, 220, 292), 54)
			end
			card.Position = UDim2.new(0, 10, 1, if mode == "Compact" then -72 else -98)
			accent.Size = UDim2.fromOffset(7, 52)
			accent.Position = UDim2.fromOffset(8, 10)
			step.Position = UDim2.fromOffset(24, 8)
			body.Position = UDim2.fromOffset(24, 26)
			body.Size = UDim2.new(1, -72, 0, 38)
			body.TextSize = 12
			applyMinimized()
		end
	end)
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
			UIController.toast("Your cafe is officially open  +$" .. tostring(msg.reward))
		end
		evaluate()
	end)
	task.spawn(function()
		while gui.Parent ~= nil do
			task.wait(1)
			evaluate()
		end
	end)
end

return TutorialController
