--!strict
-- The Staff panel (docs/GAMEPLAY_DIRECTION.md §1). One card per role: your café
-- opens with Mia (Barista) + Noah (Waiter); Sam (Cook) and Pia (Cleaner) start
-- LOCKED and are hired for coins. Each hired staffer has an upgrade track that
-- raises their work-minutes-per-hour (the more you invest, the more they make).
-- Server-authoritative: the buttons only REQUEST hire/upgrade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Staff = require(Shared.Config.Staff)
local KitchenConfig = require(Shared.Config.Kitchen)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local StaffController = {}
StaffController.Name = "StaffController"

local ui: { [string]: any } = {}

-- Fixed display order: the two starters first, then the hireable roles.
local ROSTER = { "barista_mia", "waiter_noah", "cook_sam", "cleaner_pia" }
local ROLE_GLYPH: { [string]: string } = {
	Barista = "☕",
	Waiter = "🍽",
	Cook = "🍳",
	Cleaner = "🧹",
}

local function findMember(profile: any, typeId: string): any
	for _, m in profile.staff or {} do
		if m.typeId == typeId then
			return m
		end
	end
	return nil
end

local function workMinutes(level: number): number
	return KitchenConfig.workMinutesBase + (level - 1) * KitchenConfig.workMinutesPerLevel
end

local function rebuild()
	local profile = UIController.getProfile()
	if not profile or not ui.list then
		return
	end
	ui.list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.list

	for order, typeId in ROSTER do
		local def = Staff[typeId]
		local member = findMember(profile, typeId)
		local hired = member ~= nil and member.hired ~= false
		local level = if member then math.max(1, math.floor(tonumber(member.level) or 1)) else 1

		local card = Instance.new("Frame")
		card.Name = typeId
		card.Size = UDim2.new(1, -6, 0, 116)
		card.BackgroundColor3 = if hired then Theme.Colors.Paper else Color3.fromRGB(78, 65, 61)
		card.LayoutOrder = order
		card.ZIndex = 22
		Components.Corner(card, Theme.Radius.Medium)
		Components.Stroke(card, if hired then Theme.Colors.Line else Theme.Colors.Roast, 1, 0.25)
		card.Parent = ui.list

		local accent = Theme.Colors.Blue
		local thumb = Components.ItemThumbnail(card, {
			glyph = ROLE_GLYPH[def.role] or "?",
			size = 64,
			accent = accent,
			locked = not hired,
			lockLabel = "$" .. tostring(def.hireCost),
		})
		thumb.root.Position = UDim2.fromOffset(12, 12)
		thumb.root.ZIndex = 23

		local title = Components.Label(card, def.displayName .. "  ·  " .. def.role, 15, true)
		title.Size = UDim2.new(1, -96, 0, 22)
		title.Position = UDim2.fromOffset(88, 10)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = if hired then Theme.Colors.Ink else Theme.Colors.Cream
		title.ZIndex = 23

		local blurb = Components.Label(card, def.blurb, 11, false)
		blurb.Size = UDim2.new(1, -96, 0, 18)
		blurb.Position = UDim2.fromOffset(88, 32)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextColor3 = if hired then Theme.Colors.Muted else Theme.Colors.PaperDark
		blurb.ZIndex = 23

		if not hired then
			-- Locked: a single Hire button spanning the bottom.
			local cost = def.hireCost
			local afford = (tonumber(profile.coins) or 0) >= cost
			local hire = Components.Button(
				card,
				string.format("HIRE  ·  $%d", cost),
				if afford then Theme.Colors.Mint else Theme.Colors.PaperDark,
				UDim2.new(1, -100, 0, 40)
			)
			hire.Position = UDim2.fromOffset(88, 62)
			hire.TextColor3 = if afford then Theme.Colors.White else Theme.Colors.Muted
			hire.TextSize = 14
			hire.ZIndex = 23
			hire.Activated:Connect(function()
				Remotes.event("HireStaff"):FireServer(typeId)
			end)
		else
			-- Hired: the upgrade track (level bar + min/hr + upgrade button).
			local maxLevel = def.maxLevel
			local atMax = level >= maxLevel
			local minsNow = workMinutes(level)

			local info = Components.Label(
				card,
				string.format("Lv %d/%d  ·  %d min/hr output", level, maxLevel, minsNow),
				12,
				true
			)
			info.Size = UDim2.new(1, -96, 0, 18)
			info.Position = UDim2.fromOffset(88, 52)
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.TextColor3 = Theme.Colors.MintDark
			info.ZIndex = 23

			-- Progress bar (level / maxLevel).
			local barBack = Instance.new("Frame")
			barBack.Size = UDim2.new(1, -232, 0, 12)
			barBack.Position = UDim2.fromOffset(88, 74)
			barBack.BackgroundColor3 = Theme.Colors.PaperDark
			barBack.ZIndex = 23
			Components.Corner(barBack, Theme.Radius.Pill)
			barBack.Parent = card
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(level / maxLevel, 1)
			fill.BackgroundColor3 = Theme.Colors.Honey
			fill.ZIndex = 24
			Components.Corner(fill, Theme.Radius.Pill)
			fill.Parent = barBack

			local cost = Economy.staffUpgradeCostBase * level
			local afford = (tonumber(profile.coins) or 0) >= cost
			local btn = Components.Button(
				card,
				if atMax then "MAX" else string.format("UPGRADE\n$%d", cost),
				if atMax
					then Theme.Colors.Honey
					elseif afford then Theme.Colors.Coral
					else Theme.Colors.PaperDark,
				UDim2.new(0, 130, 0, 46)
			)
			btn.Position = UDim2.new(1, -142, 0, 60)
			btn.TextColor3 = if atMax or afford then Theme.Colors.White else Theme.Colors.Muted
			btn.TextSize = 12
			btn.ZIndex = 23
			if not atMax then
				btn.Activated:Connect(function()
					Remotes.event("UpgradeStaff"):FireServer(member.id)
				end)
			end
		end
	end
end

local function applyResponsive(mode: string, viewport: Vector2)
	local panel = ui.panel
	if not panel then
		return
	end
	if mode == "Phone" then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -8)
		panel.Size = UDim2.new(1, -16, 0.74, 0)
	elseif mode == "Compact" then
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -8, 0.5, 0)
		panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.46, 360, 420), viewport.Y - 16)
	else
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(520, 560)
	end
end

function StaffController.Start(_self: any)
	local panel = Components.Panel(UIController.modalRoot(), "StaffPanel")
	panel.Size = UDim2.fromOffset(520, 560)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"STAFF",
		"Hire your crew and upgrade what they make per hour",
		Theme.Colors.Blue
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
	list.ScrollBarImageColor3 = Theme.Colors.Blue
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	ui.list = list
	ui.panel = panel

	UIController.registerAction("Staff", function()
		UIController.togglePanel(panel)
		if panel.Visible then
			rebuild()
		end
	end)
	UIController.bindActionPanel("Staff", panel)
	UIController.subscribeProfile(function()
		if panel.Visible then
			rebuild()
		end
	end)
	ResponsiveLayout.watch(applyResponsive)
end

return StaffController
