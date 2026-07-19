--!strict

local TweenService = game:GetService("TweenService")

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

function Components.Icon(
	parent: Instance,
	glyph: string,
	image: string?,
	color: Color3?,
	size: number?
): GuiObject
	local px = size or 28
	if image and image ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.fromOffset(px, px)
		icon.BackgroundTransparency = 1
		icon.Image = image
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = parent
		return icon
	end
	local badge = Instance.new("Frame")
	badge.Name = "IconFallback"
	badge.Size = UDim2.fromOffset(px, px)
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

function Components.CategoryGlyph(category: string): string
	return Theme.Glyphs[category] or string.upper(string.sub(category, 1, 2))
end

function Components.CategoryColor(category: string): Color3
	return Theme.CategoryColors[category] or Theme.Colors.Roast
end

return Components
