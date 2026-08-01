--!strict
-- Name your own café (owner request 2026-07-26). A "Name your café" prompt on your
-- own doormat opens a small panel with a text box; the typed name is sent to the
-- server (SetCafeName), which FILTERS it through Roblox's TextService before it is
-- stored and shown on the sign. The prompt is enabled only on the local player's
-- own plot (it shares the doormat with InteractionController's visitor prompt, but
-- the two are never enabled at the same time — one is owner-only, the other not).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local CafeNameController = {}
CafeNameController.Name = "CafeNameController"

local ui: { [string]: any } = {}

local function buildPanel()
	local panel = Components.Panel(UIController.modalRoot(), "CafeNamePanel")
	panel.Size = UDim2.fromOffset(380, 240)
	ResponsiveLayout.watch(function(mode, viewport)
		ResponsiveLayout.dockPanel(panel, mode, viewport, {
			side = "right",
			desktopWidth = 380,
			desktopHeight = 240,
			compactFraction = 0.4,
			compactMin = 300,
			compactMax = 380,
			phoneHeightScale = 0.4,
		})
	end)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"NAME YOUR CAFÉ",
		"It goes on your street sign for everyone to see",
		Theme.Colors.Honey
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local box = Instance.new("TextBox")
	box.Name = "NameBox"
	box.Size = UDim2.new(1, -40, 0, 48)
	box.Position = UDim2.fromOffset(20, 84)
	box.BackgroundColor3 = Theme.Colors.Paper
	box.TextColor3 = Theme.Colors.Ink
	box.Font = Theme.Font.Bold
	box.TextSize = 18
	box.PlaceholderText = "e.g. The Cosy Bean"
	box.PlaceholderColor3 = Theme.Colors.Muted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.MaxVisibleGraphemes = 22
	box.ZIndex = 22
	Components.Corner(box, Theme.Radius.Medium)
	Components.Stroke(box, Theme.Colors.Line, 1, 0.2)
	box.Parent = panel
	ui.box = box

	local hint = Components.Label(panel, "Names are filtered to keep things friendly.", 12, false)
	hint.Size = UDim2.new(1, -40, 0, 20)
	hint.Position = UDim2.fromOffset(20, 138)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Theme.Colors.Muted
	hint.ZIndex = 22

	local save =
		Components.Button(panel, "SAVE NAME", Theme.Colors.MintDark, UDim2.new(1, -40, 0, 44))
	save.Position = UDim2.new(0, 20, 1, -60)
	save.TextColor3 = Theme.Colors.White
	save.ZIndex = 22
	save.Activated:Connect(function()
		local text = ui.box.Text
		if #text > 0 then
			Remotes.event("SetCafeName"):FireServer({ name = text })
		end
	end)
	ui.panel = panel
end

local function openPanel()
	if not ui.panel then
		return
	end
	-- Pre-fill with the current name (minus the "'s Café" default) so it reads as
	-- an edit, not a blank slate.
	local profile = UIController.getProfile()
	if ui.box then
		ui.box.Text = if profile and typeof(profile.cafeName) == "string"
			then profile.cafeName
			else ""
	end
	UIController.togglePanel(ui.panel)
end

local function attachRenamePrompt(plotModel: Instance)
	local pad = plotModel:FindFirstChild("VisitPad")
	if not (pad and pad:IsA("BasePart")) then
		return
	end
	if pad:FindFirstChild("RenamePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RenamePrompt"
	prompt.ActionText = "Name your café"
	prompt.ObjectText = "Your café"
	prompt.KeyboardKeyCode = Enum.KeyCode.N
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	local function refresh()
		prompt.Enabled = plotModel:GetAttribute("ownerUserId") == player.UserId
	end
	refresh()
	plotModel:GetAttributeChangedSignal("ownerUserId"):Connect(refresh)
	prompt.Triggered:Connect(function(who)
		if who == player then
			openPanel()
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
			plot:WaitForChild("VisitPad", 15)
			attachRenamePrompt(plot)
		end)
	end
	for _, plot in plotsFolder:GetChildren() do
		hook(plot)
	end
	plotsFolder.ChildAdded:Connect(hook)
end

function CafeNameController.Start(_self: any)
	buildPanel()
	task.spawn(watchPlots)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "cafe_named" then
			if ui.panel then
				UIController.closePanel(ui.panel)
			end
			UIController.toast(if typeof(msg.text) == "string" then msg.text else "Café renamed!")
		elseif msg.kind == "cafe_name_rejected" then
			UIController.toast(
				if typeof(msg.text) == "string" then msg.text else "Name not allowed."
			)
		end
	end)
end

return CafeNameController
