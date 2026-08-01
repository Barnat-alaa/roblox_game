--!strict
-- Learn-by-doing onboarding as a small minimizable task card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Tutorial = require(Shared.Config.Tutorial)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local TutorialController = {}
TutorialController.Name = "TutorialController"

local ui: { [string]: any } = {}
local latestProfile: any = nil
local sentIndex = 0
local sentAt = 0
local minimized = false
local flags = { cooked = false, buy = false, visited = false }

local function plazaClose(): boolean
	local centre = workspace:GetAttribute("PlazaCenter")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(centre) ~= "Vector3" or not (root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - centre).Magnitude <= 18
end

local CONDITIONS: { [string]: () -> boolean } = {
	place_furniture = function()
		return latestProfile ~= nil and #latestProfile.placedFurniture >= 5
	end,
	menu = function()
		return flags.cooked
	end,
	serve = function()
		return latestProfile ~= nil and latestProfile.stats.customersServed >= 1
	end,
	buy = function()
		return flags.buy
	end,
	place_decor = function()
		return latestProfile ~= nil and #latestProfile.placedFurniture >= 6
	end,
	plaza = function()
		return flags.visited or plazaClose()
	end,
}

-- The size the card takes when expanded, chosen per viewport by the responsive
-- pass. It used to be hardcoded here, which silently undid the narrow-screen
-- sizing every time this ran.
local expandedSize = UDim2.fromOffset(360, 72)

local function applyMinimized()
	ui.card.Size = if minimized then UDim2.fromOffset(52, 46) else expandedSize
	ui.step.Visible = not minimized
	ui.text.Visible = not minimized
	ui.minimize.Text = if minimized then "?" else "-"
	ui.minimize.Position = if minimized then UDim2.fromOffset(6, 5) else UDim2.new(1, -38, 0, 8)
end

