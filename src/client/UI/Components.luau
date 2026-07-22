--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Graphics = require(ReplicatedStorage.Shared.Config.Graphics)
local Theme = require(script.Parent.Theme)

local Components = {}

function Components.Corner(parent: Instance, radius: number?): UICorner
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius or Theme.Radius.Medium)
	value.Parent = parent
	return value
end

function Components.Stroke(
	parent: Instance,
	color: Color3?,
	thickness: number?,
	transparency: number?
): UIStroke
	local value = Instance.new("UIStroke")
	value.Color = color or Theme.Colors.Line
	value.Thickness = thickness or 1
	value.Transparency = transparency or 0
	value.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	value.Parent = parent
	return value
end

function Components.Padding(parent: Instance, x: number, y: number?): UIPadding
	local value = Instance.new("UIPadding")
	value.PaddingLeft = UDim.new(0, x)
	value.PaddingRight = UDim.new(0, x)
	value.PaddingTop = UDim.new(0, y or x)
	value.PaddingBottom = UDim.new(0, y or x)
	value.Parent = parent
	return value
end

function Components.Gradient(
	parent: Instance,
	startColor: Color3,
	endColor: Color3,
	rotation: number?
): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(startColor, endColor)
	gradient.Rotation = rotation or 0
	gradient.Parent = parent
	return gradient
end

function Components.Label(parent: Instance, text: string, size: number, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if bold then Theme.Font.Bold else Theme.Font.Medium
	label.TextSize = size
	label.TextColor3 = Theme.Colors.Ink
	label.Text = text
	label.Parent = parent
	return label
end

local function glyphBadge(parent: Instance, glyph: string, color: Color3?, px: number): Frame
	local badge = Instance.new("Frame")
	badge.Name = "IconFallback"
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = color or Theme.Colors.Honey
	Components.Corner(badge, math.floor(px / 2))
	Components.Gradient(
		badge,
		(color or Theme.Colors.Honey):Lerp(Theme.Colors.White, 0.22),
		color or Theme.Colors.Honey,
		90
	)
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(0.38, 0.16)
	shine.Position = UDim2.fromScale(0.18, 0.17)
	shine.BackgroundColor3 = Theme.Colors.White
	shine.BackgroundTransparency = 0.45
	Components.Corner(shine, 99)
	shine.Parent = badge
	local text = Components.Label(badge, glyph, math.max(9, math.floor(px * 0.34)), true)
	text.Size = UDim2.fromScale(1, 1)
	text.TextColor3 = Theme.Colors.White
	text.ZIndex = badge.ZIndex + 1
	badge.Parent = parent
	return badge
end

-- Returns a fixed-size slot holding either the image or the code-drawn glyph
-- badge. If an image id is present but Roblox never loads it (moderated,
-- restricted, deleted), the slot swaps to the glyph badge, so the HUD never
-- renders a blank square.
function Components.Icon(
	parent: Instance,
	glyph: string,
	image: string?,
	color: Color3?,
	size: number?,
	imageTint: Color3?
): GuiObject
	local px = size or 28
	local slot = Instance.new("Frame")
	slot.Name = "Icon"
	slot.Size = UDim2.fromOffset(px, px)
	slot.BackgroundTransparency = 1
	slot.Parent = parent
	if image and image ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Image"
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.Image = image
		icon.ScaleType = Enum.ScaleType.Fit
		if imageTint then
			icon.ImageColor3 = imageTint
		end
		icon.Parent = slot
		-- Cover a slow image with the glyph badge rather than replacing it: a
		-- cold content queue can take far longer than this on join, and an
		-- image that eventually arrives should still be the one you see.
		task.delay(6, function()
			if icon.Parent ~= slot or icon.IsLoaded then
				return
			end
			local badge = glyphBadge(slot, glyph, color, px)
			icon.Visible = false
			icon:GetPropertyChangedSignal("IsLoaded"):Once(function()
				if icon.IsLoaded then
					badge:Destroy()
					icon.Visible = true
				end
			end)
		end)
	else
		glyphBadge(slot, glyph, color, px)
	end
	return slot
end

function Components.Button(
	parent: Instance,
	text: string,
	color: Color3,
	size: UDim2?,
	glyph: string?,
	image: string?
): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Size = size or UDim2.fromOffset(120, 44)
	button.BackgroundColor3 = color
	button.TextColor3 = Theme.Colors.White
	button.Font = Theme.Font.Bold
	button.TextSize = 14
	local hasImage = image ~= nil and image ~= ""
	button.Text = if hasImage then text elseif glyph then glyph .. "  " .. text else text
	button.Parent = parent
	Components.Corner(button, Theme.Radius.Medium)
	Components.Stroke(button, color:Lerp(Theme.Colors.Espresso, 0.25), 1, 0.2)
	if hasImage then
		local icon = Instance.new("ImageLabel")
		icon.Name = "ButtonIcon"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Position = if text == "" then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 17, 0.5, 0)
		icon.BackgroundTransparency = 1
		icon.Image = image :: string
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = button.ZIndex + 1
		icon.Parent = button
		if text ~= "" then
			button.TextXAlignment = Enum.TextXAlignment.Left
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 30)
			padding.PaddingRight = UDim.new(0, 4)
			padding.Parent = button
		end
	end
	button.MouseEnter:Connect(function()
		TweenService:Create(button, Theme.Motion.Fast, {
			BackgroundColor3 = color:Lerp(Theme.Colors.White, 0.1),
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, Theme.Motion.Fast, { BackgroundColor3 = color }):Play()
	end)
	return button
end

function Components.Panel(parent: Instance, name: string, color: Color3?): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = color or Theme.Colors.Cream
	panel.ZIndex = 20
	-- Sink clicks: an open panel covers HUD buttons, and without this a tap on
	-- panel dead space falls through to whatever it is hiding.
	panel.Active = true
	Components.Corner(panel, Theme.Radius.Large)
	Components.Stroke(panel, Theme.Colors.Line, 2, 0.12)
	panel.Parent = parent
	local shadow = Instance.new("Frame")
	shadow.Name = name .. "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundColor3 = Theme.Colors.Espresso
	shadow.BackgroundTransparency = 0.58
	shadow.Position = UDim2.new(0.5, 5, 0.5, 7)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = panel.ZIndex - 1
	shadow.Active = true
	Components.Corner(shadow, Theme.Radius.Large)
	shadow.Parent = panel
	shadow.Visible = panel.Visible
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = panel.Visible
	end)
	return panel
