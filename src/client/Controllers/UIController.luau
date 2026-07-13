--!strict
-- The HUD: stat bar, current-order banner + Serve button, shop panel, and toasts.
-- Owns all core UI. Other controllers depend on it (never the reverse) via
-- UIController.onBuildToggle (settable) and UIController.subscribeProfile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Network.Remotes)
local Furniture = require(Shared.Config.Furniture)

local player = Players.LocalPlayer

local CREAM = Color3.fromRGB(245, 235, 218)
local TERRA = Color3.fromRGB(200, 100, 70)
local DARK = Color3.fromRGB(55, 42, 38)

local FRIENDLY_ERROR = {
	not_owned = "You don't own that item.",
	insufficient_coins = "Not enough coins.",
	level_locked = "Reach a higher level first.",
	out_of_bounds = "That doesn't fit on your plot.",
	overlap = "Something is already there.",
	too_many_objects = "Your café is full.",
	too_far = "Get closer to your counter.",
	not_rotatable = "That item can't rotate.",
}

local UIController = {}
UIController.Name = "UIController"
UIController.onBuildToggle = nil :: (() -> ())?

local profile: any = nil
local currentOrderId: string? = nil
local profileListeners: { (any) -> () } = {}
local ui: { [string]: any } = {}

local function corner(radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	return c
end

local function pad(px: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	return p
end

function UIController.getProfile(): any
	return profile
end

function UIController.subscribeProfile(cb: (any) -> ())
	table.insert(profileListeners, cb)
	if profile then
		cb(profile)
	end
end

function UIController.toast(text: string)
	ui.toast.Text = text
	ui.toast.Visible = true
	local token = os.clock()
	ui.toastToken = token
	task.delay(2.5, function()
		if ui.toastToken == token then
			ui.toast.Visible = false
		end
	end)
end

local function updateStats()
	if not profile then
		return
	end
	ui.coins.Text = "🪙 " .. tostring(profile.coins)
	ui.rep.Text = "⭐ " .. tostring(profile.reputation)
	ui.level.Text = "Lv " .. tostring(profile.level) .. " " .. string.rep("★", profile.cafeStars)
end

local function setProfile(newProfile: any)
	profile = newProfile
	updateStats()
	for _, cb in profileListeners do
		task.spawn(cb, profile)
	end
end

local function showOrder(order: any)
	currentOrderId = order.orderId
	ui.orderBanner.Text = "☕ Order: " .. tostring(order.recipeId)
	ui.orderBanner.Visible = true
	ui.serve.Visible = true
end

local function clearOrder()
	currentOrderId = nil
	ui.orderBanner.Visible = false
	ui.serve.Visible = false
end

local function makeActionButton(text: string, color: Color3, order: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(132, 54)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 250, 242)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 20
	btn.Text = text
	btn.AutoButtonColor = true
	btn.LayoutOrder = order
	corner(12).Parent = btn
	return btn
end

local function buildShop(parent: Instance)
	local panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.Size = UDim2.fromOffset(320, 380)
	panel.Position = UDim2.new(1, -340, 1, -460)
	panel.BackgroundColor3 = CREAM
	panel.Visible = false
	corner(16).Parent = panel
	pad(12).Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "🛒 Shop"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = DARK
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -36)
	list.Position = UDim2.fromOffset(0, 36)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for id, def in Furniture do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 46)
		row.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
		corner(10).Parent = row

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -96, 1, 0)
		name.Position = UDim2.fromOffset(10, 0)
		name.BackgroundTransparency = 1
		name.Text = def.displayName .. "  🪙" .. tostring(def.price)
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 15
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = DARK
		name.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(76, 34)
		buy.Position = UDim2.new(1, -84, 0.5, -17)
		buy.BackgroundColor3 = TERRA
		buy.TextColor3 = Color3.fromRGB(255, 250, 242)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 15
		buy.Text = "Buy"
		corner(8).Parent = buy
		buy.Activated:Connect(function()
			Remotes.event("PurchaseItem"):FireServer(id)
		end)
		buy.Parent = row

		row.Parent = list
	end

	panel.Parent = parent
	ui.shopPanel = panel
end

