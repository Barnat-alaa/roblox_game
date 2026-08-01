--!strict
-- The "you were just attacked" banner (owner request 2026-08-01: "when a next
-- door café owner does something bad to you, show a CLEAR message").
--
-- Being robbed is the moment the whole social loop is supposed to land, and a
-- toast in the corner was far too easy to miss. This is a loud red banner that
-- slides down from the top, names the neighbour who did it and what they did,
-- and holds long enough to read before sliding away.
--
-- Placement: pinned to the TOP EDGE, not the middle of the screen (owner's
-- standing rule that nothing sits in the centre). It sits below the café-health
-- strip and above everything else at DisplayOrder 30 — this is the one message
-- that should cover a panel if one is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)

local AlertController = {}
AlertController.Name = "AlertController"

local HOLD_SECONDS = 5
local SHOWN_Y = 96 -- clear of the café-health pills at the extreme top
local HIDDEN_Y = -110

local ui: { [string]: any } = {}
local token = 0

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AlertHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30 -- above the modals (20): an attack outranks a panel
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local banner = Instance.new("Frame")
	banner.Name = "AttackBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	banner.Size = UDim2.fromOffset(420, 66)
	banner.BackgroundColor3 = Theme.Colors.Danger
	banner.Visible = false
	Components.Corner(banner, Theme.Radius.Large)
	Components.Stroke(banner, Theme.Colors.White, 2, 0.25)
	banner.Parent = gui

	-- A thick warning stripe so it reads as an alarm at a glance, before any
	-- reading happens.
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.fromOffset(8, 46)
	stripe.Position = UDim2.fromOffset(10, 10)
	stripe.BackgroundColor3 = Theme.Colors.White
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 2
	Components.Corner(stripe, 4)
	stripe.Parent = banner

	local title = Components.Label(banner, "", 15, true)
	title.Name = "AlertTitle"
	title.Size = UDim2.new(1, -40, 0, 24)
	title.Position = UDim2.fromOffset(28, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.White
	title.ZIndex = 2

	local detail = Components.Label(banner, "", 12, false)
	detail.Name = "AlertDetail"
	detail.Size = UDim2.new(1, -40, 0, 26)
	detail.Position = UDim2.fromOffset(28, 32)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextWrapped = true
	detail.TextColor3 = Theme.Colors.White
	detail.ZIndex = 2

	ui.banner = banner
	ui.title = title
	ui.detail = detail

	ResponsiveLayout.watch(function(mode, viewport)
		-- On a phone the banner spans the width rather than sitting as a fixed
		-- card, so the text never truncates on a narrow screen.
		if mode == "Phone" then
			banner.Size = UDim2.new(1, -20, 0, 70)
		else
			banner.Size = UDim2.fromOffset(math.min(460, viewport.X - 40), 66)
		end
	end)
end

local function show(attacker: string, action: string, detail: string)
	if not ui.banner then
		return
	end
	token += 1
	local mine = token
	local banner = ui.banner :: Frame

	ui.title.Text = attacker .. " hit your café — " .. action .. "!"
	ui.detail.Text = detail
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	TweenService:Create(
		banner,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, SHOWN_Y) }
	):Play()

	task.delay(HOLD_SECONDS, function()
		-- A newer alert since this one fired owns the banner now.
		if token ~= mine then
			return
		end
		local away = TweenService:Create(
			banner,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) }
		)
		away:Play()
		away.Completed:Once(function()
			if token == mine then
				banner.Visible = false
			end
		end)
	end)
end

function AlertController.Start(_self: any)
	build()
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" or msg.kind ~= "attacked" then
			return
		end
		show(
			tostring(msg.attacker or "A neighbour"),
			tostring(msg.action or "mischief"),
			tostring(msg.text or "")
		)
	end)
end

return AlertController
