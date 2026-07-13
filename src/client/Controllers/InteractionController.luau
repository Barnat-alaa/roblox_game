--!strict
-- Neighbourhood interactions (Day 5): "Visit Café" prompts on other players'
-- door pads, a compliment panel while visiting, and a Home button. All of it
-- is presentation — SocialService validates every request server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local InteractionController = {}
InteractionController.Name = "InteractionController"

local COMPLIMENT_BUTTONS = {
	{ id = "nice_cafe", label = "💖 Lovely café!" },
	{ id = "great_coffee", label = "☕ Great coffee!" },
	{ id = "cozy_vibes", label = "✨ Cosy vibes!" },
}

local ui: { [string]: any } = {}
local currentVisitPlot: number? = nil

local function buildPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VisitGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "VisitPanel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(210, 236)
	panel.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 40)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextWrapped = true
	title.TextColor3 = Color3.fromRGB(255, 246, 232)
	title.Text = "You're visiting ☕"
	title.Parent = panel
	ui.title = title

	local function button(text: string, order: number, color: Color3): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -20, 0, 36)
		btn.Position = UDim2.new(0, 10, 0, 46 + (order - 1) * 44)
		btn.BackgroundColor3 = color
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 15
		btn.TextColor3 = Color3.fromRGB(255, 250, 242)
		btn.Text = text
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = btn
		btn.Parent = panel
		return btn
	end

	ui.complimentButtons = {}
	for i, def in COMPLIMENT_BUTTONS do
		local btn = button(def.label, i, Color3.fromRGB(120, 95, 160))
		btn.Activated:Connect(function()
			if currentVisitPlot then
				Remotes.event("VisitCafe"):FireServer({
					plotIndex = currentVisitPlot,
					compliment = def.id,
				})
				for _, other in ui.complimentButtons do
					other.AutoButtonColor = false
					other.BackgroundTransparency = 0.5
				end
			end
		end)
		table.insert(ui.complimentButtons, btn)
	end

	local home = button("🏠 Go home", 4, Color3.fromRGB(200, 100, 70))
	home.Activated:Connect(function()
		Remotes.event("VisitCafe"):FireServer({ home = true })
		currentVisitPlot = nil
		panel.Visible = false
	end)

	ui.panel = panel
end

local function attachPadPrompt(plotModel: Instance, pad: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Visit Café"
	prompt.ObjectText = "Neighbour"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false

	local function refresh()
		local ownerUserId = plotModel:GetAttribute("ownerUserId")
		prompt.Enabled = typeof(ownerUserId) == "number" and ownerUserId ~= player.UserId
	end
	refresh()
	plotModel:GetAttributeChangedSignal("ownerUserId"):Connect(refresh)

	prompt.Triggered:Connect(function()
		local plotIndex = plotModel:GetAttribute("plotIndex")
		if typeof(plotIndex) == "number" then
			Remotes.event("VisitCafe"):FireServer({ plotIndex = plotIndex })
		end
	end)
	prompt.Parent = pad
end

local function watchPlots()
	local plotsFolder = workspace:WaitForChild("Plots", 30)
	if not plotsFolder then
		return
	end
	local function hook(plot: Instance)
		task.spawn(function()
			local pad = plot:WaitForChild("VisitPad", 15)
			if pad and pad:IsA("BasePart") then
				attachPadPrompt(plot, pad)
			end
		end)
	end
	for _, plot in plotsFolder:GetChildren() do
		hook(plot)
	end
	plotsFolder.ChildAdded:Connect(hook)
end

function InteractionController.Start(_self: any)
	buildPanel()
	task.spawn(watchPlots)

	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "visited" then
			currentVisitPlot = if typeof(msg.plotIndex) == "number" then msg.plotIndex else nil
			ui.title.Text = "Visiting " .. tostring(msg.owner) .. "'s café ☕"
			for _, btn in ui.complimentButtons do
				btn.AutoButtonColor = true
				btn.BackgroundTransparency = 0
			end
			ui.panel.Visible = true
			UIController.toast("☕ Welcome to " .. tostring(msg.owner) .. "'s café!")
		elseif msg.kind == "complimented" then
			UIController.toast("💌 Compliment sent!")
		end
	end)
end

return InteractionController