local function evaluate()
	if latestProfile == nil or not ui.card then
		return
	end
	local stats = latestProfile.stats
	if stats.tutorialCompleted then
		ui.card.Visible = false
		return
	end
	local stepIndex = (stats.tutorialStep or 0) + 1
	local step = Tutorial.steps[stepIndex]
	if step == nil then
		ui.card.Visible = false
		return
	end
	ui.step.Text = "STEP " .. tostring(stepIndex) .. "/" .. tostring(#Tutorial.steps)
	ui.text.Text = step.text
	ui.card.Visible = true
	local condition = CONDITIONS[step.id]
	if condition and condition() and (sentIndex ~= stepIndex or os.clock() - sentAt > 3) then
		sentIndex = stepIndex
		sentAt = os.clock()
		Remotes.event("CompleteTutorialStep"):FireServer(stepIndex)
	end
end

function TutorialController.Start(_self: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The HUD redesign moved the stat pills into the lower-left, where this card
	-- used to sit - an opaque card there hid every currency for the whole of
	-- onboarding. It now sits in the band under the cafe-health card and right
	-- of the camera pad. Short viewports have no such band (the serve button and
	-- action dock reach up into it), so there it goes to the very top strip,
	-- which is clear of the order ticket and the camera pad.
	-- Top-left (owner request). The camera pad used to own this corner on
	-- desktop and the health bars sat under it; both have moved, so the card
	-- gets the corner and the "?" bubble stays somewhere predictable.
	local function cardLeft(_mode: string): number
		-- Hard against the left edge on every platform. This used to be pushed
		-- 118px right on touch to clear the old camera pad — but that pad is gone
		-- (the camera is two edge chevrons now), so the indent was just wasted
		-- screen (owner 2026-08-01: "the introduction steps, put them on the left
		-- of the screen and rearrange it").
		return Theme.Hud.EdgeMargin
	end
	-- The card now lives in the BOTTOM-left column, directly above the money /
	-- star / buzz pills (owner 2026-08-01: "the ? menu with the steps will be put
	-- above the star money etc icons"). Up in the top-left it sat on top of those
	-- pills and hid them.
	local function cardTop(viewport: Vector2): number
		local layout = ResponsiveLayout.currentHudLayout()
		local height = if expandedSize.Y.Offset > 0 then expandedSize.Y.Offset else 72
		-- chipsTopFromTop is where the pill stack begins; sit just above it, and
		-- never let the card climb under Roblox's own topbar.
		return math.max(
			ResponsiveLayout.topInset() + 4,
			math.min(layout.chipsTopFromTop - height - 8, viewport.Y - height - 8)
		)
	end

	local card = Instance.new("Frame")
	card.Name = "TutorialCard"
	card.AnchorPoint = Vector2.new(0, 0)
	card.Size = UDim2.fromOffset(360, 72)
	card.Position = UDim2.new(0, 10, 0, 158)
	card.BackgroundColor3 = Theme.Colors.Cream
	card.Visible = false
	Components.Corner(card, Theme.Radius.Large)
	Components.Stroke(card, Theme.Colors.Honey, 2, 0.15)
	Components.Gradient(card, Theme.Colors.Paper, Theme.Colors.Cream, 90)
	card.Parent = gui
	local accent = Instance.new("Frame")
	accent.Size = UDim2.fromOffset(7, 52)
	accent.Position = UDim2.fromOffset(8, 10)
	accent.BackgroundColor3 = Theme.Colors.Honey
	Components.Corner(accent, 4)
	accent.Parent = card
	local step = Components.Label(card, "", 10, true)
	step.Size = UDim2.new(1, -70, 0, 18)
	step.Position = UDim2.fromOffset(24, 8)
	step.TextColor3 = Theme.Colors.Coral
	step.TextXAlignment = Enum.TextXAlignment.Left
	local body = Components.Label(card, "", 12, true)
	body.Size = UDim2.new(1, -72, 0, 38)
	body.Position = UDim2.fromOffset(24, 26)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local minimize = Components.Button(card, "-", Theme.Colors.Roast, UDim2.fromOffset(32, 32))
	minimize.Position = UDim2.new(1, -38, 0, 8)
	minimize.TextSize = 16
	minimize.Activated:Connect(function()
		minimized = not minimized
		applyMinimized()
	end)
	ui.card = card
	ui.step = step
	ui.text = body
	ui.minimize = minimize

	ResponsiveLayout.watch(function(mode, viewport)
		card.Position = UDim2.new(0, cardLeft(mode), 0, cardTop(viewport))
		-- Short viewports get the squat card: it lives in the top strip there,
		-- which is only tall enough for the compact height.
		local short = viewport.Y < Theme.Hud.ShortViewport
		if mode == "Phone" or short then
			expandedSize = UDim2.fromOffset(math.min(viewport.X - cardLeft(mode) - 20, 236), 62)
			accent.Size = UDim2.fromOffset(7, 38)
			accent.Position = UDim2.fromOffset(8, 8)
			step.Position = UDim2.fromOffset(24, 4)
			body.Position = UDim2.fromOffset(24, 20)
			body.Size = UDim2.new(1, -72, 0, 30)
			body.TextSize = 10
		else
			expandedSize = UDim2.fromOffset(360, 72)
			accent.Size = UDim2.fromOffset(7, 52)
			accent.Position = UDim2.fromOffset(8, 10)
			step.Position = UDim2.fromOffset(24, 8)
			body.Position = UDim2.fromOffset(24, 26)
			body.Size = UDim2.new(1, -72, 0, 38)
			body.TextSize = 12
		end
		applyMinimized()
	end)
	UIController.subscribeProfile(function(profile)
		latestProfile = profile
		evaluate()
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		-- Working the menu is the signal that always fires; collecting a batch
		-- or nailing the brew minigame also count, for a player who gets to an
		-- appliance while the automatic loop happens to be idle.
		if
			msg.kind == "menu_changed"
			or msg.kind == "kitchen_tuned"
			or msg.kind == "cook_collected"
			or msg.kind == "cook_result"
		then
			flags.cooked = true
		elseif msg.kind == "purchased" then
			flags.buy = true
		elseif msg.kind == "visited" then
			flags.visited = true
		elseif msg.kind == "tutorial_done" then
			UIController.toast("Your cafe is officially open  +$" .. tostring(msg.reward))
		end
		evaluate()
	end)
	task.spawn(function()
		while gui.Parent ~= nil do
			task.wait(1)
			evaluate()
		end
	end)
end

return TutorialController
