--!strict
-- First-run intro (owner request 2026-07-27). A full-screen welcome shown the
-- moment you join: it MASKS the initial Creator-Store asset load + café render,
-- lets you NAME your café, then fades away to reveal you standing in front of your
-- own café door. The server fires `WorldReady` once the café is built + assets are
-- loaded; only then does the "Enter my café" button light up. (Café STYLE choices
-- will slot into this same panel later — the layout leaves room.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local IntroController = {}
IntroController.Name = "IntroController"

local ui: { [string]: any } = {}
local worldReady = false
local revealed = false

local function setControlsEnabled(enabled: boolean)
	pcall(function()
		local scripts = player:WaitForChild("PlayerScripts", 10)
		local module = scripts and scripts:WaitForChild("PlayerModule", 10)
		if not module then
			return
		end
		local controls = require(module :: ModuleScript):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function markReady()
	if worldReady then
		return
	end
	worldReady = true
	if ui.status then
		ui.status.Text = "Your café is ready — welcome!"
	end
	if ui.enter then
		ui.enter.Text = "Enter my café  ☕"
		ui.enter.BackgroundColor3 = Theme.Colors.MintDark
		ui.enter.AutoButtonColor = true
		ui.enter.Active = true
	end
end

local function reveal()
	if revealed or not worldReady then
		return
	end
	revealed = true
	setControlsEnabled(true)
	local overlay = ui.overlay :: Frame?
	if not overlay then
		return
	end
	local t = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, d in overlay:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			TweenService:Create(d, t, {
				TextTransparency = 1,
				BackgroundTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		elseif d:IsA("Frame") or d:IsA("ImageLabel") then
			TweenService:Create(d, t, { BackgroundTransparency = 1 }):Play()
		end
	end
	TweenService:Create(overlay, t, { BackgroundTransparency = 1 }):Play()
	setBackdropBlur(false)
	setHudHidden(false)
	task.delay(0.7, function()
		if ui.gui then
			ui.gui:Destroy()
		end
	end)
end

local function onEnter()
	if not worldReady then
		return
	end
	local typed = if ui.box then ui.box.Text else ""
	if typeof(typed) == "string" and #typed:gsub("%s", "") > 0 then
		Remotes.event("SetCafeName"):FireServer({ name = typed })
	end
	reveal()
end

-- Blur the 3D world behind the intro. Removed again when the overlay fades, and
-- named so a leftover from a reload is replaced rather than stacked.
-- BlurEffect only blurs the 3D WORLD, never GUIs — so with a see-through backdrop
-- the whole HUD showed through the intro and read as clutter. Hide it while the
-- card is up; the player has nothing to do with it until they are inside anyway.
local HIDDEN_WHILE_INTRO = {
	"HUD",
	"InventoryHUD",
	"OperationsHUD",
	"SessionRewardHud",
	"BoostHud",
	"VipEventHud",
	"TutorialHint",
	"CafeModals",
	"HudToggleHud",
	"CameraGui",
}

local hudWatch: RBXScriptConnection? = nil

local function setHudHidden(hidden: boolean)
	-- WaitForChild, not FindFirstChild: the intro is built early enough that
	-- PlayerGui may not have replicated yet, and an early return here would skip
	-- the ChildAdded watch as well — which is exactly why the HUD kept showing
	-- through the blurred backdrop.
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then
		return
	end
	local function apply(gui: Instance)
		if gui:IsA("ScreenGui") then
			for _, name in HIDDEN_WHILE_INTRO do
				if gui.Name == name then
					gui.Enabled = not hidden
					break
				end
			end
		end
	end
	for _, gui in playerGui:GetChildren() do
		apply(gui)
	end
	if hudWatch then
		hudWatch:Disconnect()
		hudWatch = nil
	end
	-- The intro is built BEFORE most HUD controllers have made their ScreenGui,
	-- so hiding only what exists right now misses nearly all of it. Keep watching
	-- until the card goes away.
	if hidden then
		hudWatch = playerGui.ChildAdded:Connect(apply)
	end
end

local function setBackdropBlur(on: boolean)
	local Lighting = game:GetService("Lighting")
	local existing = Lighting:FindFirstChild("IntroBackdropBlur")
	if not on then
		if existing then
			local tween = TweenService:Create(
				existing,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = 0 }
			)
			tween:Play()
			tween.Completed:Once(function()
				existing:Destroy()
			end)
		end
		return
	end
	local blur = existing or Instance.new("BlurEffect")
	blur.Name = "IntroBackdropBlur"
	blur.Size = 0
	blur.Parent = Lighting
	TweenService:Create(
		blur,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = 24 }
	):Play()
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroOverlay"
	setBackdropBlur(true)
	setHudHidden(true)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200 -- above absolutely everything, including modals (20)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.gui = gui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	-- The backdrop is deliberately SEE-THROUGH: behind it sits the real café and
	-- street, blurred by a Lighting BlurEffect (see `setBackdropBlur`). That is a
	-- live shot of the actual game rather than an uploaded screenshot — nothing to
	-- license, nothing to re-upload when the art changes, and it is always the
	-- build you are about to play. The tint keeps the card readable over whatever
	-- colour happens to be behind it.
	overlay.BackgroundColor3 = Theme.Colors.Espresso
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Parent = gui
	Components.Gradient(overlay, Theme.Colors.Espresso, Theme.Colors.Roast, 90)
	ui.overlay = overlay

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 320)
	card.BackgroundColor3 = Theme.Colors.Paper
	card.BackgroundTransparency = 0.04
	Components.Corner(card, Theme.Radius.Large)
	Components.Stroke(card, Theme.Colors.Honey, 2, 0.2)
	card.Parent = overlay

	local title = Components.Label(card, "☕  Social Café City", 28, true)
	title.Size = UDim2.new(1, -40, 0, 40)
	title.Position = UDim2.fromOffset(20, 26)
	title.TextColor3 = Theme.Colors.Espresso

	local subtitle = Components.Label(card, "Let's set up your café. Give it a name!", 15, false)
	subtitle.Size = UDim2.new(1, -40, 0, 24)
	subtitle.Position = UDim2.fromOffset(20, 70)
	subtitle.TextColor3 = Theme.Colors.Muted

	local box = Instance.new("TextBox")
	box.Name = "NameBox"
	box.Size = UDim2.new(1, -48, 0, 52)
	box.Position = UDim2.fromOffset(24, 116)
	box.BackgroundColor3 = Theme.Colors.PaperDark
	box.TextColor3 = Theme.Colors.Ink
	box.Font = Theme.Font.Bold
	box.TextSize = 20
	box.PlaceholderText = "e.g. The Cosy Bean"
	box.PlaceholderColor3 = Theme.Colors.Muted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.MaxVisibleGraphemes = 22
	Components.Corner(box, Theme.Radius.Medium)
	Components.Stroke(box, Theme.Colors.Line, 1, 0.2)
	box.Parent = card
	ui.box = box

	local hint = Components.Label(card, "You can leave it blank and rename later.", 12, false)
	hint.Size = UDim2.new(1, -48, 0, 18)
	hint.Position = UDim2.fromOffset(24, 176)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Theme.Colors.Muted

	local enter = Components.Button(
		card,
		"Setting up your café…",
		Theme.Colors.Muted,
		UDim2.new(1, -48, 0, 52)
	)
	enter.Position = UDim2.new(0, 24, 1, -70)
	enter.TextColor3 = Theme.Colors.White
	enter.TextSize = 18
	enter.AutoButtonColor = false
	enter.Active = false
	enter.Activated:Connect(onEnter)
	ui.enter = enter

	local status = Components.Label(card, "Loading café…", 12, false)
	status.Size = UDim2.new(1, -40, 0, 18)
	status.Position = UDim2.fromOffset(20, 300)
	status.TextColor3 = Theme.Colors.Muted
	ui.status = status
end

-- Build the overlay in Init (runs synchronously, BEFORE every other controller's
-- Start), so it reliably masks the world from the very first frame the client is
-- up — never a race where the café pops in before the intro appears.
function IntroController.Init(_self: any)
	build()
	setControlsEnabled(false)
end

function IntroController.Start(_self: any)
	Remotes.event("WorldReady").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) == "table" and typeof(msg.cafeName) == "string" and ui.box then
			ui.box.Text = msg.cafeName
		end
		markReady()
	end)

	-- Safety net: if WorldReady never arrives (e.g. asset service hiccup), let the
	-- player in anyway after a few seconds rather than trapping them behind the
	-- overlay.
	task.delay(10, markReady)
end

return IntroController