end

function Components.PanelHeader(
	panel: Frame,
	titleText: string,
	subtitleText: string?,
	accent: Color3?
): (Frame, TextButton)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, if subtitleText then 64 else 50)
	header.BackgroundColor3 = accent or Theme.Colors.Coral
	header.ZIndex = panel.ZIndex + 1
	Components.Corner(header, Theme.Radius.Large)
	header.Parent = panel
	local squareOff = Instance.new("Frame")
	squareOff.Size = UDim2.new(1, 0, 0, Theme.Radius.Large)
	squareOff.Position = UDim2.new(0, 0, 1, -Theme.Radius.Large)
	squareOff.BackgroundColor3 = header.BackgroundColor3
	squareOff.BorderSizePixel = 0
	squareOff.ZIndex = header.ZIndex
	squareOff.Parent = header

	local title = Components.Label(header, titleText, 20, true)
	title.Size = UDim2.new(1, -62, 0, 30)
	title.Position = UDim2.fromOffset(16, 6)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.White
	title.ZIndex = header.ZIndex + 1
	if subtitleText then
		local subtitle = Components.Label(header, subtitleText, 11, false)
		subtitle.Size = UDim2.new(1, -62, 0, 18)
		subtitle.Position = UDim2.fromOffset(16, 34)
		subtitle.TextXAlignment = Enum.TextXAlignment.Left
		subtitle.TextColor3 = Theme.Colors.Cream
		subtitle.ZIndex = header.ZIndex + 1
	end
	local close = Components.Button(
		header,
		Theme.Glyphs.Close,
		Theme.Colors.CoralDark,
		UDim2.fromOffset(40, 40)
	)
	close.Position = UDim2.new(1, -48, 0, 7)
	close.TextSize = 15
	close.ZIndex = header.ZIndex + 2
	return header, close
end

