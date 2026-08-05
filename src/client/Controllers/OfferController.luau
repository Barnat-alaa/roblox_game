--!strict
-- Contextual offers (economy fix #12, docs/ECONOMY_ANALYSIS.md §6).
--
-- The store sat in UPGRADES and was never mentioned again, so a player only saw
-- it if they went looking. The fix is NOT to put a Robux button on the HUD — it
-- is to make the offer appear at the moment the player already feels the
-- friction, and stay silent otherwise.
--
-- The rails forbid fake urgency, so this deliberately has no countdown, no
-- "limited time", and no way to lose anything by ignoring it. Every card is a
-- statement of what is available plus a button that opens the ordinary panel;
-- everything offered is coin-buyable too. If the player does nothing, nothing
-- happens.
--
-- The nag guard is the important part: each key can fire at most once every
-- COOLDOWN seconds, and a card the player dismisses does not come back for
-- twice that. Server triggers like an empty pantry re-fire every second, so
-- without this it would be a strobe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Products = require(Shared.Config.Products)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local OfferController = {}
OfferController.Name = "OfferController"

local COOLDOWN = 240
local DISMISS_COOLDOWN = 480
local SHOW_SECONDS = 9

-- key -> what the player is feeling, and the panel that answers it.
local OFFERS: { [string]: { title: string, body: string, action: string, cta: string } } = {
	pantry_empty = {
		title = "Out of ingredients",
		body = "Your kitchen has stopped. Restock at the Market, or grab a Stock Pack.",
		action = "Upgrades",
		cta = "SEE PACKS",
	},
	no_room = {
		title = "No room left",
		body = "Your café is full. A bigger café pushes the back wall into the garden.",
		action = "Upgrades",
		cta = "SEE SIZES",
	},
	welcome_back = {
		title = "Welcome back",
		body = "Your staff kept working while you were away. VIP earns for longer offline.",
		action = "Upgrades",
		cta = "SEE VIP",
	},
	shift_empty = {
		title = "Your staff are done for the hour",
		body = "Each role only works so many minutes an hour. Levelling them up buys more.",
		action = "Staff",
		cta = "SEE STAFF",
	},
}

-- Economy fix #11 lights two of these up, but only once the products really
-- exist: an offer for something a player cannot then buy is worse than no offer
-- at all. Until the owner pastes the IDs into Config/Products, both moments keep
-- their free-path-only copy. Either way the free path stays in the sentence —
-- the rails ask for the coin route to be visible wherever Robux is mentioned.
if Products.timeProductLive("double_shift") then
	OFFERS.shift_empty.body =
		"Each role only works so many minutes an hour. Level them up, or run a Double Shift."
	OFFERS.shift_empty.action = "Upgrades"
	OFFERS.shift_empty.cta = "SEE OPTIONS"
end
if Products.timeProductLive("instant_expansion") then
	OFFERS.no_room.body =
		"Your café is full. Buy a bigger one with coins, or expand to it instantly."
end

local lastShown: { [string]: number } = {}
local ui: { [string]: any } = {}

local function hide()
	local card = ui.card
	if not card or not card.Visible then
		return
	end
	local tween = TweenService:Create(card, Theme.Motion.Panel, {
		Position = UDim2.new(card.Position.X.Scale, card.Position.X.Offset, 1, 40),
	})
	tween:Play()
	tween.Completed:Once(function()
		card.Visible = false
	end)
end

local function show(key: string)
	local offer = OFFERS[key]
	local card = ui.card
	if not offer or not card then
		return
	end
	local now = os.clock()
	if now - (lastShown[key] or -math.huge) < COOLDOWN then
		return
	end
	lastShown[key] = now

	ui.title.Text = offer.title
	ui.body.Text = offer.body
	ui.cta.Text = offer.cta
	ui.openKey = key
	card.Visible = true
	local target = ui.restPosition or UDim2.new(0.5, 0, 1, -120)
	card.Position = UDim2.new(target.X.Scale, target.X.Offset, 1, 40)
	TweenService:Create(card, Theme.Motion.Panel, { Position = target }):Play()

	task.delay(SHOW_SECONDS, function()
		if ui.openKey == key then
			hide()
		end
	end)
end

function OfferController.Start(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "OfferHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18 -- under the modals it opens, over the world HUD
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.Name = "Offer"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.BackgroundColor3 = Theme.Colors.Paper
	card.BackgroundTransparency = 0.02
	card.Visible = false
	Components.Corner(card, Theme.Radius.Large)
	Components.Stroke(card, Theme.Colors.Honey, 2, 0.15)
	card.Parent = gui

	local title = Components.Label(card, "", 15, true)
	title.Position = UDim2.fromOffset(14, 10)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.Ink

	local body = Components.Label(card, "", 12, false)
	body.Position = UDim2.fromOffset(14, 32)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextColor3 = Theme.Colors.Muted

	local cta = Components.Button(card, "", Theme.Colors.Mint, UDim2.fromOffset(118, 34))
	cta.Activated:Connect(function()
		local key = ui.openKey
		hide()
		if key and OFFERS[key] then
			UIController.openAction(OFFERS[key].action)
		end
	end)

	-- Dismiss is a first-class control, not a corner cross: an offer you cannot
	-- easily refuse is a nag. Refusing also buys a longer quiet period.
	local no = Components.Button(card, "NOT NOW", Theme.Colors.PaperDark, UDim2.fromOffset(88, 34))
	no.TextColor3 = Theme.Colors.Muted
	no.Activated:Connect(function()
		local key = ui.openKey
		if key then
			lastShown[key] = os.clock() + (DISMISS_COOLDOWN - COOLDOWN)
		end
		hide()
	end)

	ui.card, ui.title, ui.body, ui.cta = card, title, body, cta

	ResponsiveLayout.watch(function(mode, viewport)
		local layout = ResponsiveLayout.hudLayout(mode, viewport)
		local width = math.min(360, viewport.X - 2 * Theme.Hud.EdgeMargin)
		card.Size = UDim2.fromOffset(width, 108)
		title.Size = UDim2.new(1, -28, 0, 20)
		body.Size = UDim2.new(1, -28, 0, 34)
		cta.Position = UDim2.new(1, -132, 1, -44)
		no.Position = UDim2.new(1, -226, 1, -44)
		-- Sits clear of the action dock so it never covers the six buttons.
		local bottom = layout.dockBottom + layout.dockPlate + layout.labelBand + 16
		ui.restPosition = UDim2.new(0.5, 0, 1, -bottom)
		if card.Visible then
			card.Position = ui.restPosition
		end
	end)

	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) == "table" and msg.kind == "offer" and typeof(msg.offer) == "string" then
			show(msg.offer)
		end
	end)
end

return OfferController
