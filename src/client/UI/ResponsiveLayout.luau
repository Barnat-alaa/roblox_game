--!strict

local Theme = require(script.Parent.Theme)

local ResponsiveLayout = {}

export type Mode = "Phone" | "Compact" | "Desktop"

-- The live viewport, with the same fallback every other helper here uses.
function ResponsiveLayout.viewport(): Vector2
	return (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)
		or Vector2.new(1280, 720)
end

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
	-- A landscape phone reports "Compact", not "Phone" (this module is
	-- landscape-first), so the narrow column keys off the SHORT axis as well —
	-- the same rule the rest of hudLayout uses. Without this, the device class
	-- the owner actually plays on kept the wide strip.
	if mode == "Phone" or viewport.Y < Theme.Hud.ShortViewport then
		-- Narrow column, four slots tall. Was nearly the full screen width and
		-- only 56 tall, which is what pinned the action dock up off the bottom
		-- edge and left it floating in the middle of the screen.
		local spec = Theme.Hud.StockDockPhone
		return spec.Width, spec.Header + spec.Slots * spec.SlotHeight
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
	-- Six dock buttons (Build, Cookbook, Staff, Upgrades, Shop, Market). This
	-- said 5 and was under-measuring the dock by a whole plate, which is part of
	-- why it kept colliding with the left column.
	local dockWidth = 6 * dockPlate + 5 * hud.DockGap
	local dockLeft = (viewport.X - dockWidth) / 2

	-- The bottom-left corner belongs to the always-visible stock dock, with the
	-- stat pills stacked directly on top of it. The centred action dock shares
	-- the bottom edge only when it clears that column; otherwise it floats just
	-- above the stock dock.
	local chipsBottom = margin + stockHeight + 8
	-- The caption band under each button is gone (names flash on tap now), so the
	-- action dock can sit on the EXTREME bottom edge, which is where the owner
	-- wants it and where a thumb naturally lands.
	local dockBottom = if phoneSized then margin else margin + labelBand
	local leftColumn = margin + math.max(stockWidth, chipWidth) + 8
	-- Hoisted: the "can the dock sit beside the left column?" test and the shift
	-- that acts on it MUST use the same threshold. They did not, so on a very
	-- narrow screen the dock was told it fitted, then refused to shift, and ended
	-- up overlapping the pantry.
	local railGutter = viewport.X
		- margin
		- (if phoneSized then hud.RailPlate.Phone else hud.RailPlate.Desktop)
	local fitsBesideColumn = leftColumn + dockWidth <= railGutter - 8
	if dockLeft < leftColumn then
		-- The left column is in the way. On a phone the stock dock is now a NARROW
		-- tall strip, so sliding the dock right of it almost always works and is
		-- much better than lifting it — lifting is what put the buttons in the
		-- middle of the screen. Only stack vertically if the dock genuinely cannot
		-- fit beside the column.
		if not (phoneSized and fitsBesideColumn) then
			dockBottom = margin + stockHeight + 8 + labelBand
		end
	end

	-- If the dock still clips the pill column, slide it right out of the way
	-- before considering anything taller: on narrow screens the overlap is
	-- often only a few pixels, and nudging the dock costs far less than
	-- restacking the whole left column. Only when it cannot fit between the
	-- pills and the rail do the pills move above the dock band instead.
	-- Clear the WHOLE left column, not just the pills. Since the phone stock dock
	-- became a tall narrow strip it is the wider of the two, and measuring against
	-- the pills alone left the dock overlapping it by ~20px.
	local chipsRight = leftColumn
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

	-- The café-health bars sit as one slim strip at the EXTREME top-centre (owner
	-- request 2026-07-27) so they never cover the café/dishes below. Compact and
	-- always centred; shrinks to fit a phone. The order ticket is top-RIGHT and the
	-- camera pad bottom-left, so nothing collides here.
	local healthWidth = math.min(360, viewport.X - 16)

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
		healthLeft = (viewport.X - healthWidth) / 2,
		healthTopFromTop = 6,
		healthWidth = healthWidth,
		healthHeight = 30,
	}
end

-- Convenience for controllers that only own one element and just need the
-- current numbers.
function ResponsiveLayout.currentHudLayout(): HudLayout
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return ResponsiveLayout.hudLayout(ResponsiveLayout.mode(viewport), viewport)
end

-- Roblox draws its own topbar over the top of the screen. A panel pinned to the
-- "extreme top" therefore has to start BELOW that inset or its header is
-- unreadable — which is exactly what was happening to the build panel.
function ResponsiveLayout.topInset(): number
	local ok, inset = pcall(function()
		return game:GetService("GuiService"):GetGuiInset()
	end)
	return if ok and inset then math.max(inset.Y, 36) else 36
end

-- ————— panel docking —————
--
-- Every modal used to carry its own three-branch layout, and every one of them
-- ended the same way: centred on Desktop (`fromScale(0.5, 0.5)`). That is what
-- put the menus in the middle of the screen. One helper now owns all three
-- breakpoints so a panel cannot drift back to the centre, and so a fix here
-- reaches all of them.
--
--   Phone   — bottom sheet. It leaves the top of the screen showing the café,
--             which is what keeps the game playable one-handed while a panel is
--             open, and it puts the content under the thumb.
--   Compact — a full-height column on `side`.
--   Desktop — the SAME column, just at the panel's natural width. This is the
--             behaviour change: the café stays visible beside the panel instead
--             of being covered by it.
--
-- `side` keeps each panel where players already expect it: Build has always
-- opened on the left, everything else on the right.
export type DockOptions = {
	side: ("left" | "right")?,
	desktopWidth: number,
	desktopHeight: number,
	compactFraction: number?,
	compactMin: number?,
	compactMax: number?,
	phoneHeightScale: number?,
}

function ResponsiveLayout.dockPanel(
	panel: GuiObject,
	mode: Mode,
	viewport: Vector2,
	opts: DockOptions
)
	local margin = Theme.Hud.EdgeMargin
	local onLeft = opts.side == "left"

	if mode == "Phone" then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -margin)
		panel.Size = UDim2.new(1, -2 * margin, opts.phoneHeightScale or 0.68, 0)
		return
	end

	-- Full-height column, kept clear of Roblox's own topbar at the top.
	local inset = ResponsiveLayout.topInset()
	local height = math.max(200, viewport.Y - inset - 2 * margin)
	local width = if mode == "Compact"
		then math.clamp(
			viewport.X * (opts.compactFraction or 0.44),
			opts.compactMin or 320,
			opts.compactMax or 400
		)
		else math.min(opts.desktopWidth, viewport.X - 2 * margin)

	panel.AnchorPoint = Vector2.new(if onLeft then 0 else 1, 0)
	panel.Position =
		UDim2.new(if onLeft then 0 else 1, if onLeft then margin else -margin, 0, inset + margin)
	panel.Size = UDim2.fromOffset(
		width,
		math.min(if mode == "Compact" then height else opts.desktopHeight, height)
	)
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