function Components.SetPanelVisible(panel: Frame, visible: boolean)
	if visible then
		panel.Visible = true
		local target = panel.Size
		panel.Size = UDim2.new(
			target.X.Scale,
			math.floor(target.X.Offset * 0.96),
			target.Y.Scale,
			math.floor(target.Y.Offset * 0.96)
		)
		TweenService:Create(panel, Theme.Motion.Panel, { Size = target }):Play()
	else
		panel.Visible = false
	end
end

export type ItemThumbnailOpts = {
	-- An explicit image wins over assetId: dishes ship their own uploaded icon,
	-- while furniture is rendered on demand from its Creator Store model.
	image: string?,
	assetId: number?,
	size: number,
	-- Shown instead of a picture when the item has no Creator Store asset.
	glyph: string,
	accent: Color3,
	locked: boolean?,
	lockLabel: string?,
}

export type ItemThumbnailHandle = {
	root: Frame,
	setLocked: (locked: boolean, lockLabel: string?) -> (),
}

-- A catalogue row's picture of the actual item. Roblox renders a preview of any
-- Creator Store asset, so this is the real model, not a stand-in.
--
-- Locked items show the same picture heavily blurred. Roblox has no GUI blur
-- and rbxthumb serves only 150px and 420px (verified live - every other size
-- returns a blank image), so there is no small source to upscale; the blur is
-- composited by drawing the picture many times at small offsets.
function Components.ItemThumbnail(parent: Instance, opts: ItemThumbnailOpts): ItemThumbnailHandle
	local spec = Theme.Thumbnail
	local px = opts.size
	local image = if opts.image and opts.image ~= ""
		then opts.image
		elseif opts.assetId and opts.assetId > 0 then Graphics.ItemThumbnail(opts.assetId)
		else nil

	local root = Instance.new("Frame")
	root.Name = "Thumbnail"
	root.Size = UDim2.fromOffset(px, px)
	root.BackgroundColor3 = spec.Plate
	root.ClipsDescendants = true
	Components.Corner(root, Theme.Radius.Medium)
	Components.Stroke(root, Theme.Colors.Line, 1, 0.55)
	root.Parent = parent

	local picture: ImageLabel? = nil
	if image then
		local label = Instance.new("ImageLabel")
		label.Name = "Picture"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.ScaleType = Enum.ScaleType.Fit
		label.Image = image
		label.Parent = root
		picture = label
	else
		-- No asset for this item: fall back to the code-drawn glyph badge so the
		-- row is never empty.
		local badge = Components.Icon(root, opts.glyph, nil, opts.accent, px - 10)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.5, 0.5)
	end

	local overlay: Frame? = nil

	local function clearOverlay()
		if overlay then
			overlay:Destroy()
			overlay = nil
		end
		if picture then
			picture.Visible = true
		end
	end

	local function buildOverlay(lockLabel: string?)
		local holder = Instance.new("Frame")
		holder.Name = "Locked"
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.ZIndex = root.ZIndex + 1
		holder.Parent = root

		if picture and image then
			picture.Visible = false
			local blur = spec.Blur
			for sample = 1, blur.Samples do
				local angle = (sample / blur.Samples) * math.pi * 2
				-- Two rings read smoother than one at the same instance count.
				local reach = if sample % 2 == 0 then blur.Radius else blur.Radius * 0.5
				local copy = Instance.new("ImageLabel")
				copy.Size = UDim2.fromScale(1, 1)
				copy.Position = UDim2.fromOffset(
					math.floor(math.cos(angle) * reach),
					math.floor(math.sin(angle) * reach)
				)
				copy.BackgroundTransparency = 1
				copy.ScaleType = Enum.ScaleType.Fit
				copy.Image = image
				copy.ImageTransparency = blur.Transparency
				copy.ZIndex = holder.ZIndex
				copy.Parent = holder
			end
		end

		local veil = Instance.new("Frame")
		veil.Name = "Veil"
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = spec.VeilColor
		veil.BackgroundTransparency = spec.VeilTransparency
		veil.ZIndex = holder.ZIndex + 1
		veil.Parent = holder

		if lockLabel and lockLabel ~= "" then
			local text = Components.Label(holder, lockLabel, spec.LockTextSize, true)
			text.Size = UDim2.fromScale(1, 1)
			text.TextColor3 = Theme.Colors.Cream
			text.ZIndex = holder.ZIndex + 2
		end
		overlay = holder
	end

	local function setLocked(locked: boolean, lockLabel: string?)
		clearOverlay()
		if locked then
			buildOverlay(lockLabel)
		end
	end

	if opts.locked then
		buildOverlay(opts.lockLabel)
	end

	return { root = root, setLocked = setLocked }
