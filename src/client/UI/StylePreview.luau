--!strict
-- Live swatches for the customisation pickers (owner feedback 2026-08-01: the
-- menus showed only text, so you could not tell what an option would give you).
--
-- Every preview is DRAWN from the same config the world renderer uses — nested
-- Frames, no images — so a swatch can never drift from what actually gets built,
-- and adding a colour or motif needs no new art. Frames also cost far less than a
-- ViewportFrame per row, which matters on the phone build.

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local StylePreview = {}

local function box(parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = 24
	frame.Parent = parent
	return frame
end

-- The card every preview is drawn inside: a fixed square with the base colour.
local function plate(parent: Instance, side: number, base: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Preview"
	frame.Size = UDim2.fromOffset(side, side)
	frame.BackgroundColor3 = base
	frame.BorderSizePixel = 0
	frame.ZIndex = 23
	frame.ClipsDescendants = true
	Components.Corner(frame, 6)
	Components.Stroke(frame, Theme.Colors.Ink, 1, 0.75)
	frame.Parent = parent
	return frame
end

-- Evenly spaced band centres as a 0..1 fraction, matching the renderer's
-- bandOffsets so the swatch reads like the real thing.
local function fractions(bands: number): { number }
	local out = {}
	for i = 1, bands do
		out[i] = i / (bands + 1)
	end
	return out
end

-- Shared by floor tiles, wall panels and façade motifs: bands over a base.
local function drawMotif(card: Frame, kind: string, bands: number, ink: Color3, lineScale: number)
	local w = lineScale
	if kind == "vertical" or kind == "both" then
		for _, f in fractions(bands) do
			box(card, UDim2.new(w, 0, 1, 0), UDim2.new(f - w / 2, 0, 0, 0), ink)
		end
	end
	if kind == "horizontal" or kind == "both" then
		for _, f in fractions(bands) do
			box(card, UDim2.new(1, 0, w, 0), UDim2.new(0, 0, f - w / 2, 0), ink)
		end
	end
	if kind == "checker" then
		box(card, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0, 0), ink)
		box(card, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), ink)
	end
	if kind == "wainscot" then
		box(card, UDim2.new(1, 0, 0.34, 0), UDim2.new(0, 0, 0.66, 0), ink)
	end
	if kind == "pilaster" then
		box(card, UDim2.new(0.16, 0, 1, 0), UDim2.new(0.04, 0, 0, 0), ink)
		box(card, UDim2.new(0.16, 0, 1, 0), UDim2.new(0.8, 0, 0, 0), ink)
	end
end

-- A floor tile / wall panel: base colour plus its motif.
function StylePreview.surface(parent: Instance, color: any, motif: any, side: number): Frame
	local card = plate(parent, side, color.base)
	drawMotif(card, motif.kind, motif.bands, color.ink, 0.14)
	return card
end

-- A façade wall: the motif, with a DOOR NOTCH cut out of the bottom so the
-- swatch also shows the rule that bands stop at the opening.
function StylePreview.facadeMotif(parent: Instance, color: any, motif: any, side: number): Frame
	local card = plate(parent, side, color.base)
	drawMotif(card, motif.kind, math.min(motif.bands, 4), color.trim, 0.11)
	local door = box(card, UDim2.new(0.26, 0, 0.5, 0), UDim2.new(0.37, 0, 0.5, 0), color.base)
	door.ZIndex = 26
	Components.Stroke(door, color.trim, 1, 0.4)
	return card
end

-- A colour chip: the field with a band of its own trim tone.
function StylePreview.color(parent: Instance, color: any, side: number): Frame
	local card = plate(parent, side, color.base)
	box(card, UDim2.new(1, 0, 0.26, 0), UDim2.new(0, 0, 0.74, 0), color.trim)
	return card
end

-- The three architectures, as a silhouette of their crown.
function StylePreview.architecture(parent: Instance, entry: any, color: any, side: number): Frame
	local card = plate(parent, side, color.base)
	if entry.crown == "awning" then
		for i = 0, 5 do
			box(
				card,
				UDim2.new(1 / 6, 0, 0.3, 0),
				UDim2.new(i / 6, 0, 0.12, 0),
				if i % 2 == 0 then Theme.Colors.Coral else Theme.Colors.Cream
			)
		end
	elseif entry.crown == "gable" then
		-- Stacked shrinking bars read as a pitched roof, the same trick the
		-- renderer uses in the world.
		for i = 0, 4 do
			local t = i / 5
			box(
				card,
				UDim2.new(0.9 * (1 - t), 0, 0.11, 0),
				UDim2.new(0.05 + 0.45 * t, 0, 0.08 + i * 0.11, 0),
				color.trim
			)
		end
	else
		box(card, UDim2.new(1, 0, 0.16, 0), UDim2.new(0, 0, 0.1, 0), color.trim)
		box(card, UDim2.new(0.86, 0, 0.08, 0), UDim2.new(0.07, 0, 0.3, 0), color.trim)
	end
	box(card, UDim2.new(0.3, 0, 0.36, 0), UDim2.new(0.35, 0, 0.64, 0), color.trim)
	return card
