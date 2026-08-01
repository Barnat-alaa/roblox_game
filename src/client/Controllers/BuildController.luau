--!strict
-- Responsive build catalogue with server-authoritative placement.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Grid = require(Shared.Utilities.Grid)
local World = require(Shared.Config.World)
local AssetManifest = require(Shared.Config.AssetManifest)
local Furniture = require(Shared.Config.Furniture)
local Surfaces = require(Shared.Config.Surfaces)
local Facade = require(Shared.Config.Facade)

-- Every catalogue id has a Creator Store model, so the row can show the real
-- item. Returns nil for anything unmapped, which falls back to a glyph badge.
local function assetIdFor(catalogId: string): number?
	local entry = (AssetManifest.furniture :: any)[catalogId]
	return if entry then entry.assetId else nil
end
local Remotes = require(Shared.Network.Remotes)

local Components = require(script.Parent.Parent.UI.Components)
local StylePreview = require(script.Parent.Parent.UI.StylePreview)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local BuildController = {}
BuildController.Name = "BuildController"

local active = false
local selectedId: string? = nil
local selectedCategory = "All"
local rotation = 0
-- Set while CARRYING an already-placed piece (B2). When this is set, a click
-- moves that item instead of placing a new one; the ghost preview and R-to-rotate
-- are shared with normal placement.
local movingInstanceId: string? = nil
-- The armed surface style (B3). Both must be set for a click to paint; they
-- default to the first entries so the tab is usable the moment it is opened.
local surfaceColor = Surfaces.palette[1].id
local surfaceMotif = Surfaces.motifs[1].id
local previewPart: Part? = nil
local ui: { [string]: any } = {}

local function getOrigin(): CFrame?
	local origin = player:GetAttribute("PlotOrigin")
	return if typeof(origin) == "CFrame" then origin else nil
end

