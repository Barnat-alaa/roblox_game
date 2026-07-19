--!strict
-- Neighbour visits and compliments in a small contextual card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local InteractionController = {}
InteractionController.Name = "InteractionController"

local COMPLIMENT_BUTTONS = {
	{ id = "nice_cafe", label = "Lovely cafe" },
	{ id = "great_coffee", label = "Great coffee" },
	{ id = "cozy_vibes", label = "Cosy vibes" },
}

local ui: { [string]: any } = {}
local currentVisitPlot: number? = nil

local function goHome()
	Remotes.event("VisitCafe"):FireServer({ home = true })
	currentVisitPlot = nil
	UIController.closePanel(ui.panel)
end

local function buildPanel()
	local panel = Components.Panel(UIController.modalRoot(), "VisitPanel")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(286, 310)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"NEIGHBOUR VISIT",
		"Leave a compliment before you go",
		Theme.Colors.Blue
	)
	close.Activated:Connect(goHome)

	local title = Components.Label(panel, "Visiting a neighbour", 14, true)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 76)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = true
	title.ZIndex = 21
	ui.title = title

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -24, 0, 132)
	list.Position = UDim2.fromOffset(12, 112)
	list.BackgroundTransparency = 1
	list.ZIndex = 21
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	ui.complimentButtons = {}
	for order, definition in COMPLIMENT_BUTTONS do
		local button = Components.Button(
			list,
			definition.label,
			Theme.Colors.Roast,
			UDim2.new(1, 0, 0, 40),
			"+"
		)
		button.LayoutOrder = order
		button.ZIndex = 22
		button.Activated:Connect(function()
			if currentVisitPlot then
				Remotes.event("VisitCafe"):FireServer({
					plotIndex = currentVisitPlot,
					compliment = definition.id,
				})
				for _, other in ui.complimentButtons do
					other.Active = false
					other.BackgroundTransparency = 0.5
				end
			end
		end)
		table.insert(ui.complimentButtons, button)
	end

	local home = Components.Button(
		panel,
		"RETURN HOME",
		Theme.Colors.Coral,
		UDim2.new(1, -24, 0, 44),
		"HOME"
	)
	home.Position = UDim2.new(0, 12, 1, -54)
	home.ZIndex = 22
	home.Activated:Connect(goHome)
	ui.panel = panel
	ResponsiveLayout.watch(function(mode)
		if mode == "Phone" then
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -8)
			panel.Size = UDim2.new(1, -16, 0, 310)
		else
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -12, 0.5, 0)
			panel.Size = UDim2.fromOffset(286, 310)
		end
	end)
end

local function attachPadPrompt(plotModel: Instance, pad: BasePart)
	if pad:FindFirstChild("VisitPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VisitPrompt"
	prompt.ActionText = "Visit Cafe"
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
			ui.title.Text = "Visiting " .. tostring(msg.owner) .. "'s cafe"
			for _, button in ui.complimentButtons do
				button.Active = true
				button.BackgroundTransparency = 0
			end
			UIController.togglePanel(ui.panel)
			UIController.toast("Welcome to " .. tostring(msg.owner) .. "'s cafe")
		elseif msg.kind == "complimented" then
			UIController.toast("Compliment sent")
		end
	end)
end

return InteractionController
