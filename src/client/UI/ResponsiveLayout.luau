--!strict

local Theme = require(script.Parent.Theme)

local ResponsiveLayout = {}

export type Mode = "Phone" | "Compact" | "Desktop"

function ResponsiveLayout.mode(viewport: Vector2?): Mode
	local size = viewport
		or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)
		or Vector2.new(1280, 720)
	-- Social Cafe is landscape-first. A short landscape viewport is compact, not a
	-- portrait phone: treating height alone as "Phone" made every drawer full width.
	if size.X < 600 or (size.X < 700 and size.X < size.Y) then
		return "Phone"
	elseif size.X < 1100 or size.Y < 620 then
		return "Compact"
	end
	return "Desktop"
end

function ResponsiveLayout.isPhone(viewport: Vector2?): boolean
	return ResponsiveLayout.mode(viewport) == "Phone"
end

function ResponsiveLayout.isCompact(viewport: Vector2?): boolean
	return ResponsiveLayout.mode(viewport) ~= "Desktop"
end

-- The always-visible active-stock dock (InventoryController) sits bottom-left.
-- Its footprint is needed by two controllers: InventoryController sizes the
-- dock itself, and UIController must know where its right edge lands so the
-- centre action dock can lift above it instead of overlapping (phones make it
-- nearly full-width). One formula, one place.
function ResponsiveLayout.stockDockSize(mode: Mode, viewport: Vector2): (number, number)
	if mode == "Phone" then
		return math.max(260, viewport.X - 82), Theme.Hud.StockDockHeight.Compact
	elseif mode == "Compact" then
		return math.min(344, viewport.X - 120), Theme.Hud.StockDockHeight.Compact
	end
	return 500, Theme.Hud.StockDockHeight.Desktop
end

-- Every rectangle the HUD occupies, measured once so the five controllers that
-- share the screen agree instead of each guessing (docs/HUD_REDESIGN.md §3
-- "measure, don't eyeball"). Vertical offsets are distances from the BOTTOM
-- screen edge unless the name says FromTop.
export type HudLayout = {
	phoneSized: boolean,
	dockPlate: number,
	dockWidth: number,
	dockBottom: number,
	dockOffsetX: number,
	labelBand: number,
	railPlate: number,
	railHeight: number,
	railTopFromTop: number?,
	chipWidth: number,
	chipHeight: number,
	chipsHeight: number,
	chipsBottom: number,
	chipsTopFromTop: number,
	stockWidth: number,
	stockHeight: number,
	ticketTop: number,
	ticketHeight: number,
	serveHeight: number,
	serveBottom: number,
	serveTopFromBottom: number,
	healthLeft: number,
	healthTopFromTop: number,
	healthWidth: number,
	healthHeight: number,
}

