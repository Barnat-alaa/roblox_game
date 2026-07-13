--!strict
-- Manual coffee-brew minigame (Day 3). A ProximityPrompt on YOUR OWN coffee
-- machine opens a timing bar; stop the indicator inside the green zone and the
-- SERVER (RecipeService) verifies the timing and arms a quality bonus for the
-- serve. Everything here is presentation — the server judges the hit from its
-- own clock and never trusts this controller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Cooking = require(Shared.Config.Cooking)

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local CookingController = {}
CookingController.Name = "CookingController"

local currentOrder: any = nil
local brewing = false
local startClock = 0
local renderConn: RBXScriptConnection? = nil
local promptByPart: { [BasePart]: ProximityPrompt } = {}
local ui: { [string]: any } = {}

-- Must match RecipeService.BarPosition exactly (both read Config.Cooking).
local function barPosition(elapsed: number): number
	local phase = (elapsed % Cooking.barPeriod) / Cooking.barPeriod
	return 0.5 + 0.5 * math.sin(2 * math.pi * phase - math.pi / 2)
end

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CookingGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "BrewPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -170)
	panel.Size = UDim2.fromOffset(420, 120)
	panel.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.TextColor3 = Color3.fromRGB(255, 246, 232)
	title.Text = "☕ Brewing — stop in the green!"
	title.Parent = panel

	local barBg = Instance.new("Frame")
	barBg.Name = "Bar"
	barBg.Position = UDim2.new(0, 14, 0, 44)
	barBg.Size = UDim2.new(1, -28, 0, 24)
	barBg.BackgroundColor3 = Color3.fromRGB(35, 27, 24)
	barBg.ClipsDescendants = true
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBg
	barBg.Parent = panel

	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.Position = UDim2.fromScale(Cooking.targetCenter - Cooking.targetHalfWidth, 0)
	zone.Size = UDim2.new(Cooking.targetHalfWidth * 2, 0, 1, 0)
	zone.BackgroundColor3 = Color3.fromRGB(90, 165, 95)
	zone.BackgroundTransparency = 0.2
	zone.BorderSizePixel = 0
	zone.Parent = barBg

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 4, 1, 0)
	indicator.Position = UDim2.fromScale(0, 0)
	indicator.BackgroundColor3 = Color3.fromRGB(255, 248, 235)
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 2
	indicator.Parent = barBg

	local stop = Instance.new("TextButton")
	stop.Name = "Stop"
	stop.AnchorPoint = Vector2.new(0.5, 0)
	stop.Position = UDim2.new(0.5, 0, 0, 76)
	stop.Size = UDim2.fromOffset(170, 36)
	stop.BackgroundColor3 = Color3.fromRGB(200, 100, 70)
	stop.Font = Enum.Font.GothamBold
	stop.TextSize = 18
	stop.TextColor3 = Color3.fromRGB(255, 250, 242)
	stop.Text = "STOP  (Space)"
	local stopCorner = Instance.new("UICorner")
	stopCorner.CornerRadius = UDim.new(0, 10)
	stopCorner.Parent = stop
	stop.Parent = panel

	ui.panel = panel
	ui.zone = zone
	ui.indicator = indicator
	ui.stop = stop
end

local function endBrewVisuals(delay: number)
	task.delay(delay, function()
		if not brewing then
			ui.panel.Visible = false
			ui.zone.BackgroundColor3 = Color3.fromRGB(90, 165, 95)
		end
	end)
end

local function stopRender()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

local function beginBrew()
	if brewing or currentOrder == nil then
		if currentOrder == nil then
			UIController.toast("No order to brew yet — wait for a customer")
		end
		return
	end
	brewing = true
	Remotes.event("StartCooking"):FireServer(currentOrder.orderId)
	startClock = os.clock()
	ui.panel.Visible = true
	stopRender()
	renderConn = RunService.RenderStepped:Connect(function()
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
	stopRender() -- freeze the indicator where it was stopped
	Remotes.event("FinishCooking"):FireServer(currentOrder.orderId)
	-- The panel stays until the server's cook_result arrives (or a fallback).
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

-- Find MY plot (server stamps ownerUserId on the plot model) and watch its
-- furniture folder so freshly placed machines get a prompt too.
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
				then Color3.fromRGB(90, 165, 95)
				else Color3.fromRGB(190, 70, 60)
			if msg.success then
				UIController.toast("Perfect brew! ✨ Serve it for a bonus")
			else
				UIController.toast("Missed the sweet spot — still servable")
			end
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
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space and brewing then
			stopBrew()
		end
	end)

	-- Deferred so buildUi has run before anyone taps it.
	ui.stop.Activated:Connect(stopBrew)
end

return CookingController
