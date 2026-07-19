--!strict
-- Manual brew timing interaction with a compact, contextual overlay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Cooking = require(Shared.Config.Cooking)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)
local AudioController = require(script.Parent.AudioController)

local player = Players.LocalPlayer

local CookingController = {}
CookingController.Name = "CookingController"

local currentOrder: any = nil
local brewing = false
local startClock = 0
local renderConnection: RBXScriptConnection? = nil
local promptByPart: { [BasePart]: ProximityPrompt } = {}
local ui: { [string]: any } = {}

local function barPosition(elapsed: number): number
	local phase = (elapsed % Cooking.barPeriod) / Cooking.barPeriod
	return 0.5 + 0.5 * math.sin(2 * math.pi * phase - math.pi / 2)
end

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CookingGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "BrewPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -96)
	panel.Size = UDim2.fromOffset(430, 126)
	panel.BackgroundColor3 = Theme.Colors.Cream
	panel.Visible = false
	Components.Corner(panel, Theme.Radius.Large)
	Components.Stroke(panel, Theme.Colors.Honey, 2, 0.1)
	panel.Parent = gui

	local title = Components.Label(panel, "BREW TIMING  -  STOP IN THE MINT ZONE", 13, true)
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.fromOffset(10, 7)
	title.TextColor3 = Theme.Colors.Espresso

	local bar = Instance.new("Frame")
	bar.Name = "TimingBar"
	bar.Position = UDim2.fromOffset(14, 40)
	bar.Size = UDim2.new(1, -28, 0, 24)
	bar.BackgroundColor3 = Theme.Colors.Espresso
	bar.ClipsDescendants = true
	Components.Corner(bar, Theme.Radius.Small)
	bar.Parent = panel

	local zone = Instance.new("Frame")
	zone.Name = "SweetSpot"
	zone.Position = UDim2.fromScale(Cooking.targetCenter - Cooking.targetHalfWidth, 0)
	zone.Size = UDim2.fromScale(Cooking.targetHalfWidth * 2, 1)
	zone.BackgroundColor3 = Theme.Colors.Mint
	zone.BackgroundTransparency = 0.08
	zone.BorderSizePixel = 0
	zone.Parent = bar

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 5, 1, 0)
	indicator.Position = UDim2.fromScale(0, 0)
	indicator.BackgroundColor3 = Theme.Colors.White
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 2
	indicator.Parent = bar

	local stop =
		Components.Button(panel, "STOP", Theme.Colors.Coral, UDim2.fromOffset(176, 40), "SPACE")
	stop.AnchorPoint = Vector2.new(0.5, 0)
	stop.Position = UDim2.new(0.5, 0, 0, 76)
	stop.TextSize = 14

	ui.panel = panel
	ui.zone = zone
	ui.indicator = indicator
	ui.stop = stop
	ResponsiveLayout.watch(function(mode, viewport)
		panel.Size = if mode == "Phone"
			then UDim2.fromOffset(math.min(viewport.X - 20, 390), 118)
			else UDim2.fromOffset(430, 126)
		panel.Position = UDim2.new(0.5, 0, 1, if mode == "Phone" then -74 else -96)
	end)
end

local function endBrewVisuals(delaySeconds: number)
	task.delay(delaySeconds, function()
		if not brewing then
			ui.panel.Visible = false
			ui.zone.BackgroundColor3 = Theme.Colors.Mint
		end
	end)
end

local function stopRender()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function beginBrew()
	if brewing or currentOrder == nil then
		if currentOrder == nil then
			UIController.toast("Wait for a customer order before brewing")
		end
		return
	end
	brewing = true
	Remotes.event("StartCooking"):FireServer(currentOrder.orderId)
	AudioController.play("brew")
	startClock = os.clock()
	ui.panel.Visible = true
	stopRender()
	renderConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startClock
		ui.indicator.Position = UDim2.new(barPosition(elapsed), -2, 0, 0)
		if elapsed > Cooking.sessionTtl then
			brewing = false
			stopRender()
			ui.panel.Visible = false
		end
	end)
end

local function stopBrew()
	if not brewing or currentOrder == nil then
		return
	end
	brewing = false
	stopRender()
	Remotes.event("FinishCooking"):FireServer(currentOrder.orderId)
	endBrewVisuals(2)
end

local function attachPrompt(part: BasePart)
	if promptByPart[part] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Brew"
	prompt.ObjectText = "Coffee Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(beginBrew)
	promptByPart[part] = prompt
	part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			promptByPart[part] = nil
		end
	end)
end

local function watchFurniture(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == "coffee_machine" then
			attachPrompt(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") and child.Name == "coffee_machine" then
			attachPrompt(child)
		end
	end)
end

local function findMyPlot()
	local plotsFolder = workspace:WaitForChild("Plots", 30)
	if not plotsFolder then
		return
	end
	while true do
		for _, plot in plotsFolder:GetChildren() do
			if plot:GetAttribute("ownerUserId") == player.UserId then
				local furniture = plot:WaitForChild("Furniture", 10)
				if furniture then
					watchFurniture(furniture)
				end
				return
			end
		end
		task.wait(1)
	end
end

function CookingController.Start(_self: any)
	buildUi()
	task.spawn(findMyPlot)
	Remotes.event("OrderCreated").OnClientEvent:Connect(function(order)
		if typeof(order) == "table" and typeof(order.orderId) == "string" then
			currentOrder = order
		end
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "cook_result" then
			ui.zone.BackgroundColor3 = if msg.success
				then Theme.Colors.Mint
				else Theme.Colors.Danger
			UIController.toast(
				if msg.success
					then "Perfect brew - fresh bonus armed"
					else "Missed the sweet spot - still servable"
			)
			endBrewVisuals(0.7)
		elseif msg.kind == "served" or msg.kind == "order_cancelled" then
			currentOrder = nil
			if brewing then
				brewing = false
				stopRender()
				ui.panel.Visible = false
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.Space and brewing then
			stopBrew()
		end
	end)
	ui.stop.Activated:Connect(stopBrew)
end

return CookingController