function ResponsiveLayout.hudLayout(mode: Mode, viewport: Vector2): HudLayout
	local hud = Theme.Hud
	local margin = hud.EdgeMargin
	local labelBand = hud.LabelHeight + 4
	local phone = mode == "Phone"
	local compact = mode ~= "Desktop"
	-- This module is landscape-first, so a landscape phone reports "Compact".
	-- Desktop-sized plates would eat a quarter of such a screen, so HUD sizing
	-- keys off the short axis too, not off the mode alone.
	local phoneSized = phone or viewport.Y < hud.ShortViewport

	local ticketTop = if viewport.X < 1000 then 58 else 9
	local ticketHeight = if compact then 42 else 48
	local ticketBottomFromTop = ticketTop + ticketHeight

	local stockWidth, stockHeight = ResponsiveLayout.stockDockSize(mode, viewport)

	local chipSpec = hud.StatChip
	local chipWidth = if phoneSized then chipSpec.Width.Phone else chipSpec.Width.Desktop
	local chipHeight = if phoneSized then chipSpec.Height.Phone else chipSpec.Height.Desktop
	local chipsHeight = 3 * chipHeight + 2 * chipSpec.Gap

	local dockPlate = if phoneSized then hud.DockPlate.Phone else hud.DockPlate.Desktop
	local dockWidth = 5 * dockPlate + 4 * hud.DockGap
	local dockLeft = (viewport.X - dockWidth) / 2

	-- The bottom-left corner belongs to the always-visible stock dock, with the
	-- stat pills stacked directly on top of it. The centred action dock shares
	-- the bottom edge only when it clears that column; otherwise it floats just
	-- above the stock dock.
	local chipsBottom = margin + stockHeight + 8
	local dockBottom = margin + labelBand
	if dockLeft < margin + math.max(stockWidth, chipWidth) + 8 then
		dockBottom = margin + stockHeight + 8 + labelBand
	end

	-- If the dock still clips the pill column, slide it right out of the way
	-- before considering anything taller: on narrow screens the overlap is
	-- often only a few pixels, and nudging the dock costs far less than
	-- restacking the whole left column. Only when it cannot fit between the
	-- pills and the rail do the pills move above the dock band instead.
	local chipsRight = margin + chipWidth
	local railGutter = viewport.X
		- margin
		- (if phoneSized then hud.RailPlate.Phone else hud.RailPlate.Desktop)
	local dockOffsetX = 0
	if dockLeft < chipsRight + 8 then
		local shifted = chipsRight + 8
		if shifted + dockWidth <= railGutter - 8 then
			dockOffsetX = shifted - dockLeft
			dockLeft = shifted
		else
			chipsBottom = dockBottom + dockPlate + 8
		end
	end

	-- The rail centres on the right edge when it fits clear of the order
	-- ticket, otherwise it hangs from just under the ticket and shrinks to
	-- whatever height is left above the dock band.
	local railPlate = if phoneSized then hud.RailPlate.Phone else hud.RailPlate.Desktop
	local railTopFromTop: number? = nil
	if (viewport.Y - (5 * railPlate + 4 * hud.RailGap)) / 2 < ticketBottomFromTop + 8 then
		local top = ticketBottomFromTop + 8
		railTopFromTop = top
		-- Only reserve room for the dock when the two actually share columns.
		local railLeft = viewport.X - margin - railPlate
		local floor = if dockLeft + dockWidth > railLeft - 8
			then dockBottom + dockPlate + 8
			else margin
		local available = viewport.Y - top - floor
		railPlate = math.max(
			hud.RailPlateMin,
			math.min(railPlate, math.floor((available - 4 * hud.RailGap) / 5))
		)
	end

	local serveHeight = if compact then 46 else 50
	local serveBottom = dockBottom + dockPlate + 12

	-- The cafe-health bars sit centred along the top edge (owner request). Only
	-- a viewport too narrow to centre them without colliding with the order
	-- ticket drops them into the left column, where the camera pad also lives —
	-- which is why the pad reads these numbers.
	local healthWidth = if viewport.X < 700 then 292 else 304
	local healthNarrow = viewport.X < 700

	return {
		phoneSized = phoneSized,
		dockPlate = dockPlate,
		dockWidth = dockWidth,
		dockBottom = dockBottom,
		dockOffsetX = dockOffsetX,
		labelBand = labelBand,
		railPlate = railPlate,
		railHeight = 5 * railPlate + 4 * hud.RailGap,
		railTopFromTop = railTopFromTop,
		chipWidth = chipWidth,
		chipHeight = chipHeight,
		chipsHeight = chipsHeight,
		chipsBottom = chipsBottom,
		chipsTopFromTop = viewport.Y - (chipsBottom + chipsHeight),
		stockWidth = stockWidth,
		stockHeight = stockHeight,
		ticketTop = ticketTop,
		ticketHeight = ticketHeight,
		serveHeight = serveHeight,
		serveBottom = serveBottom,
		serveTopFromBottom = serveBottom + serveHeight,
		healthLeft = if healthNarrow then 10 else (viewport.X - healthWidth) / 2,
		healthTopFromTop = if healthNarrow then 100 else 62,
		healthWidth = healthWidth,
		healthHeight = 50,
	}
end

-- Convenience for controllers that only own one element and just need the
-- current numbers.
function ResponsiveLayout.currentHudLayout(): HudLayout
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return ResponsiveLayout.hudLayout(ResponsiveLayout.mode(viewport), viewport)
end

function ResponsiveLayout.panelSize(desktopWidth: number, desktopHeight: number): UDim2
	if ResponsiveLayout.isPhone() then
		return UDim2.new(1, -20, 0.76, 0)
	end
	return UDim2.fromOffset(desktopWidth, desktopHeight)
end

function ResponsiveLayout.panelPosition(desktopX: number?): UDim2
	if ResponsiveLayout.isPhone() then
		return UDim2.new(0.5, 0, 1, -10)
	end
	return UDim2.new(0.5, desktopX or 0, 0.5, 0)
end

function ResponsiveLayout.watch(callback: (Mode, Vector2) -> ()): RBXScriptConnection?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local function fire()
		callback(ResponsiveLayout.mode(camera.ViewportSize), camera.ViewportSize)
	end
	fire()
	return camera:GetPropertyChangedSignal("ViewportSize"):Connect(fire)
end

return ResponsiveLayout
