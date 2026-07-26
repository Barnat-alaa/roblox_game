--!strict
-- Neighbour visits and compliments in a small contextual card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Mischief = require(Shared.Config.Mischief)

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

-- Co-op help actions (Phase C §4a). Server (SocialService.HELP_ACTIONS) is the
-- source of truth for rewards + the once-per-neighbour-per-day cap.
local HELP_BUTTONS = {
	{ id = "water_plants", label = "💧 Water plants" },
	{ id = "bus_table", label = "🧽 Bus a table" },
	{ id = "stir_pot", label = "🥄 Stir a pot" },
	{ id = "hand_flyers", label = "📣 Hand flyers" },
}

local ui: { [string]: any } = {}
local currentVisitPlot: number? = nil

-- Keep the smell-bomb button showing the player's current count (server is the
-- source of truth; the profile carries `smellBombs`). Phase C-4b.
local function refreshSmellCount()
	local button = ui.smellButton
	if not button then
		return
	end
	local profile = UIController.getProfile()
	local n = if profile then tonumber(profile.smellBombs) or 0 else 0
	button.Text = "💨 Smell bomb (×" .. tostring(n) .. ")"
end

local function goHome()
	Remotes.event("VisitCafe"):FireServer({ home = true })
	currentVisitPlot = nil
	UIController.closePanel(ui.panel)
end

local function buildPanel()
	local panel = Components.Panel(UIController.modalRoot(), "VisitPanel")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(286, 420)
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

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 0, 258)
	list.Position = UDim2.fromOffset(12, 112)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = 21
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function sectionLabel(labelText: string, order: number)
		local lbl = Components.Label(list, labelText, 12, true)
		lbl.Size = UDim2.new(1, 0, 0, 20)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.fromRGB(190, 180, 170)
		lbl.LayoutOrder = order
		lbl.ZIndex = 22
	end

	sectionLabel("Say something nice", 1)
	ui.complimentButtons = {}
	for order, definition in COMPLIMENT_BUTTONS do
		local button = Components.Button(
			list,
			definition.label,
			Theme.Colors.Roast,
			UDim2.new(1, 0, 0, 38),
			"+"
		)
		button.LayoutOrder = 1 + order
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

	sectionLabel("Lend a hand", 10)
	ui.helpButtons = {}
	for order, definition in HELP_BUTTONS do
		local button = Components.Button(
			list,
			definition.label,
			Theme.Colors.Blue,
			UDim2.new(1, 0, 0, 38),
			"♥"
		)
		button.LayoutOrder = 10 + order
		button.ZIndex = 22
		button.Activated:Connect(function()
			if currentVisitPlot then
				Remotes.event("NeighbourHelp"):FireServer({
					plotIndex = currentVisitPlot,
					actionId = definition.id,
				})
			end
		end)
		table.insert(ui.helpButtons, button)
	end

	-- Mischief (Phase C-4b) — the one rails-brushing section, shown only when
	-- Config.Mischief.enabled. Server (MischiefService) owns every guardrail.
	if Mischief.enabled then
		sectionLabel("Cause mischief 😈", 20)
		local recruit = Components.Button(
			list,
			"😈 Poach a customer (free)",
			Theme.Colors.Berry,
			UDim2.new(1, 0, 0, 38)
		)
		recruit.LayoutOrder = 21
		recruit.ZIndex = 22
		recruit.Activated:Connect(function()
			if currentVisitPlot then
				Remotes.event("Mischief"):FireServer({
					method = "recruit",
					plotIndex = currentVisitPlot,
				})
			end
		end)

		local bomb = Components.Button(
			list,
			"💨 Smell bomb (×0)",
			Theme.Colors.Berry,
			UDim2.new(1, 0, 0, 38)
		)
		bomb.LayoutOrder = 22
		bomb.ZIndex = 22
		bomb.Activated:Connect(function()
			if currentVisitPlot then
				Remotes.event("Mischief"):FireServer({
					method = "smell_bomb",
					plotIndex = currentVisitPlot,
				})
			end
		end)
		ui.smellButton = bomb

		local buy = Components.Button(
			list,
			"🛒 Buy smell bomb (" .. Mischief.bombCost .. " 🪙)",
			Theme.Colors.Roast,
			UDim2.new(1, 0, 0, 38)
		)
		buy.LayoutOrder = 23
		buy.ZIndex = 22
		buy.Activated:Connect(function()
			Remotes.event("Mischief"):FireServer({ method = "buy_bomb" })
		end)

		refreshSmellCount()
		UIController.subscribeProfile(refreshSmellCount)
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
			panel.Size = UDim2.new(1, -16, 0, 420)
		else
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -12, 0.5, 0)
			panel.Size = UDim2.fromOffset(286, 420)
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
			for _, button in ui.helpButtons do
				button.Active = true
				button.BackgroundTransparency = 0
			end
			UIController.togglePanel(ui.panel)
			UIController.toast("Welcome to " .. tostring(msg.owner) .. "'s cafe")
		elseif msg.kind == "complimented" then
			UIController.toast("Compliment sent")
		elseif
			msg.kind == "helped"
			or msg.kind == "neighbour_helped"
			or msg.kind == "help_blocked"
		then
			if typeof(msg.text) == "string" then
				UIController.toast(msg.text)
			end
		elseif
			msg.kind == "mischief_done"
			or msg.kind == "mischief_hit"
			or msg.kind == "mischief_blocked"
			or msg.kind == "mischief_bought"
		then
			if typeof(msg.text) == "string" then
				UIController.toast(msg.text)
			end
			if msg.kind == "mischief_bought" then
				refreshSmellCount()
			end
		end
	end)
end

return InteractionController
