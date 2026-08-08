--!strict
-- First-run intro (owner request 2026-07-27). A full-screen welcome shown the
-- moment you join: it MASKS the initial Creator-Store asset load + café render,
-- lets you NAME your café, then fades away to reveal you standing in front of your
-- own café door. The server fires `WorldReady` once the café is built + assets are
-- loaded; only then does the "Enter my café" button light up. (Café STYLE choices
-- will slot into this same panel later — the layout leaves room.)

local ContentProvider = game:GetService("ContentProvider")
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
-- True once we know this café already has a name, which turns the card from a
-- naming prompt into a welcome-back (owner request 2026-08-05).
local returning = false
-- Longest the card will hold waiting for the world to stream in before letting
-- the player through regardless. Generous, because arriving into a half-built
-- street is worse than a couple more seconds on a card that says why it is there.
local STREAM_WAIT_SECONDS = 15

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

-- `blurWanted` is the authority, not the tween. The blur was surviving into the
-- game because removal could fire while the 0.6s grow tween was still running,
-- and the grow kept writing Size back up; the tween that "wins" is whichever
-- finishes last. Now every exit checks this flag and destroys outright, and the
-- teardown is also hooked to the overlay's own destruction so no dismiss path
-- can leave the world blurred.
local blurWanted = false

local function setBackdropBlur(on: boolean)
	local Lighting = game:GetService("Lighting")
	blurWanted = on
	local existing = Lighting:FindFirstChild("IntroBackdropBlur")
	if not on then
		if existing then
			existing:Destroy()
		end
		return
	end
	local blur = existing or Instance.new("BlurEffect")
	blur.Name = "IntroBackdropBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local grow = TweenService:Create(
		blur,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = 24 }
	)
	grow:Play()
	grow.Completed:Once(function()
		-- Dismissed while we were still fading in.
		if not blurWanted and blur.Parent then
			blur:Destroy()
		end
	end)
end

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

-- `WorldReady` only says the SERVER finished building the café. With
-- Workspace.StreamingEnabled the client then streams the world in separately, so
-- releasing the card on that signal alone dropped the player into a street whose
-- trees and NPCs were still arriving — they popped in around you for several
-- seconds (owner report 2026-08-06).
--
-- This waits for the two things the server cannot know about: that the region
-- around the spawn has actually STREAMED to this client, and that the meshes and
-- textures about to be on screen are DECODED. Bounded by the caller's watchdog,
-- because a player must never be trapped behind the card by a slow asset.
local function awaitWorldStreamed()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		pcall(function()
			-- Radius covers the café you spawn facing plus its neighbours.
			player:RequestStreamAroundAsync((root :: BasePart).Position, 10)
		end)
	end
	local targets: { Instance } = {}
	for _, name in { "Plots", "RoadNetwork", "Customers", "Pedestrians", "Scenery" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(targets, folder)
		end
	end
	if #targets > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(targets)
		end)
	end
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

-- Turn the naming card into a welcome-back for a café that already has a name
-- (owner request 2026-08-05). The text box goes away entirely rather than being
-- pre-filled: leaving an editable field on screen is what made the card read as
-- "confirm your name again" every single join.
local function showReturning(name: string)
	returning = true
	if ui.subtitle then
		ui.subtitle.Text = "Welcome back to"
	end
	if ui.box then
		ui.box.Visible = false
	end
	if ui.nameHint then
		-- Say where renaming lives, since the box that used to imply it is gone.
		ui.nameHint.Text = 'Rename any time at your door — "Name your café".'
		ui.nameHint.Position = UDim2.fromOffset(24, 186)
	end
	if not ui.cafeName then
		local label = Components.Label(ui.card, "", 26, true)
		label.Size = UDim2.new(1, -48, 0, 56)
		label.Position = UDim2.fromOffset(24, 110)
		label.TextColor3 = Theme.Colors.Espresso
		label.TextScaled = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		ui.cafeName = label
	end
	ui.cafeName.Text = name
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
	-- A returning owner is not naming anything, so nothing is sent: re-submitting
	-- the existing name would burn a text-filter round-trip to store the string
	-- the server already has.
	local typed = if ui.box then ui.box.Text else ""
	if not returning and typeof(typed) == "string" and #typed:gsub("%s", "") > 0 then
		Remotes.event("SetCafeName"):FireServer({ name = typed })
	end
	reveal()
end

-- Blur the 3D world behind the intro. Removed again when the overlay fades, and
-- named so a leftover from a reload is replaced rather than stacked.

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroOverlay"
	setBackdropBlur(true)
	-- Belt and braces: whatever tears the overlay down, the world un-blurs.
	gui.Destroying:Connect(function()
		setBackdropBlur(false)
		setHudHidden(false)
	end)
	setHudHidden(true)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- ABOVE every HUD layer. The backdrop is translucent so the blurred world
	-- shows through, which also means anything drawn on top of it stays at full
	-- brightness — the HUD was sitting over the intro and reading as clutter.
	-- Ordering the overlay above it lets the tint dim the HUD too, so the card is
	-- the only thing at full contrast.
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
	ui.card = card

	local title = Components.Label(card, "☕  Social Café City", 28, true)
	title.Size = UDim2.new(1, -40, 0, 40)
	title.Position = UDim2.fromOffset(20, 26)
	title.TextColor3 = Theme.Colors.Espresso

	local subtitle = Components.Label(card, "Let's set up your café. Give it a name!", 15, false)
	subtitle.Size = UDim2.new(1, -40, 0, 24)
	subtitle.Position = UDim2.fromOffset(20, 70)
	subtitle.TextColor3 = Theme.Colors.Muted
	ui.subtitle = subtitle

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
	ui.nameHint = hint

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
		local existing = if typeof(msg) == "table" and typeof(msg.cafeName) == "string"
			then msg.cafeName
			else ""
		if existing ~= "" then
			-- Owner request 2026-08-05: once a café has a name, stop asking for it.
			-- The card used to reappear on every join as a naming prompt with the
			-- old name typed in, so a returning player had to re-confirm a decision
			-- they had already made — and pressing Enter re-sent SetCafeName, paying
			-- for a text filter round-trip to store the identical string. Now it
			-- simply welcomes them back by name. Renaming still lives on the
			-- doormat's "Name your café" prompt (CafeNameController).
			showReturning(existing)
		elseif ui.box then
			ui.box.Text = ""
		end
		-- Hold the card until the street this client is about to see has actually
		-- streamed in, with a watchdog so a slow asset can never trap anyone.
		if ui.status then
			ui.status.Text = "Loading the street…"
		end
		task.spawn(function()
			local streamed = false
			task.spawn(function()
				awaitWorldStreamed()
				streamed = true
			end)
			local deadline = os.clock() + STREAM_WAIT_SECONDS
			while not streamed and os.clock() < deadline do
				task.wait(0.2)
			end
			markReady()
		end)
	end)

	-- Safety net: if WorldReady never arrives (e.g. asset service hiccup), let the
	-- player in anyway rather than trapping them behind the overlay. Longer than
	-- the streaming wait above so it only ever fires when WorldReady is genuinely
	-- lost, not merely slow.
	task.delay(10 + STREAM_WAIT_SECONDS, markReady)
end

return IntroController