end

-- A door: the wood's own grain count and tone, plus the style's panels.
function StylePreview.door(parent: Instance, style: any, wood: any, side: number): Frame
	local card = plate(parent, side, wood.base)
	for _, f in fractions(math.min(wood.lines, 6)) do
		box(card, UDim2.new(0.05, 0, 1, 0), UDim2.new(f - 0.025, 0, 0, 0), wood.grain)
	end
	local inset = wood.grain
	local panels = style.panels
	if panels == "two" then
		box(card, UDim2.new(0.56, 0, 0.28, 0), UDim2.new(0.22, 0, 0.1, 0), inset)
		box(card, UDim2.new(0.56, 0, 0.28, 0), UDim2.new(0.22, 0, 0.58, 0), inset)
	elseif panels == "four" then
		for _, fx in { 0.14, 0.54 } do
			for _, fy in { 0.1, 0.58 } do
				box(card, UDim2.new(0.32, 0, 0.28, 0), UDim2.new(fx, 0, fy, 0), inset)
			end
		end
	elseif panels == "arch" then
		local top = box(card, UDim2.new(0.56, 0, 0.34, 0), UDim2.new(0.22, 0, 0.08, 0), inset)
		Components.Corner(top, 999)
		box(card, UDim2.new(0.56, 0, 0.3, 0), UDim2.new(0.22, 0, 0.56, 0), inset)
	elseif panels == "window" then
		local pane =
			box(card, UDim2.new(0.5, 0, 0.3, 0), UDim2.new(0.25, 0, 0.1, 0), Theme.Colors.Blue)
		pane.BackgroundTransparency = 0.25
	elseif panels == "cross" then
		box(card, UDim2.new(0.86, 0, 0.1, 0), UDim2.new(0.07, 0, 0.45, 0), inset)
		box(card, UDim2.new(0.1, 0, 0.86, 0), UDim2.new(0.45, 0, 0.07, 0), inset)
	end
	return card
end

-- A window: the shape itself, tinted with the current glass.
function StylePreview.window(parent: Instance, shape: any, tint: any, side: number): Frame
	local card = plate(parent, side, Theme.Colors.PaperDark)
	local pane = box(card, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.19, 0.19), tint.color)
	pane.BackgroundTransparency = 0.15
	Components.Stroke(pane, Theme.Colors.Ink, 2, 0.4)
	if shape.shape == "round" then
		Components.Corner(pane, 999)
	elseif shape.shape == "lozenge" then
		pane.Rotation = 45
	end
	return card
end

-- A glass tint on its own, over a light frame.
function StylePreview.glass(parent: Instance, tint: any, side: number): Frame
	local card = plate(parent, side, Theme.Colors.PaperDark)
	local pane = box(card, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.15), tint.color)
	pane.BackgroundTransparency = 0.12
	Components.Stroke(pane, Theme.Colors.Ink, 2, 0.4)
	return card
end

-- A drawn coin. The 🪙 emoji renders as a tofu box in Roblox's UI font (seen in
-- Studio), so the coin is two circles instead — guaranteed to render everywhere,
-- and it matches the procedural art direction.
function StylePreview.coin(parent: Instance, side: number): Frame
	local outer = Instance.new("Frame")
	outer.Name = "Coin"
	outer.Size = UDim2.fromOffset(side, side)
	outer.BackgroundColor3 = Theme.Colors.Honey
	outer.BorderSizePixel = 0
	outer.ZIndex = 25
	Components.Corner(outer, 999)
	Components.Stroke(outer, Color3.fromRGB(150, 106, 34), 1.5, 0)
	outer.Parent = parent

	local inner = Instance.new("Frame")
	inner.Size = UDim2.fromScale(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.25, 0.25)
	inner.BackgroundColor3 = Color3.fromRGB(150, 106, 34)
	inner.BackgroundTransparency = 0.45
	inner.BorderSizePixel = 0
	inner.ZIndex = 26
	Components.Corner(inner, 999)
	inner.Parent = outer
	return outer
end

-- The price chip on every buyable row: a drawn coin plus the number.
function StylePreview.priceChip(parent: Instance, price: number): TextLabel
	local chip = Components.Label(parent, tostring(price), 11, true)
	chip.Name = "PriceChip"
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -8, 0.5, 0)
	chip.Size = UDim2.fromOffset(58, 20)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = Theme.Colors.Cream
	chip.TextColor3 = Theme.Colors.Espresso
	chip.TextXAlignment = Enum.TextXAlignment.Right
	chip.ZIndex = 24
	Components.Corner(chip, Theme.Radius.Pill)
	Components.Padding(chip, 6, 0)

	local coin = StylePreview.coin(chip, 14)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 2, 0.5, 0)
	return chip
end

return StylePreview
