--!strict
-- The UPGRADES panel (docs/MONETISATION.md). P4 folded the old separate "Store"
-- rail button in here, so the coin-bought batch-output ladder and the Robux
-- catalogue sit in ONE place — a player sees both ways to get the same thing
-- side by side, which is the honest presentation of the rails.
--
-- Layout: the batch-output tiers first (each card carries a coin button and, once
-- the owner creates the products, a Robux button), then the dev products and
-- passes. Robux buttons fire Roblox's NATIVE purchase prompt (which shows the
-- product's real uploaded art + price); every reward is granted server-side by
-- MonetizationService — this panel only asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Remotes = require(Shared.Network.Remotes)

local World = require(Shared.Config.World)
local Grid = require(Shared.Utilities.Grid)
local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local StylePreview = require(script.Parent.Parent.UI.StylePreview)
local UIController = require(script.Parent.UIController)

local RobuxShopController = {}
RobuxShopController.Name = "RobuxShopController"

local player = Players.LocalPlayer
local ui: { [string]: any } = {}

local function infoFor(id: number, pass: boolean): any
	return if pass then Products.passes[id] else Products.developerProducts[id]
end

-- Stock packs (P4, reworked 2026-08-01): CONSUMABLE restocks, shown first with
-- BOTH prices on the same card. Side-by-side is the point — Robux skips the
-- grind, it never buys something coins cannot.
--
-- There is no owned/in-use state: a pack is meant to be bought again whenever
-- your shelves run down.
local function buildStockPackSection(parent: ScrollingFrame)
	local heading = Components.Label(parent, "STOCK PACKS", 12, true)
	heading.Size = UDim2.new(1, -6, 0, 22)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Theme.Colors.Muted
	heading.LayoutOrder = -100
	heading.ZIndex = 22

	for index, row in Products.stockPacks do
		local card = Instance.new("Frame")
		card.Name = "stockpack_" .. row.amount
		card.Size = UDim2.new(1, -6, 0, 88)
		card.BackgroundColor3 = Theme.Colors.Paper
		card.LayoutOrder = -100 + index
		card.ZIndex = 22
		Components.Corner(card, Theme.Radius.Medium)
		Components.Stroke(card, Theme.Colors.Line, 1, 0.3)
		card.Parent = parent

		local thumb = Components.ItemThumbnail(card, {
			glyph = row.icon,
			size = 60,
			accent = Theme.Colors.Honey,
		})
		thumb.root.Position = UDim2.fromOffset(12, 14)
		thumb.root.ZIndex = 23

		local title = Components.Label(card, row.name, 15, true)
		title.Size = UDim2.new(1, -230, 0, 22)
		title.Position = UDim2.fromOffset(84, 14)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Theme.Colors.Ink
		title.ZIndex = 23

		local blurb = Components.Label(card, row.blurb, 11, false)
		blurb.Size = UDim2.new(1, -230, 0, 34)
		blurb.Position = UDim2.fromOffset(84, 38)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		blurb.TextWrapped = true
		blurb.TextColor3 = Theme.Colors.Muted
		blurb.ZIndex = 23

		-- Coins first: it is the path that exists for everyone.
		local coinButton = Components.Button(
			card,
			string.format("%d coins", row.coinCost),
			Theme.Colors.Honey,
			UDim2.fromOffset(120, 30)
		)
		coinButton.Position = UDim2.new(1, -132, 0.5, -34)
		coinButton.TextSize = 14
		coinButton.ZIndex = 23
		local amount = row.amount
		coinButton.Activated:Connect(function()
			Remotes.event("BuyStockPack"):FireServer({ amount = amount })
		end)

		local robux = Components.Button(
			card,
			string.format("R$ %d", row.robuxPrice),
			Theme.Colors.MintDark,
			UDim2.fromOffset(120, 30)
		)
		robux.Position = UDim2.new(1, -132, 0.5, 2)
		robux.TextColor3 = Theme.Colors.White
		robux.TextSize = 14
		robux.ZIndex = 23
		local pid = row.productId
		robux.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, pid)
		end)
	end
end

