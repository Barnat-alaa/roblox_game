--!strict
-- Neighbour visits: a small contextual card offering the REAL actions (P2). It
-- no longer carries compliments or abstract "help" buttons — helping is done by
-- walking in and doing the jobs (P2c), and the card just says so.

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

local ui: { [string]: any } = {}
local currentVisitPlot: number? = nil

-- The armed steal (P2a). Choosing an item at the door does NOT take it — it
-- lights up that item's shelf and puts a prompt on it. You still have to walk
-- over and press E, which is the whole point: a real, visible action in the
-- world rather than a button on a card. Disarms itself after
-- Mischief.theftArmSeconds so a forgotten pick can't linger.
local armed: { prompt: ProximityPrompt, highlight: Highlight, token: number }? = nil
local armToken = 0

local function disarmSteal()
	local current = armed
	armed = nil
	if current then
		current.prompt:Destroy()
		current.highlight:Destroy()
	end
end

local function armSteal(plotIndex: number, recipeId: string, name: string, shelf: BasePart)
	disarmSteal()
	armToken += 1
	local token = armToken

	local highlight = Instance.new("Highlight")
	highlight.Name = "StealTarget"
	highlight.FillColor = Theme.Colors.Berry
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 235, 140)
	highlight.Adornee = shelf
	highlight.Parent = shelf

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal " .. name
	prompt.ObjectText = "Neighbour's shelf"
	prompt.HoldDuration = 0.6 -- a beat of commitment; not an accidental tap
	prompt.MaxActivationDistance = Mischief.theftShelfRadius
	prompt.RequiresLineOfSight = false
	prompt.Parent = shelf
	prompt.Triggered:Connect(function()
		Remotes.event("Mischief"):FireServer({
			method = "steal",
			plotIndex = plotIndex,
			recipeId = recipeId,
		})
		disarmSteal()
	end)

	armed = { prompt = prompt, highlight = highlight, token = token }
	task.delay(Mischief.theftArmSeconds, function()
		if armed and armed.token == token then
			disarmSteal()
		end
	end)
	UIController.toast("Go to the " .. name .. " shelf and press E")
end

-- Keep the smell-bomb button showing the player's current count (server is the
-- source of truth; the profile carries `smellBombs`). Phase C-4b.
local function refreshSmellCount()
	local button = ui.smellButton
	if not button then
		return
	end
	local profile = UIController.getProfile()
	local n = if profile then tonumber(profile.smellBombs) or 0 else 0
	button.Text = "💨 Smell bomb — clear their café (×" .. tostring(n) .. ")"
end

local function goHome()
	Remotes.event("VisitCafe"):FireServer({ home = true })
	currentVisitPlot = nil
	disarmSteal()
	UIController.closePanel(ui.panel)
end

-- "What could I take?" — the server answers with the neighbour's stocked shelves
-- (and the shelf part itself), filtered to what this player could actually hold.
local function buildStealPanel()
	local panel = Components.Panel(UIController.modalRoot(), "StealPanel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 360)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"STEAL AN ITEM",
		"Pick one, then go to its shelf",
		Theme.Colors.Berry
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -96)
	list.Position = UDim2.fromOffset(12, 84)
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

	ui.stealPanel = panel
	ui.stealList = list
end

local function openStealPicker()
	local plotIndex = currentVisitPlot
	if not plotIndex then
		return
	end
	local list = ui.stealList
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local ok, result = pcall(function()
		return Remotes.func("NeighbourStock"):InvokeServer({ plotIndex = plotIndex })
	end)
	if not ok or typeof(result) ~= "table" then
		UIController.toast("Couldn't see their shelves right now")
		return
	end

	local rows = if typeof(result.items) == "table" then result.items else {}
	if #rows == 0 then
		local empty = Components.Label(list, "Their shelves are bare — nothing you can take.", 13)
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.TextWrapped = true
		empty.ZIndex = 22
	end
	for order, row in rows do
		if typeof(row) == "table" and typeof(row.recipeId) == "string" and row.shelf then
			local button = Components.Button(
				list,
				row.name .. "  ×" .. tostring(row.count),
				Theme.Colors.Berry,
				UDim2.new(1, 0, 0, 40),
				"+"
			)
			button.LayoutOrder = order
			button.ZIndex = 22
			button.Activated:Connect(function()
				armSteal(plotIndex, row.recipeId, tostring(row.name), row.shelf)
				UIController.closePanel(ui.stealPanel)
			end)
		end
	end
	UIController.togglePanel(ui.stealPanel)
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
		"Help out, or cause a little trouble",
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

	-- P2c: helping is no longer a button. The card now just TELLS you that the
	-- way to help is to walk in and do the jobs — clear a plate, scrub the floor,
	-- run an order to a table — and that each one pays you.
	sectionLabel("Lend a hand", 1)
	local howTo = Components.Label(
		list,
		"Walk inside and just DO the work — clear a dirty plate, scrub the floor,"
			.. " or carry an order from the shelf to the table. Each job pays you"
			.. " coins and earns friendship. No buttons needed.",
		12
	)
	howTo.Size = UDim2.new(1, 0, 0, 84)
	howTo.LayoutOrder = 2
	howTo.TextWrapped = true
	howTo.TextXAlignment = Enum.TextXAlignment.Left
	howTo.TextYAlignment = Enum.TextYAlignment.Top
	howTo.ZIndex = 22

	-- Mischief (Phase C-4b) — the one rails-brushing section, shown only when
	-- Config.Mischief.enabled. Server (MischiefService) owns every guardrail.
	if Mischief.enabled then
		sectionLabel("Cause mischief 😈", 20)

		-- P2a: steal a real item off a real shelf. The button only picks the
		-- target; the theft itself happens at the shelf, with E.
		if Mischief.theftEnabled then
			local steal =
				Components.Button(list, "Steal an item", Theme.Colors.Berry, UDim2.new(1, 0, 0, 38))
			steal.LayoutOrder = 20.5
			steal.ZIndex = 22
			steal.Activated:Connect(openStealPicker)
		end

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
			"💨 Smell bomb — clear their café (×0)",
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
			"Buy smell bomb (" .. Mischief.bombCost .. " coins)",
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
	buildStealPanel()
	task.spawn(watchPlots)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "visited" then
			currentVisitPlot = if typeof(msg.plotIndex) == "number" then msg.plotIndex else nil
			ui.title.Text = "Visiting " .. tostring(msg.owner) .. "'s cafe"
			UIController.togglePanel(ui.panel)
			UIController.toast("Welcome to " .. tostring(msg.owner) .. "'s cafe")
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
			or msg.kind == "steal_done"
			or msg.kind == "steal_hit"
			or msg.kind == "steal_blocked"
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