end

export type IconButtonOpts = {
	name: string,
	glyph: string,
	icon: string?,
	accent: Color3,
	size: number,
	shape: "Square" | "Round",
	badge: string?,
	badgePlacement: ("Corner" | "Beside")?,
	-- The icon carries its own colours and must not be tinted.
	fullColour: boolean?,
	labelSide: "Bottom" | "Left",
	alwaysShowLabel: boolean?,
	liftEnabled: boolean?,
	-- A toggle that is usually on (music) should not sit permanently in the
	-- raised hover state that marks an open panel: it reads as tint and stroke
	-- only.
	persistentToggle: boolean?,
	layoutOrder: number?,
}

export type IconButtonHandle = {
	root: Frame,
	button: ImageButton,
	setActive: (active: boolean) -> (),
	setIcon: (image: string?, glyph: string?) -> (),
	isActive: () -> boolean,
}

-- The chunky HUD button (docs/HUD_REDESIGN.md §2b/2c): plate image over a
-- code-drawn rounded gradient (which doubles as the no-image fallback), glyph
-- icon, corner badge, hover lift with a name label, and a press dip that
-- settles back ("pop"). Both the bottom dock and the right rail build from
-- this; every visual constant comes from Theme.Hud.
function Components.IconButton(parent: Instance, opts: IconButtonOpts): IconButtonHandle
	local hud = Theme.Hud
	local size = opts.size
	local round = opts.shape == "Round"
	local lift = opts.liftEnabled ~= false

	local root = Instance.new("Frame")
	root.Name = opts.name .. "Button"
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 1
	root.LayoutOrder = opts.layoutOrder or 0
	root.Parent = parent

	local plate = Instance.new("ImageButton")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromOffset(size, size)
	plate.AutoButtonColor = false
	plate.BackgroundColor3 = hud.PlateTint
	plate.ScaleType = Enum.ScaleType.Fit
	plate.ImageColor3 = hud.PlateTint
	local plateImage = if round then Theme.Images.PlateRound else Theme.Images.PlateSquare
	if plateImage ~= "" then
		plate.Image = plateImage
	end
	Components.Corner(plate, if round then math.floor(size / 2) else Theme.Radius.Large)
	Components.Gradient(plate, hud.PlateTint:Lerp(Theme.Colors.White, 0.35), hud.PlateTint, 90)
	local stroke = Components.Stroke(plate, Theme.Colors.Cream, 2, hud.StrokeTransparency)
	plate.Parent = root

	local scale = Instance.new("UIScale")
	scale.Parent = plate

	local iconPx = math.floor(size * hud.IconRatio)
	-- Full-colour artwork keeps its own palette; only flat glyphs get recoloured.
	local iconTint = if opts.fullColour then nil else hud.IconTint
	local iconSlot = Components.Icon(plate, opts.glyph, opts.icon, opts.accent, iconPx, iconTint)
	iconSlot.AnchorPoint = Vector2.new(0.5, 0.5)
	iconSlot.Position = UDim2.fromScale(0.5, 0.5)
	iconSlot.ZIndex = plate.ZIndex + 1

	-- "Corner" is the dock's numbered badge sitting on the plate; "Beside" is
	-- the rail's tiny key pill parked just outside it (spec §2b vs §2c).
	local beside = opts.badgePlacement == "Beside"
	local badgeSize = if beside then hud.BadgeSizeBeside else hud.BadgeSize
	if opts.badge then
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
		if beside then
			badge.AnchorPoint = Vector2.new(1, 0.5)
			badge.Position = UDim2.new(0, -6, 0.5, 0)
		else
			badge.AnchorPoint = Vector2.new(1, 1)
			badge.Position = UDim2.new(1, 6, 1, 6)
		end
		badge.BackgroundColor3 = opts.accent
		badge.ZIndex = plate.ZIndex + 2
		Components.Corner(badge, Theme.Radius.Pill)
		Components.Stroke(badge, Theme.Colors.Cream, 1, 0.25)
		local badgeText = Components.Label(
			badge,
			opts.badge,
			if beside then hud.BadgeTextSizeBeside else hud.BadgeTextSize,
			true
		)
		badgeText.Size = UDim2.fromScale(1, 1)
		badgeText.TextColor3 = Theme.Colors.White
		badgeText.ZIndex = badge.ZIndex + 1
		badge.Parent = plate
	end

	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, hud.LabelHeight)
	label.BackgroundColor3 = Theme.Colors.Espresso
	label.Font = Theme.Font.Bold
	label.TextSize = if opts.alwaysShowLabel then hud.LabelTextSizeTouch else hud.LabelTextSize
	label.TextColor3 = Theme.Colors.Cream
	label.Text = " " .. opts.name .. " "
	label.ZIndex = plate.ZIndex + 3
	if opts.labelSide == "Left" then
		label.AnchorPoint = Vector2.new(1, 0.5)
		-- Clear the key pill when one is parked on that same side.
		label.Position =
			UDim2.new(0, if beside and opts.badge then -(10 + badgeSize) else -6, 0.5, 0)
	else
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 1, 4)
	end
	Components.Corner(label, Theme.Radius.Pill)
	label.Parent = root
	local shown = opts.alwaysShowLabel == true
	label.BackgroundTransparency = if shown then hud.LabelBackgroundTransparency else 1
	label.TextTransparency = if shown then 0 else 1

	local active = false
	local hovered = false
	local persistent = opts.persistentToggle == true

	-- A persistent toggle shows its on-state through tint and stroke only; the
	-- lift and the pinned name are reserved for "this panel is open".
	local function raised(): boolean
		return hovered or (active and not persistent)
	end

	local function targetScale(): number
		return if lift and raised() then hud.HoverScale else 1
	end

	local function setLabelShown(visible: boolean)
		if opts.alwaysShowLabel then
			return
		end
		TweenService:Create(label, Theme.Motion.Fast, {
			BackgroundTransparency = if visible then hud.LabelBackgroundTransparency else 1,
			TextTransparency = if visible then 0 else 1,
		}):Play()
	end

	local function settle()
		TweenService:Create(scale, Theme.Motion.Settle, { Scale = targetScale() }):Play()
	end

	plate.MouseEnter:Connect(function()
		hovered = true
		TweenService:Create(scale, Theme.Motion.Fast, { Scale = targetScale() }):Play()
		setLabelShown(true)
	end)
	plate.MouseLeave:Connect(function()
		hovered = false
		settle()
		setLabelShown(raised())
	end)
	plate.MouseButton1Down:Connect(function()
		TweenService:Create(scale, Theme.Motion.Fast, { Scale = hud.PressScale }):Play()
	end)
	plate.MouseButton1Up:Connect(settle)

	local function setActive(value: boolean)
		active = value
		settle()
		setLabelShown(raised())
		TweenService:Create(stroke, Theme.Motion.Fast, {
			Color = if active then opts.accent else Theme.Colors.Cream,
			Transparency = if active then hud.StrokeTransparencyActive else hud.StrokeTransparency,
		}):Play()
		TweenService:Create(plate, Theme.Motion.Fast, {
			ImageColor3 = if active then hud.PlateTintActive else hud.PlateTint,
			BackgroundColor3 = if active then hud.PlateTintActive else hud.PlateTint,
		}):Play()
	end

	local function setIcon(image: string?, glyph: string?)
		iconSlot:Destroy()
		iconSlot = Components.Icon(plate, glyph or opts.glyph, image, opts.accent, iconPx, iconTint)
		iconSlot.AnchorPoint = Vector2.new(0.5, 0.5)
		iconSlot.Position = UDim2.fromScale(0.5, 0.5)
		iconSlot.ZIndex = plate.ZIndex + 1
	end

	return {
		root = root,
		button = plate,
		setActive = setActive,
		setIcon = setIcon,
		isActive = function()
			return active
		end,
	}
end

function Components.CategoryGlyph(category: string): string
	return Theme.Glyphs[category] or string.upper(string.sub(category, 1, 2))
end

function Components.CategoryColor(category: string): Color3
	return Theme.CategoryColors[category] or Theme.Colors.Roast
end

return Components