-- ————— café expansion (economy fix #7) —————
--
-- A drawn front elevation of the café that gets visibly WIDER at each tier, so
-- the upgrade reads as "my building grows" rather than as a number. Drawn from
-- Frames rather than an image: no asset to license, and it recolours with the
-- theme. `pieces` is the tile count the tier unlocks — the concrete thing the
-- owner is buying, shown next to every row.
local function drawHouse(parent: Instance, size: number, fill: number, tone: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Name = "HouseIcon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local w = math.floor(size * (0.42 + 0.5 * fill)) -- wider each tier
	local h = math.floor(size * 0.52)
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.new(0.5, 0, 1, -math.floor(size * 0.08))
	body.Size = UDim2.fromOffset(w, h)
	body.BackgroundColor3 = Theme.Colors.Cream
	body.BorderSizePixel = 0
	Components.Corner(body, 3)
	body.Parent = holder

	local roof = Instance.new("Frame")
	roof.AnchorPoint = Vector2.new(0.5, 1)
	roof.Position = UDim2.new(0.5, 0, 1, -h - math.floor(size * 0.08))
	roof.Size = UDim2.fromOffset(w + math.floor(size * 0.12), math.floor(size * 0.16))
	roof.BackgroundColor3 = tone
	roof.BorderSizePixel = 0
	Components.Corner(roof, 3)
	roof.Parent = holder

	-- One window per unlocked "room": the growth is countable, not just wider.
	local windows = 1 + math.floor(fill * 3 + 0.001)
	for i = 1, windows do
		local pane = Instance.new("Frame")
		pane.AnchorPoint = Vector2.new(0.5, 0)
		pane.Position = UDim2.new(i / (windows + 1), 0, 0, math.floor(size * 0.1))
		pane.Size = UDim2.fromOffset(math.max(3, math.floor(size * 0.1)), math.floor(size * 0.13))
		pane.BackgroundColor3 = tone
		pane.BorderSizePixel = 0
		Components.Corner(pane, 2)
		pane.Parent = body
	end
	return holder
end

local function tilesFor(tierIndex: number): number
	local cells = World.interiorDepthTiers[math.clamp(tierIndex + 1, 1, #World.interiorDepthTiers)]
	return Grid.PLOT_WIDTH * cells
end

local function buildExpansionRows(list: Instance, profile: any, order: number)
	local tier = math.max(0, math.floor(tonumber(profile and profile.expansionTier) or 0))
	local coins = tonumber(profile and profile.coins) or 0
	local last = #World.interiorDepthTiers - 1

	for target = 1, last do
		local row = Instance.new("Frame")
		row.Name = "Expansion" .. target
		row.Size = UDim2.new(1, 0, 0, 74)
		row.BackgroundColor3 = Theme.Colors.Paper
		row.BackgroundTransparency = 0.06
		row.LayoutOrder = order + target
		Components.Corner(row, Theme.Radius.Medium)
		Components.Stroke(row, Theme.Colors.Line, 1, 0.4)
		row.Parent = list

		local owned = tier >= target
		local icon = drawHouse(row, 58, target / last, Theme.Colors.Honey)
		icon.Position = UDim2.fromOffset(8, 8)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(74, 8)
		title.Size = UDim2.new(1, -190, 0, 22)
		title.Font = Theme.Font.Bold
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Theme.Colors.Ink
		title.Text = "Bigger Café " .. string.rep("+", target)
		title.Parent = row

		-- The concrete thing being bought: how many more floor tiles you get.
		local before, after = tilesFor(target - 1), tilesFor(target)
		local detail = Instance.new("TextLabel")
		detail.BackgroundTransparency = 1
		detail.Position = UDim2.fromOffset(74, 30)
		detail.Size = UDim2.new(1, -190, 0, 36)
		detail.Font = Theme.Font.Regular
		detail.TextSize = 12
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextYAlignment = Enum.TextYAlignment.Top
		detail.TextWrapped = true
		detail.TextColor3 = Theme.Colors.Muted
		detail.Text = string.format(
			"%d → %d floor pieces  (+%d)  ·  pushes the back wall into the garden",
			before,
			after,
			after - before
		)
		detail.Parent = row

		local cost = World.expansionCosts[target] or 0
		if owned then
			local done = Instance.new("TextLabel")
			done.BackgroundTransparency = 1
			done.AnchorPoint = Vector2.new(1, 0.5)
			done.Position = UDim2.new(1, -12, 0.5, 0)
			done.Size = UDim2.fromOffset(96, 30)
			done.Font = Theme.Font.Bold
			done.TextSize = 13
			done.TextColor3 = Theme.Colors.Mint
			done.Text = "OWNED"
			done.Parent = row
		else
			local locked = tier < target - 1
			local affordable = not locked and coins >= cost
			local buy = Components.Button(
				row,
				if locked then "LOCKED" else "BUY",
				if affordable then Theme.Colors.Mint else Theme.Colors.Muted,
				UDim2.fromOffset(104, 34)
			)
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -12, 0.5, 0)
			buy.AutoButtonColor = affordable
			buy.ZIndex = 23
			buy.Activated:Connect(function()
				if not locked then
					Remotes.event("BuyExpansion"):FireServer()
				end
			end)
			if not locked then
				StylePreview.priceChip(row, cost).Position = UDim2.new(1, -120, 0.5, -10)
			end
		end
	end
end

local function rebuild()
	local profile = UIController.getProfile()
	if not ui.list then
		return
	end
	ui.list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list

	local owned = (profile and profile.ownedPasses) or {}
	buildStockPackSection(ui.list)
	buildExpansionRows(ui.list, profile, 50)

	for order, ref in Products.order do
		local info = infoFor(ref.id, ref.pass)
		if not info then
			continue
		end
		local isOwnedPass = ref.pass and owned[info.pass] == true

		local card = Instance.new("Frame")
		card.Name = info.key
		card.Size = UDim2.new(1, -6, 0, 88)
		card.BackgroundColor3 = Theme.Colors.Paper
		card.LayoutOrder = order
		card.ZIndex = 22
		Components.Corner(card, Theme.Radius.Medium)
		Components.Stroke(
			card,
			if ref.pass then Theme.Colors.Honey else Theme.Colors.Line,
			1,
			if ref.pass then 0.1 else 0.4
		)
		card.Parent = ui.list

		local thumb = Components.ItemThumbnail(card, {
			glyph = info.icon,
			size = 60,
			accent = if ref.pass then Theme.Colors.Honey else Theme.Colors.Blue,
		})
		thumb.root.Position = UDim2.fromOffset(12, 14)
		thumb.root.ZIndex = 23

		local title = Components.Label(card, info.name, 15, true)
		title.Size = UDim2.new(1, -230, 0, 22)
		title.Position = UDim2.fromOffset(84, 14)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextColor3 = Theme.Colors.Ink
		title.ZIndex = 23

		local blurb = Components.Label(card, info.blurb, 11, false)
		blurb.Size = UDim2.new(1, -230, 0, 34)
		blurb.Position = UDim2.fromOffset(84, 38)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		blurb.TextWrapped = true
		blurb.TextColor3 = Theme.Colors.Muted
		blurb.ZIndex = 23

		if isOwnedPass then
			local ownedChip = Components.Label(card, "OWNED", 13, true)
			ownedChip.Size = UDim2.fromOffset(120, 44)
			ownedChip.Position = UDim2.new(1, -132, 0.5, -22)
			ownedChip.BackgroundTransparency = 0
			ownedChip.BackgroundColor3 = Theme.Colors.Mint
			ownedChip.TextColor3 = Theme.Colors.White
			ownedChip.ZIndex = 23
			Components.Corner(ownedChip, Theme.Radius.Pill)
		else
			local buy = Components.Button(
				card,
				string.format("R$ %d", info.price),
				Theme.Colors.MintDark,
				UDim2.fromOffset(120, 44)
			)
			buy.Position = UDim2.new(1, -132, 0.5, -22)
			buy.TextColor3 = Theme.Colors.White
			buy.TextSize = 15
			buy.ZIndex = 23
			local id = info.id
			local isPass = ref.pass
			buy.Activated:Connect(function()
				if isPass then
					MarketplaceService:PromptGamePassPurchase(player, id)
				else
					MarketplaceService:PromptProductPurchase(player, id)
				end
			end)
		end
	end
end

local function applyResponsive(mode: string, viewport: Vector2)
	local panel = ui.panel
	if not panel then
		return
	end
	ResponsiveLayout.dockPanel(panel, mode, viewport, {
		side = "right",
		desktopWidth = 560,
		desktopHeight = 580,
		compactFraction = 0.48,
		compactMin = 380,
		compactMax = 440,
		phoneHeightScale = 0.74,
	})
end

function RobuxShopController.Start(_self: any)
	local panel = Components.Panel(UIController.modalRoot(), "UpgradesPanel")
	panel.Size = UDim2.fromOffset(560, 580)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"UPGRADES",
		"Batch output, boosts & VIP — everything's also earnable with coins",
		Theme.Colors.Honey
	)
	close.Activated:Connect(function()
		UIController.closePanel(panel)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -80)
	list.Position = UDim2.fromOffset(10, 72)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Honey
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	ui.list = list
	ui.panel = panel

	UIController.registerAction("Upgrades", function()
		UIController.togglePanel(panel)
		if panel.Visible then
			rebuild()
		end
	end)
	UIController.bindActionPanel("Upgrades", panel)
	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)
	ResponsiveLayout.watch(applyResponsive)
end

return RobuxShopController