function UIController.Start(_self: any)
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Stat bar (top-left)
	local statBar = Instance.new("Frame")
	statBar.Size = UDim2.fromOffset(300, 42)
	statBar.Position = UDim2.fromOffset(12, 12)
	statBar.BackgroundColor3 = DARK
	statBar.BackgroundTransparency = 0.1
	corner(12).Parent = statBar
	statBar.Parent = gui

	local statLayout = Instance.new("UIListLayout")
	statLayout.FillDirection = Enum.FillDirection.Horizontal
	statLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statLayout.Padding = UDim.new(0, 8)
	statLayout.Parent = statBar

	local function stat(order: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromOffset(94, 30)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = 16
		l.TextColor3 = Color3.fromRGB(255, 246, 232)
		l.Text = ""
		l.LayoutOrder = order
		l.Parent = statBar
		return l
	end
	ui.coins = stat(1)
	ui.rep = stat(2)
	ui.level = stat(3)

	-- Order banner (top-center)
	ui.orderBanner = Instance.new("TextLabel")
	ui.orderBanner.Size = UDim2.fromOffset(260, 40)
	ui.orderBanner.Position = UDim2.new(0.5, -130, 0, 12)
	ui.orderBanner.BackgroundColor3 = TERRA
	ui.orderBanner.TextColor3 = Color3.fromRGB(255, 250, 242)
	ui.orderBanner.Font = Enum.Font.GothamBold
	ui.orderBanner.TextSize = 18
	ui.orderBanner.Text = ""
	ui.orderBanner.Visible = false
	corner(12).Parent = ui.orderBanner
	ui.orderBanner.Parent = gui

	-- Toast (below banner)
	ui.toast = Instance.new("TextLabel")
	ui.toast.Size = UDim2.fromOffset(280, 34)
	ui.toast.Position = UDim2.new(0.5, -140, 0, 58)
	ui.toast.BackgroundColor3 = DARK
	ui.toast.BackgroundTransparency = 0.1
	ui.toast.TextColor3 = Color3.fromRGB(255, 246, 232)
	ui.toast.Font = Enum.Font.GothamMedium
	ui.toast.TextSize = 16
	ui.toast.Text = ""
	ui.toast.Visible = false
	corner(10).Parent = ui.toast
	ui.toast.Parent = gui

	-- Serve button (big, bottom-center)
	ui.serve = Instance.new("TextButton")
	ui.serve.Size = UDim2.fromOffset(220, 64)
	ui.serve.Position = UDim2.new(0.5, -110, 1, -88)
	ui.serve.BackgroundColor3 = Color3.fromRGB(90, 165, 95)
	ui.serve.TextColor3 = Color3.fromRGB(255, 250, 242)
	ui.serve.Font = Enum.Font.GothamBold
	ui.serve.TextSize = 24
	ui.serve.Text = "Serve ☕"
	ui.serve.Visible = false
	corner(16).Parent = ui.serve
	ui.serve.Parent = gui
	ui.serve.Activated:Connect(function()
		if currentOrderId then
			Remotes.event("ClaimOrder"):FireServer(currentOrderId, false)
		end
	end)

	-- Action bar (bottom-right): Build + Shop
	local actionBar = Instance.new("Frame")
	actionBar.Size = UDim2.fromOffset(132, 120)
	actionBar.Position = UDim2.new(1, -144, 1, -132)
	actionBar.BackgroundTransparency = 1
	actionBar.Parent = gui
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.Padding = UDim.new(0, 8)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionBar

	local buildBtn = makeActionButton("🔨 Build", TERRA, 1)
	buildBtn.Parent = actionBar
	buildBtn.Activated:Connect(function()
		if UIController.onBuildToggle then
			UIController.onBuildToggle()
		end
	end)

	local shopBtn = makeActionButton("🛒 Shop", Color3.fromRGB(120, 95, 160), 2)
	shopBtn.Parent = actionBar
	shopBtn.Activated:Connect(function()
		ui.shopPanel.Visible = not ui.shopPanel.Visible
	end)

	buildShop(gui)

	-- Wire remotes
	Remotes.event("ProfileUpdated").OnClientEvent:Connect(setProfile)
	Remotes.event("OrderCreated").OnClientEvent:Connect(showOrder)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		if msg.kind == "served" then
			clearOrder()
			UIController.toast("+" .. tostring(msg.coins) .. " 🪙")
		elseif msg.kind == "purchased" then
			UIController.toast("Bought — open 🔨 Build to place it")
		elseif msg.kind == "order_cancelled" then
			clearOrder()
			UIController.toast("The customer left 😞")
		elseif msg.kind == "error" then
			UIController.toast(FRIENDLY_ERROR[msg.reason] or tostring(msg.reason))
		end
	end)

	-- Pull the initial snapshot in case ProfileUpdated fired before we connected.
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return Remotes.func("RequestProfile"):InvokeServer()
		end)
		if ok and snapshot then
			setProfile(snapshot)
		end
	end)
end

return UIController