local function ownPlotModel(): Instance?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("ownerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function ownPlotFloor(): BasePart?
	local plot = ownPlotModel()
	if plot then
		local shell = plot:FindFirstChild("Shell")
		local floor = shell and shell:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			return floor
		end
	end
	return nil
end

-- Expects viewport coordinates. InputObject coordinates are converted in Start.
local function raycastCell(viewportPosition: Vector2): (number?, number?)
	local origin = getOrigin()
	local camera = workspace.CurrentCamera
	if not origin or not camera then
		return nil, nil
	end
	local ray = camera:ViewportPointToRay(viewportPosition.X, viewportPosition.Y)
	local params = RaycastParams.new()
	local floor = ownPlotFloor()
	if floor then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { floor }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude: { Instance } = {}
		if player.Character then
			table.insert(exclude, player.Character)
		end
		if previewPart then
			table.insert(exclude, previewPart)
		end
		params.FilterDescendantsInstances = exclude
	end
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not result then
		return nil, nil
	end
	return Grid.worldToCell(origin, result.Position)
end

local function updatePreview()
	if not active or not selectedId then
		if previewPart then
			previewPart.Parent = nil
		end
		return
	end
	local definition = Furniture[selectedId]
	local origin = getOrigin()
	if not definition or not origin then
		return
	end
	local gridX, gridY = raycastCell(UserInputService:GetMouseLocation())
	if not gridX or not gridY then
		return
	end
	if not previewPart then
		local part = Instance.new("Part")
		part.Name = "BuildPreview"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.35
		part.Material = Enum.Material.SmoothPlastic
		previewPart = part
	end
	local preview = previewPart :: Part
	preview.Size = Vector3.new(
		definition.width * Grid.CELL_SIZE - 0.2,
		definition.height,
		definition.depth * Grid.CELL_SIZE - 0.2
	)
	preview.CFrame = Grid.cellToWorld(
		origin,
		gridX,
		gridY,
		definition.width,
		definition.depth,
		rotation,
		definition.height
	)
	local tier = tonumber(player:GetAttribute("ExpansionTier")) or 0
	local depthCells = World.interiorDepthTiers[math.clamp(tier + 1, 1, #World.interiorDepthTiers)]
	local fits =
		Grid.inBounds(gridX, gridY, definition.width, definition.depth, rotation, nil, depthCells)
	preview.Color = if fits then Theme.Colors.Mint else Theme.Colors.Danger
	preview.Parent = workspace
end

-- Which already-placed item covers this cell? Derived from the same footprint
-- maths the server validates with, so what you can click is exactly what the
-- server believes is there — no second raycast pass and no separate hitboxes.
local function placedAtCell(gridX: number, gridY: number): any
	local profile = UIController.getProfile()
	if not profile then
		return nil
	end
	for _, placed in profile.placedFurniture or {} do
		local definition = Furniture[placed.catalogId]
		if definition then
			local w, d = Grid.footprintSize(definition.width, definition.depth, placed.rotation)
			if
				gridX >= placed.gridX
				and gridX < placed.gridX + w
				and gridY >= placed.gridY
				and gridY < placed.gridY + d
			then
				return placed
			end
		end
	end
	return nil
end

local function setHint(text: string)
	if ui.hint then
		ui.hint.Text = text
	end
end

-- Which wall segment is under the cursor? Build mode's normal raycast filters to
-- the FLOOR, so painting walls needs its own pass against the shell's wall parts.
-- The hit is converted into plot-local space and read off the wall it landed on.
local function raycastWall(viewportPosition: Vector2): (string?, number?)
	local origin = getOrigin()
	local camera = workspace.CurrentCamera
	local plot = ownPlotModel()
	local shell = plot and plot:FindFirstChild("Shell")
	if not origin or not camera or not shell then
		return nil, nil
	end
	local walls: { Instance } = {}
	for _, part in shell:GetChildren() do
		if
			part:IsA("BasePart")
			and (part.Name == "WallLeft" or part.Name == "WallRight" or part.Name == "WallBack")
		then
			table.insert(walls, part)
		end
	end
	if #walls == 0 then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = walls
	local ray = camera:ViewportPointToRay(viewportPosition.X, viewportPosition.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not result or not result.Instance then
		return nil, nil
	end
	local localPos = origin:PointToObjectSpace(result.Position)
	local name = result.Instance.Name
	if name == "WallBack" then
		return "back", math.floor(localPos.X / Grid.CELL_SIZE)
	end
	-- Left and right walls both run along local Z, so the segment index is the
	-- same maths; which one it is comes from the part that was hit.
	return (if name == "WallLeft" then "left" else "right"), math.floor(localPos.Z / Grid.CELL_SIZE)
end

-- Paint whatever is under the cursor. Walls are tried FIRST: a wall stands
-- between the camera and the floor behind it, so testing the floor first would
-- make the far wall unpaintable.
local function tryPaint(screenPosition: Vector2): boolean
	local wallId, index = raycastWall(screenPosition)
	if wallId and index and index >= 0 then
		Remotes.event("PaintSurface"):FireServer({
			surface = "wall",
			wallId = wallId,
			index = index,
			colorId = surfaceColor,
			motifId = surfaceMotif,
		})
		return true
	end
	local gridX, gridY = raycastCell(screenPosition)
	if gridX and gridY then
		Remotes.event("PaintSurface"):FireServer({
			surface = "floor",
			gridX = gridX,
			gridY = gridY,
			colorId = surfaceColor,
			motifId = surfaceMotif,
		})
		return true
	end
	return false
end

local function tryPlace(screenPosition: Vector2)
	if not active then
		return
	end
	-- The Surfaces tab paints instead of placing.
	if selectedCategory == "Surfaces" then
		tryPaint(screenPosition)
		return
	end
	local gridX, gridY = raycastCell(screenPosition)
	if not gridX or not gridY then
		return
	end

	-- Carrying an existing piece: this click sets it down at the new cell.
	if movingInstanceId then
		Remotes.event("MoveFurniture"):FireServer({
			instanceId = movingInstanceId,
			gridX = gridX,
			gridY = gridY,
			rotation = rotation,
		})
		movingInstanceId = nil
		selectedId = nil
		setHint("Moved. Tap another placed item to move it.")
		return
	end

	-- A catalogue item is chosen: place a new one.
	if selectedId then
		Remotes.event("PlaceFurniture"):FireServer({
			catalogId = selectedId,
			gridX = gridX,
			gridY = gridY,
			rotation = rotation,
		})
		return
	end

	-- Nothing chosen: pick up whatever is under the cursor and carry it. The
	-- ghost preview and R-to-rotate then work exactly as they do for a new piece.
	local placed = placedAtCell(gridX, gridY)
	if placed then
		movingInstanceId = placed.instanceId
		selectedId = placed.catalogId
		rotation = math.floor(tonumber(placed.rotation) or 0) % 4
		local definition = Furniture[placed.catalogId]
		setHint(
			"Moving "
				.. ((definition and definition.displayName) or placed.catalogId)
				.. " — tap a new spot (R rotates)."
		)
	end
end

local function setCategoryButtons(activeButton: TextButton?)
	for _, child in ui.categories:GetChildren() do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = if child == activeButton
				then Theme.Colors.Coral
				else Theme.Colors.PaperDark
			child.TextColor3 = if child == activeButton
				then Theme.Colors.White
				else Theme.Colors.Ink
		end
	end
end

-- Forward declaration: buildSurfacePicker re-runs the catalogue when a swatch is
-- tapped, and the catalogue in turn renders the picker.
local refreshCatalogue: () -> ()

-- The Front tab (B4a): one labelled row per façade axis. Every button sends just
-- its own axis, because `SetFacade` accepts any SUBSET — so one tap changes one
-- thing and the other six choices are left alone.
local FACADE_AXES = {
	{ axis = "architecture", label = "ARCHITECTURE", list = Facade.architectures },
	{ axis = "color", label = "FRONT COLOUR", list = Facade.colors },
	{ axis = "motif", label = "FRONT MOTIF", list = Facade.motifs },
	{ axis = "doorStyle", label = "DOOR STYLE", list = Facade.doorStyles },
	{ axis = "doorWood", label = "DOOR WOOD", list = Facade.doorWoods },
	{ axis = "windowShape", label = "WINDOW SHAPE", list = Facade.windowShapes },
	{ axis = "glass", label = "GLASS", list = Facade.glassTints },
}

local function buildFacadePicker()
	local profile = UIController.getProfile()
	local chosen = Facade.resolve(profile and profile.facade)
	local order = 0

	order += 1
	local intro = Components.Label(
		ui.list,
		string.format("Restyle your café front — %d coins per change", Facade.changePrice),
		11,
		true
	)
	intro.Name = "SurfaceHeading"
	intro.Size = UDim2.new(1, -6, 0, 22)
	intro.LayoutOrder = order
	intro.TextXAlignment = Enum.TextXAlignment.Left
	intro.TextColor3 = Theme.Colors.Muted
	intro.ZIndex = 22

	for _, group in FACADE_AXES do
		order += 1
		local heading = Components.Label(ui.list, group.label, 11, true)
		heading.Name = "SurfaceHeading"
		heading.Size = UDim2.new(1, -6, 0, 18)
		heading.LayoutOrder = order
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.TextColor3 = Theme.Colors.Muted
		heading.ZIndex = 22

		for _, entry in group.list do
			order += 1
			local isChosen = chosen[group.axis] and chosen[group.axis].id == entry.id
			local button = Components.Button(
				ui.list,
				"",
				if isChosen then Theme.Colors.Mint else Theme.Colors.Paper,
				UDim2.new(1, -6, 0, 46)
			)
			button.Name = group.axis .. "_" .. entry.id
			button.LayoutOrder = order
			button.ZIndex = 22
			if isChosen then
				Components.Stroke(button, Theme.Colors.Ink, 3, 0.15)
			end

			-- A drawn preview of what this option actually gives you, using the
			-- CURRENT choices for the axes it depends on: a door style previews in
			-- YOUR wood, a window shape in YOUR glass, a motif in YOUR colour. So
			-- the swatch shows the result of picking it, not the option in isolation.
			local axis = group.axis
			local preview: Frame
			if axis == "architecture" then
				preview = StylePreview.architecture(button, entry, chosen.color, 36)
			elseif axis == "motif" then
				preview = StylePreview.facadeMotif(button, chosen.color, entry, 36)
			elseif axis == "doorStyle" then
				preview = StylePreview.door(button, entry, chosen.doorWood, 36)
			elseif axis == "doorWood" then
				preview = StylePreview.door(button, chosen.doorStyle, entry, 36)
			elseif axis == "windowShape" then
				preview = StylePreview.window(button, entry, chosen.glass, 36)
			elseif axis == "color" then
				preview = StylePreview.color(button, entry, 36)
			else
				preview = StylePreview.glass(button, entry, 36)
			end
			preview.Position = UDim2.fromOffset(6, 5)

			local name = Components.Label(button, entry.name, 12, true)
			name.Size = UDim2.new(1, -118, 1, 0)
			name.Position = UDim2.fromOffset(50, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.TextColor3 = if isChosen then Theme.Colors.White else Theme.Colors.Ink
			name.ZIndex = 24

			if isChosen then
				local owned = Components.Label(button, "IN USE", 10, true)
				owned.AnchorPoint = Vector2.new(1, 0.5)
				owned.Position = UDim2.new(1, -8, 0.5, 0)
				owned.Size = UDim2.fromOffset(58, 20)
				owned.BackgroundTransparency = 0
				owned.BackgroundColor3 = Theme.Colors.MintDark
				owned.TextColor3 = Theme.Colors.White
				owned.ZIndex = 24
				Components.Corner(owned, Theme.Radius.Pill)
			else
				StylePreview.priceChip(button, Facade.changePrice)
			end

			button.Activated:Connect(function()
				Remotes.event("SetFacade"):FireServer({ [group.axis] = entry.id })
				setHint("Applying " .. entry.name .. "…")
			end)
		end
	end
end

-- The Surfaces tab (B3): a colour swatch row and a motif row, instead of the
-- furniture list. Picking both arms "painting" — clicking the floor tiles a cell,
-- clicking a wall panels that segment.
local function buildSurfacePicker()
	local order = 0
	local function row(labelText: string)
		order += 1
		local label = Components.Label(ui.list, labelText, 11, true)
		label.Name = "SurfaceHeading"
		label.Size = UDim2.new(1, -6, 0, 18)
		label.LayoutOrder = order
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.Colors.Muted
		label.ZIndex = 22
	end

	-- Both rows preview the SAME pairing you would paint: a colour is shown
	-- wearing the motif you have armed, and vice versa — you see the result,
	-- not the ingredient.
	local activeMotif = Surfaces.motif(surfaceMotif) or Surfaces.motifs[1]
	local activeColor = Surfaces.color(surfaceColor) or Surfaces.palette[1]

	local function optionRow(
		name: string,
		label: string,
		chosen: boolean,
		preview: (Instance) -> Frame,
		onPick: () -> ()
	)
		order += 1
		local button = Components.Button(
			ui.list,
			"",
			if chosen then Theme.Colors.Mint else Theme.Colors.Paper,
			UDim2.new(1, -6, 0, 46)
		)
		button.Name = name
		button.LayoutOrder = order
		button.ZIndex = 22
		if chosen then
			Components.Stroke(button, Theme.Colors.Ink, 3, 0.15)
		end
		preview(button).Position = UDim2.fromOffset(6, 5)

		local text = Components.Label(button, label, 12, true)
		text.Size = UDim2.new(1, -132, 1, 0)
		text.Position = UDim2.fromOffset(50, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextTruncate = Enum.TextTruncate.AtEnd
		text.TextColor3 = if chosen then Theme.Colors.White else Theme.Colors.Ink
		text.ZIndex = 24

		-- Painting is charged per placement and a wall panel costs more than a
		-- floor tile, so the chip shows both rather than one misleading number.
		local chip = StylePreview.priceChip(button, Surfaces.floorTilePrice)
		chip.Text = Surfaces.floorTilePrice .. " / " .. Surfaces.wallPanelPrice
		chip.Size = UDim2.fromOffset(74, 20)

		button.Activated:Connect(onPick)
	end

	row("COLOUR")
	for _, entry in Surfaces.palette do
		optionRow("color_" .. entry.id, entry.name, surfaceColor == entry.id, function(parent)
			return StylePreview.surface(parent, entry, activeMotif, 36)
		end, function()
			surfaceColor = entry.id
			movingInstanceId = nil
			selectedId = nil
			refreshCatalogue()
			setHint("Painting " .. entry.name .. " — tap the floor or a wall.")
		end)
	end

	row("MOTIF")
	for _, entry in Surfaces.motifs do
		optionRow("motif_" .. entry.id, entry.name, surfaceMotif == entry.id, function(parent)
			return StylePreview.surface(parent, activeColor, entry, 36)
		end, function()
			surfaceMotif = entry.id
			movingInstanceId = nil
			selectedId = nil
			refreshCatalogue()
			setHint("Painting " .. entry.name .. " — tap the floor or a wall.")
		end)
	end

	order += 1
	local prices =
		Components.Label(ui.list, "Floor tile / wall panel — charged as you place", 11, true)
	prices.Name = "SurfaceHeading"
	prices.Size = UDim2.new(1, -6, 0, 26)
	prices.LayoutOrder = order
	prices.TextXAlignment = Enum.TextXAlignment.Left
	prices.TextColor3 = Theme.Colors.Muted
	prices.ZIndex = 22
end

refreshCatalogue = function()
	if not ui.list then
		return
	end
	for _, child in ui.list:GetChildren() do
		if child:IsA("TextButton") or child.Name == "SurfaceHeading" then
			child:Destroy()
		end
	end
	if selectedCategory == "Surfaces" then
		ui.empty.Visible = false
		buildSurfacePicker()
		return
	end
	if selectedCategory == "Front" then
		ui.empty.Visible = false
		buildFacadePicker()
		return
	end
	local profile = UIController.getProfile()
	if not profile then
		return
	end
	local ids = {}
	for id, count in profile.inventory do
		local definition = Furniture[id]
		if
			count > 0
			and definition
			and (selectedCategory == "All" or definition.category == selectedCategory)
		then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Furniture[a].displayName < Furniture[b].displayName
	end)
	for order, id in ids do
		local count = profile.inventory[id]
		local definition = Furniture[id]
		local selected = selectedId == id
		local button = Instance.new("TextButton")
		button.Name = id
		button.Size = UDim2.new(1, -6, 0, 58)
		button.LayoutOrder = order
		button.BackgroundColor3 = if selected then Theme.Colors.Mint else Theme.Colors.Paper
		button.TextColor3 = if selected then Theme.Colors.White else Theme.Colors.Ink
		button.Text = ""
		button.ZIndex = 22
		Components.Corner(button, Theme.Radius.Medium)
		Components.Stroke(button, Theme.Colors.Line, 1, 0.35)

		-- Show the actual item you are about to place, not a coloured bar.
		local thumbnail = Components.ItemThumbnail(button, {
			assetId = assetIdFor(id),
			size = Theme.Thumbnail.CardSize,
			glyph = Components.CategoryGlyph(definition.category),
			accent = Components.CategoryColor(definition.category),
		})
		thumbnail.root.Position = UDim2.fromOffset(6, 6)
		thumbnail.root.ZIndex = 23

		local textLeft = 6 + Theme.Thumbnail.CardSize + 8
		local name = Components.Label(button, definition.displayName, 13, true)
		name.Size = UDim2.new(1, -(textLeft + 8), 0, 22)
		name.Position = UDim2.fromOffset(textLeft, 7)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = button.TextColor3
		name.ZIndex = 23
		local detail = Components.Label(
			button,
			string.format(
				"%s  |  %dx%d cells  |  x%d",
				definition.category,
				definition.width,
				definition.depth,
				count
			),
			11,
			false
		)
		detail.Size = UDim2.new(1, -(textLeft + 8), 0, 20)
		detail.Position = UDim2.fromOffset(textLeft, 30)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		detail.TextColor3 = if selected then Theme.Colors.Cream else Theme.Colors.Muted
		detail.ZIndex = 23

		button.Activated:Connect(function()
			-- Choosing from the catalogue abandons any piece being carried.
			movingInstanceId = nil
			selectedId = id
			setHint("Tap a spot to place it (R rotates).")
			refreshCatalogue()
		end)
		button.Parent = ui.list
	end
	ui.empty.Visible = #ids == 0
end

local function leaveBuildMode()
	active = false
	selectedId = nil
	movingInstanceId = nil
	if previewPart then
		previewPart.Parent = nil
	end
end

local function toggle()
	if active then
		leaveBuildMode()
		UIController.closePanel(ui.panel)
	else
		active = true
		UIController.togglePanel(ui.panel)
		refreshCatalogue()
	end
end

local function buildPanel()
	local panel = Components.Panel(UIController.modalRoot(), "BuildPanel")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Size = UDim2.fromOffset(320, 520)
	panel.Position = UDim2.new(0, 12, 0.5, 0)
	panel.Visible = false
	local _, close = Components.PanelHeader(
		panel,
		"BUILD MODE",
		"Tap a placed item to MOVE it, or pick one below to add",
		Theme.Colors.Coral
	)
	close.Activated:Connect(toggle)

	-- Live instruction line: what a tap will do right now. Build mode has three
	-- states (idle / placing a new item / carrying an existing one) and without
	-- this the only feedback for "you are carrying something" is the ghost.
	local hint = Components.Label(panel, "", 11, true)
	hint.Size = UDim2.new(1, -20, 0, 18)
	hint.Position = UDim2.fromOffset(10, 108)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.TextColor3 = Theme.Colors.Muted
	hint.ZIndex = 22
	ui.hint = hint

	local categories = Instance.new("Frame")
	categories.Size = UDim2.new(1, -20, 0, 36)
	categories.Position = UDim2.fromOffset(10, 72)
	categories.BackgroundTransparency = 1
	categories.ZIndex = 21
	categories.Parent = panel
	local categoryLayout = Instance.new("UIListLayout")
	categoryLayout.FillDirection = Enum.FillDirection.Horizontal
	categoryLayout.Padding = UDim.new(0, 5)
	categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
	categoryLayout.Parent = categories
	ui.categories = categories
	local firstButton: TextButton? = nil
	for order, category in { "All", "Appliance", "Seating", "Decoration", "Surfaces", "Front" } do
		local button = Components.Button(
			categories,
			if category == "Decoration"
				then "Decor"
				elseif category == "Surfaces" then "Floor/Wall"
				elseif category == "Appliance" then "Appl."
				else category,
			Theme.Colors.PaperDark,
			UDim2.new(1 / 6, -4, 1, 0)
		)
		button.LayoutOrder = order
		button.TextColor3 = Theme.Colors.Ink
		button.TextSize = 10
		button.ZIndex = 22
		if category == "All" then
			firstButton = button
		end
		button.Activated:Connect(function()
			selectedCategory = category
			setCategoryButtons(button)
			refreshCatalogue()
		end)
	end
	setCategoryButtons(firstButton)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -176)
	list.Position = UDim2.fromOffset(8, 116)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Coral
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	ui.list = list
	local empty = Components.Label(list, "No owned items here. Visit the Shop first.", 12, true)
	empty.Size = UDim2.new(1, -12, 0, 60)
	empty.TextWrapped = true
	empty.TextColor3 = Theme.Colors.Muted
	empty.Visible = false
	empty.ZIndex = 22
	ui.empty = empty

	local rotateButton =
		Components.Button(panel, "ROTATE", Theme.Colors.Blue, UDim2.new(0.5, -14, 0, 44), "R")
	rotateButton.Position = UDim2.new(0, 10, 1, -52)
	rotateButton.ZIndex = 22
	rotateButton.Activated:Connect(function()
		rotation = (rotation + 1) % 4
	end)
	local doneButton =
		Components.Button(panel, "DONE", Theme.Colors.Mint, UDim2.new(0.5, -14, 0, 44), "OK")
	doneButton.Position = UDim2.new(0.5, 4, 1, -52)
	doneButton.ZIndex = 22
	doneButton.Activated:Connect(toggle)
	ui.panel = panel

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and active then
			leaveBuildMode()
		end
	end)
	ResponsiveLayout.watch(function(mode, viewport)
		if mode == "Phone" then
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -8)
			panel.Size = UDim2.new(1, -16, 0.7, 0)
		elseif mode == "Compact" then
			panel.AnchorPoint = Vector2.new(0, 0.5)
			panel.Position = UDim2.new(0, 8, 0.5, 0)
			panel.Size = UDim2.fromOffset(math.clamp(viewport.X * 0.39, 300, 324), viewport.Y - 16)
		else
			panel.AnchorPoint = Vector2.new(0, 0.5)
			panel.Position = UDim2.new(0, 12, 0.5, 0)
			panel.Size = UDim2.fromOffset(320, 520)
		end
	end)
end

function BuildController.Start(_self: any)
	buildPanel()
	UIController.onBuildToggle = toggle
	UIController.registerAction("Build", toggle)
	UIController.bindActionPanel("Build", ui.panel)
	UIController.subscribeProfile(function()
		if active then
			refreshCatalogue()
		end
	end)
	RunService.RenderStepped:Connect(updatePreview)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local inset = GuiService:GetGuiInset()
			tryPlace(Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y))
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
		end
	end)
end

return BuildController
