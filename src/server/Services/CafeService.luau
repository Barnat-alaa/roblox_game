--!strict
-- Builds the neighbourhood street of café BUILDINGS, assigns one plot per
-- player, renders their saved furniture, and teleports them in. Each plot
-- exposes a local origin CFrame that the grid system uses for placement.
--
-- S2 architecture (2026-07-16): a café is a real building —
--   • FRONT FACADE with windows and an auto-door that swings open when any
--     player/customer/staff approaches and closes behind them (the door is
--     the only way in and out; walls are too tall to jump).
--   • TIERED INTERIOR: floor area starts at 3x the original and deepens with
--     PlayerData.expansionTier (buy-land flow lands in S4; the geometry,
--     data field and rebuild path already work — see RefreshTier).
--   • PRIVATE GARDEN behind the café: fenced grass with a gate off the back
--     wall. Buying land converts garden depth into interior depth.
-- Static parts (facade, sign, awning) build once; the tier-dependent "Shell"
-- (floors, side/back walls, garden) rebuilds on claim/expand/release.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local Graphics = require(Shared.Config.Graphics)
local World = require(Shared.Config.World)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local NpcNav = require(script.Parent.Parent.NpcNav)

local CafeService = {}
CafeService.Name = "CafeService"

local DataService: any
local BuildService: any
local AssetLibraryService: any

local NUM_PLOTS = World.plotCount
local PLOTS_PER_ROW = World.plotsPerRow
local PLOT_SPACING = Grid.PLOT_WIDTH * Grid.CELL_SIZE + World.plotGap

local WALL_H = World.wallHeight
local DOOR_W = World.doorWidth
local DOOR_H = World.doorHeight
local GATE_W = World.gateWidth
local KITCHEN_W = World.kitchenWidthCells * Grid.CELL_SIZE
local KITCHEN_D = World.kitchenDepthCells * Grid.CELL_SIZE
local KITCHEN_DIVIDER_H = World.kitchenDividerHeight
local KITCHEN_PASS_W = 3 * Grid.CELL_SIZE

-- Saturated, sunny cafe palette shared by the shell and facade.
local CORAL = Color3.fromRGB(232, 82, 67)
-- Warm plaster for every wall (interior + facade) — replaces the harsh orange
-- the owner disliked (2026-07-19). CORAL stays for the red awning accent only.
local WALL = Color3.fromRGB(224, 206, 176)
local HONEY_OAK = Color3.fromRGB(212, 151, 76)
local CREAM = Color3.fromRGB(255, 244, 216)
local TEAL = Color3.fromRGB(48, 151, 143)
local GOLD = Color3.fromRGB(243, 174, 55)

-- Total plot depth in studs: max interior + the garden strip that always remains.
local TOTAL_DEPTH = Grid.PLOT_DEPTH * Grid.CELL_SIZE + World.gardenMinDepth

local function tierDepthCells(tier: number): number
	return World.interiorDepthTiers[math.clamp(tier + 1, 1, #World.interiorDepthTiers)]
end

-- Two rows of cafés face each other across a boulevard. Row 0 fronts -Z;
-- row 1 is rotated 180° so its fronts face +Z toward the same street. All
-- plot internals are origin-relative, so rotation Just Works everywhere.
local function plotOriginFor(index: number): CFrame
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local row = if index <= PLOTS_PER_ROW then 0 else 1
	local col = (index - 1) % PLOTS_PER_ROW
	if row == 0 then
		return CFrame.new(col * PLOT_SPACING, 0, 0)
	end
	return CFrame.new(col * PLOT_SPACING + width, 0, -World.boulevardWidth)
		* CFrame.Angles(0, math.rad(180), 0)
end

type Plot = {
	index: number,
	origin: CFrame,
	model: Model,
	furnitureFolder: Folder,
	ownerLabel: TextLabel,
	ownerUserId: number?,
	shutter: Model?,
	shell: Model?,
	tier: number,
}

local plots: { Plot } = {}
local plotByUser: { [number]: Plot } = {}

-- ————— auto-doors —————

type Door = {
	leaf: BasePart,
	closedCf: CFrame,
	openCf: CFrame,
	isOpen: boolean,
}

local doors: { [string]: Door } = {}

-- A swinging door leaf. NEVER collidable — a door must never trap anyone —
-- and the wall gap it fills is what the pathfinding navmesh routes through.
local function makeDoor(
	key: string,
	parent: Instance,
	cf: CFrame,
	w: number,
	h: number,
	color: Color3,
	openDeg: number
): BasePart
	local leaf = Instance.new("Part")
	leaf.Name = "DoorLeaf"
	leaf.Anchored = true
	leaf.CanCollide = false
	leaf.CanQuery = false
	leaf.Size = Vector3.new(w, h, 0.35)
	leaf.CFrame = cf
	leaf.Color = color
	leaf.Material = Enum.Material.Wood
	leaf.Parent = parent

	-- Handle detail so the leaf reads as a door, not a plank.
	local handle = Instance.new("Part")
	handle.Name = "DoorHandle"
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Color = Color3.fromRGB(220, 190, 120)
	handle.Material = Enum.Material.Metal
	handle.CFrame = cf * CFrame.new(w / 2 - 0.5, -0.2, -0.3)
	handle.Parent = leaf
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = leaf
	weld.Part1 = handle
	weld.Parent = leaf
	handle.Anchored = false

	local hinge = cf * CFrame.new(-w / 2, 0, 0)
	doors[key] = {
		leaf = leaf,
		closedCf = cf,
		openCf = hinge * CFrame.Angles(0, math.rad(openDeg), 0) * CFrame.new(w / 2, 0, 0),
		isOpen = false,
	}
	return leaf
end

local function setDoorOpen(door: Door, open: boolean)
	if door.isOpen == open or door.leaf.Parent == nil then
		return
	end
	door.isOpen = open
	TweenService:Create(
		door.leaf,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = if open then door.openCf else door.closedCf }
	):Play()
end

-- Anyone near a door opens it: players, customers, staff.
local function collectCharacterPositions(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(positions, hrp.Position)
		end
	end
	for _, folderName in { "Customers", "Staff" } do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, npc in folder:GetChildren() do
				if npc:IsA("Model") then
					local root = npc:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						table.insert(positions, root.Position)
					end
				end
			end
		end
	end
	return positions
end

local function tickDoors()
	local positions = collectCharacterPositions()
	for key, door in doors do
		if door.leaf.Parent == nil then
			doors[key] = nil
		else
			local centre = door.closedCf.Position
			local near = false
			for _, pos in positions do
				local flat = (pos - centre) * Vector3.new(1, 0, 1)
				if flat.Magnitude < 9 then
					near = true
					break
				end
			end
			setDoorOpen(door, near)
		end
	end
end

-- ————— indoor movement —————

type JumpState = {
	humanoid: Humanoid,
	jumpHeight: number,
	jumpPower: number,
	limited: boolean,
}

local jumpStates: { [Player]: JumpState } = {}
local worldSafetyCenter: Vector3? = nil
local worldSafetySize: Vector3? = nil

local function isInsideRestaurant(position: Vector3): boolean
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	for _, plot in plots do
		local localPosition = plot.origin:PointToObjectSpace(position)
		local depth = tierDepthCells(math.max(plot.tier, 0)) * Grid.CELL_SIZE
		if
			localPosition.X > 0.5
			and localPosition.X < width - 0.5
			and localPosition.Z > 0.5
			and localPosition.Z < depth - 0.5
			and localPosition.Y > -2
			and localPosition.Y < WALL_H + 8
		then
			return true
		end
	end
	return false
end

-- Keep normal street movement, but use a gentler jump while a player is in
-- any restaurant. This lets the walls stay at a welcoming human scale while
-- preventing counter/shelf-assisted vaults over them.
local function tickIndoorJumpLimits()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") then
			local state = jumpStates[player]
			if not state or state.humanoid ~= humanoid then
				state = {
					humanoid = humanoid,
					jumpHeight = humanoid.JumpHeight,
					jumpPower = humanoid.JumpPower,
					limited = false,
				}
				jumpStates[player] = state
			end

			local inside = isInsideRestaurant(root.Position)
			if inside and not state.limited then
				humanoid.JumpHeight = World.indoorJumpHeight
				humanoid.JumpPower = World.indoorJumpPower
				humanoid:SetAttribute("CafeIndoorJumpLimited", true)
				state.limited = true
			elseif not inside and state.limited then
				humanoid.JumpHeight = state.jumpHeight
				humanoid.JumpPower = state.jumpPower
				humanoid:SetAttribute("CafeIndoorJumpLimited", nil)
				state.limited = false
			end
		end
	end
end

-- Invisible city walls plus a recovery watchdog keep players in the playable
-- neighbourhood. Falling or somehow crossing a wall returns them safely to
-- their own front door instead of killing or resetting their character.
local function tickWorldSafety()
	local centre = worldSafetyCenter
	local size = worldSafetySize
	if not centre or not size then
		return
	end
	for _, player in Players:GetPlayers() do
		local plot = plotByUser[player.UserId]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if plot and root and root:IsA("BasePart") then
			local outside = math.abs(root.Position.X - centre.X)
					> size.X / 2 + World.mapSafetyMargin
				or math.abs(root.Position.Z - centre.Z) > size.Z / 2 + World.mapSafetyMargin
				or root.Position.Y < -18
			if outside then
				local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
				local standAt = (plot.origin * CFrame.new(width / 2, 4, -8)).Position
				local lookAt = (plot.origin * CFrame.new(width / 2, 4, 10)).Position
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = CFrame.lookAt(standAt, lookAt)
			end
		end
	end
end

-- ————— part helper —————

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function applyTopTexture(part: BasePart, content: string, tileU: number, tileV: number)
	local texture = Instance.new("Texture")
	texture.Name = "ApprovedSurface"
	texture.Face = Enum.NormalId.Top
	texture.Texture = content
	texture.StudsPerTileU = tileU
	texture.StudsPerTileV = tileV
	texture.Parent = part
end

local function makeWindow(parent: Instance, cf: CFrame)
	makePart("WindowFrame", Vector3.new(5, 3.6, 0.4), cf, CREAM, parent)
	local glass = makePart(
		"WindowGlass",
		Vector3.new(4.2, 2.8, 0.3),
		cf * CFrame.new(0, 0, -0.07),
		Color3.fromRGB(170, 210, 230),
		parent,
		Enum.Material.Glass
	)
	glass.Transparency = 0.15
	glass.CanCollide = false
end

-- ————— tier-dependent shell: floors, side/back walls, garden —————

local function rebuildShell(plot: Plot, tier: number)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local depth = tierDepthCells(tier) * Grid.CELL_SIZE
	local origin = plot.origin

	doors["G" .. plot.index] = nil
	if plot.shell then
		plot.shell:Destroy()
	end
	local shell = Instance.new("Model")
	shell.Name = "Shell"

	-- Warm oak interior floor (tier-sized), grass garden behind it.
	local floor = makePart(
		"Floor",
		Vector3.new(width, 1, depth),
		origin * CFrame.new(width / 2, -0.5, depth / 2),
		HONEY_OAK,
		shell,
		Enum.Material.WoodPlanks
	)
	applyTopTexture(floor, Graphics.Surfaces.WoodFloor, 16, 16)
	makePart(
		"GardenFloor",
		Vector3.new(width, 1, TOTAL_DEPTH - depth),
		origin * CFrame.new(width / 2, -0.5, (depth + TOTAL_DEPTH) / 2),
		Color3.fromRGB(112, 152, 88),
		shell,
		Enum.Material.Grass
	)

	-- Front-right open kitchen: an L-shaped waist-high counter closes the
	-- former empty shortcut off from dining traffic. The final 3-cell section
	-- is the dish pass used by the cook/barista and waiter choreography.
	local dividerColor = CREAM
	local counterColor = GOLD
	local function divider(name: string, size: Vector3, cf: CFrame)
		makePart(name, size, cf, dividerColor, shell)
		makePart(
			name .. "Top",
			Vector3.new(size.X + 0.35, 0.35, size.Z + 0.35),
			cf * CFrame.new(0, size.Y / 2 + 0.175, 0),
			counterColor,
			shell,
			Enum.Material.Wood
		)
	end
	divider(
		"KitchenDivider",
		Vector3.new(0.8, KITCHEN_DIVIDER_H, KITCHEN_D),
		origin * CFrame.new(KITCHEN_W, KITCHEN_DIVIDER_H / 2, KITCHEN_D / 2)
	)
	local backDividerW = KITCHEN_W - KITCHEN_PASS_W
	divider(
		"KitchenDivider",
		Vector3.new(backDividerW, KITCHEN_DIVIDER_H, 0.8),
		origin * CFrame.new(backDividerW / 2, KITCHEN_DIVIDER_H / 2, KITCHEN_D)
	)
	divider(
		"KitchenPass",
		Vector3.new(KITCHEN_PASS_W, KITCHEN_DIVIDER_H, 0.8),
		origin * CFrame.new(KITCHEN_W - KITCHEN_PASS_W / 2, KITCHEN_DIVIDER_H / 2, KITCHEN_D)
	)
	for _, plateX in { KITCHEN_W - KITCHEN_PASS_W + 2, KITCHEN_W - 2 } do
		local plate = makePart(
			"PassPlate",
			Vector3.new(0.18, 1.5, 1.5),
			origin
				* CFrame.new(plateX, KITCHEN_DIVIDER_H + 0.35, KITCHEN_D)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(250, 248, 240),
			shell,
			Enum.Material.SmoothPlastic
		)
		plate.Shape = Enum.PartType.Cylinder
		plate.CanCollide = false
	end

	-- Side walls run the interior only; the garden gets picket fences.
	makePart(
		"WallLeft",
		Vector3.new(1, WALL_H, depth),
		origin * CFrame.new(0, WALL_H / 2, depth / 2),
		WALL,
		shell
	)
	makePart(
		"WallRight",
		Vector3.new(1, WALL_H, depth),
		origin * CFrame.new(width, WALL_H / 2, depth / 2),
		WALL,
		shell
	)

	-- Back wall with a garden gate gap in the middle + interior windows.
	local gateL = width / 2 - GATE_W / 2
	local gateR = width / 2 + GATE_W / 2
	makePart(
		"WallBack",
		Vector3.new(gateL, WALL_H, 1),
		origin * CFrame.new(gateL / 2, WALL_H / 2, depth),
		WALL,
		shell
	)
	makePart(
		"WallBack",
		Vector3.new(width - gateR, WALL_H, 1),
		origin * CFrame.new(gateR + (width - gateR) / 2, WALL_H / 2, depth),
		WALL,
		shell
	)
	makePart(
		"WallBack",
		Vector3.new(GATE_W, WALL_H - 6.5, 1),
		origin * CFrame.new(width / 2, 6.5 + (WALL_H - 6.5) / 2, depth),
		WALL,
		shell
	)
	for _, fx in { 0.22, 0.78 } do
		makeWindow(shell, origin * CFrame.new(width * fx, 4.6, depth - 0.55))
	end

	-- Garden gate (auto-door, swings into the garden).
	makeDoor(
		"G" .. plot.index,
		shell,
		origin * CFrame.new(width / 2, 3.2, depth),
		GATE_W - 0.3,
		6.3,
		Color3.fromRGB(112, 78, 55),
		100
	)

	-- Picket fence around the garden (low — players can hop it, NPCs won't path over).
	local fenceColor = CREAM
	local gardenDepth = TOTAL_DEPTH - depth
	local function fenceRun(centerCf: CFrame, length: number, alongX: boolean)
		for _, y in { 0.9, 2 } do
			makePart(
				"FenceRail",
				if alongX then Vector3.new(length, 0.3, 0.25) else Vector3.new(0.25, 0.3, length),
				centerCf * CFrame.new(0, y, 0),
				fenceColor,
				shell,
				Enum.Material.Wood
			)
		end
		local posts = math.max(2, math.floor(length / 8))
		for i = 0, posts do
			local along = -length / 2 + (length / posts) * i
			makePart(
				"FencePost",
				Vector3.new(0.45, 2.6, 0.45),
				centerCf * CFrame.new(if alongX then along else 0, 1.3, if alongX then 0 else along),
				fenceColor,
				shell,
				Enum.Material.Wood
			)
		end
		local boundary = makePart(
			"GardenBoundary",
			if alongX
				then Vector3.new(length, World.gardenBoundaryHeight, 0.35)
				else Vector3.new(0.35, World.gardenBoundaryHeight, length),
			centerCf * CFrame.new(0, World.gardenBoundaryHeight / 2, 0),
			fenceColor,
			shell
		)
		boundary.Transparency = 1
		boundary.CanQuery = false
		boundary.CanTouch = false
	end
	fenceRun(origin * CFrame.new(0, 0, depth + gardenDepth / 2), gardenDepth, false)
	fenceRun(origin * CFrame.new(width, 0, depth + gardenDepth / 2), gardenDepth, false)
	fenceRun(origin * CFrame.new(width / 2, 0, TOTAL_DEPTH), width, true)

	-- Garden charm: stone path from the gate, then the owner's Creator Store
	-- dressing (trees/flowers/hedges/bench/lantern) when loaded — procedural
	-- tree + flower beds as the fallback.
	for i = 1, 3 do
		makePart(
			"GardenPath",
			Vector3.new(2.6, 0.2, 2),
			origin * CFrame.new(width / 2, 0.1, depth + i * 3 - 1),
			Color3.fromRGB(190, 180, 165),
			shell,
			Enum.Material.Slate
		)
	end

	-- Drop a world-decor clone with its bounding box resting on the floor.
	local function placeWorld(key: string, localX: number, localZ: number, yaw: number?): boolean
		local m: Model? = if AssetLibraryService then AssetLibraryService:GetWorld(key) else nil
		if not m then
			return false
		end
		m.Name = "Garden_" .. key
		local _, size = m:GetBoundingBox()
		local worldCf = origin * CFrame.new(localX, size.Y / 2, localZ)
		m:PivotTo(
			CFrame.new(worldCf.Position)
				* CFrame.Angles(0, math.rad(yaw or 0), 0)
				* (origin - origin.Position)
		)
		m.Parent = shell
		return true
	end

	local g = gardenDepth
	if not placeWorld("tree", 10, depth + g * 0.55) then
		makePart(
			"GardenTrunk",
			Vector3.new(1.2, 5, 1.2),
			origin * CFrame.new(10, 2.5, depth + g * 0.55),
			Color3.fromRGB(110, 82, 60),
			shell,
			Enum.Material.Wood
		)
		local canopy = makePart(
			"GardenCanopy",
			Vector3.new(6.5, 6.5, 6.5),
			origin * CFrame.new(10, 6.6, depth + g * 0.55),
			Color3.fromRGB(105, 150, 88),
			shell,
			Enum.Material.Grass
		)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
	end
	placeWorld("tree", width - 10, depth + g * 0.8)

	for bi, bx in { width - 12, 16 } do
		local bedZ = depth + g * (if bi == 1 then 0.35 else 0.75)
		if not placeWorld("flowers", bx, bedZ) then
			makePart(
				"FlowerBed",
				Vector3.new(2.6, 0.8, 2.6),
				origin * CFrame.new(bx, 0.4, bedZ),
				Color3.fromRGB(185, 115, 90),
				shell,
				Enum.Material.Concrete
			)
			for fi, fc in { Color3.fromRGB(220, 90, 90), Color3.fromRGB(240, 200, 90) } do
				local bloom = makePart(
					"Flower",
					Vector3.new(0.9, 0.9, 0.9),
					origin * CFrame.new(bx + (fi - 1.5) * 1.1, 1.2, bedZ),
					fc,
					shell,
					Enum.Material.Grass
				)
				bloom.Shape = Enum.PartType.Ball
				bloom.CanCollide = false
			end
		end
	end

	-- Store-only extras (no procedural equivalent): hedges along the fences,
	-- a garden bench and a lantern.
	for _, hz in { 0.25, 0.55, 0.85 } do
		placeWorld("hedge", 4, depth + g * hz)
		placeWorld("hedge", width - 4, depth + g * hz)
	end
	placeWorld("garden_bench", width / 2 + 12, depth + 9, 180)
	placeWorld("lantern", width / 2 - 14, depth + 7)

	shell.Parent = plot.model
	plot.shell = shell
	plot.tier = tier
end

-- ————— per-plot static build: facade, door, sign, awning —————

local function buildPlot(index: number, parent: Instance): Plot
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local origin = plotOriginFor(index)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("plotIndex", index)
	-- Clients read this to know whether their character is INSIDE this plot
	-- (the camera only x-rays the café you are actually in).
	model:SetAttribute("origin", origin)

	-- FRONT FACADE: two wall segments + lintel around a centred door gap.
	local gapL = width / 2 - DOOR_W / 2
	local gapR = width / 2 + DOOR_W / 2
	makePart(
		"WallFront",
		Vector3.new(gapL, WALL_H, 1),
		origin * CFrame.new(gapL / 2, WALL_H / 2, 0),
		WALL,
		model
	)
	makePart(
		"WallFront",
		Vector3.new(width - gapR, WALL_H, 1),
		origin * CFrame.new(gapR + (width - gapR) / 2, WALL_H / 2, 0),
		WALL,
		model
	)
	makePart(
		"WallFront",
		Vector3.new(DOOR_W, WALL_H - DOOR_H, 1),
		origin * CFrame.new(width / 2, DOOR_H + (WALL_H - DOOR_H) / 2, 0),
		WALL,
		model
	)
	for _, wx in { 15, width - 15 } do
		makeWindow(model, origin * CFrame.new(wx, 4.6, -0.55))
	end

	-- The FRONT DOOR: swings inward for anyone approaching, closes behind them.
	makeDoor(
		"F" .. index,
		model,
		origin * CFrame.new(width / 2, DOOR_H / 2 - 0.05, 0),
		DOOR_W - 0.4,
		DOOR_H - 0.25,
		Color3.fromRGB(112, 78, 55),
		-100
	)

	-- Sign above the door: the café's name + Buzz, readable from the street.
	local sign = makePart(
		"Sign",
		Vector3.new(width, 2, 0.5),
		origin * CFrame.new(width / 2, WALL_H + 1, 0),
		TEAL,
		model
	)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SignGui"
	gui.Size = UDim2.fromScale(12, 2.4)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 248, 235)
	label.TextStrokeTransparency = 0.4
	label.Text = "Empty Café"
	label.Parent = gui

	-- Striped awning over the door line (fixed height — walls are much taller
	-- now, so it hangs at human scale instead of tracking the wall top).
	for i = 0, 7 do
		local slat = makePart(
			"AwningSlat",
			Vector3.new(width / 8, 0.25, 3.4),
			origin
				* CFrame.new(width / 16 + i * (width / 8), DOOR_H + 1.5, -0.9)
				* CFrame.Angles(math.rad(-12), 0, 0),
			if i % 2 == 0 then CORAL else CREAM,
			model,
			Enum.Material.Fabric
		)
		slat.CanCollide = false
	end

	-- Warm interior glow so open cafés shine at golden hour.
	local glowAnchor = makePart(
		"InteriorGlow",
		Vector3.new(0.4, 0.4, 0.4),
		origin * CFrame.new(width / 2, WALL_H - 1.6, 14),
		Color3.fromRGB(255, 220, 170),
		model
	)
	glowAnchor.Transparency = 1
	glowAnchor.CanCollide = false
	local interiorLight = Instance.new("PointLight")
	interiorLight.Color = Color3.fromRGB(255, 214, 160)
	interiorLight.Range = 24
	interiorLight.Brightness = 0.65
	interiorLight.Parent = glowAnchor

	-- Doormat pad at the café front; the client attaches a "Visit Café" prompt.
	local pad = makePart(
		"VisitPad",
		Vector3.new(6, 0.3, 3),
		origin * CFrame.new(width / 2, 0.15, -2.5),
		TEAL,
		model,
		Enum.Material.Fabric
	)
	pad:SetAttribute("plotIndex", index)

	local furnitureFolder = Instance.new("Folder")
	furnitureFolder.Name = "Furniture"
	furnitureFolder.Parent = model

	model.Parent = parent

	local plot: Plot = {
		index = index,
		origin = origin,
		model = model,
		furnitureFolder = furnitureFolder,
		ownerLabel = label,
		ownerUserId = nil,
		shell = nil,
		tier = -1,
	}
	rebuildShell(plot, 0)
	return plot
end

-- Warm golden-hour pass: the street should feel like a Mediterranean evening.
local function applyLighting()
	Lighting.ClockTime = 16.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(140, 120, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 130, 110)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 200, 150)
	Lighting.ColorShift_Bottom = Color3.fromRGB(200, 160, 130)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	-- The approved Store sky is one square decal, not a six-face cubemap. A
	-- single decal cannot be assigned to Skybox* without producing gray faces;
	-- buildSkyBackdrop uses it on distant tiled scenery instead.
	local brokenSky = Lighting:FindFirstChild("ApprovedCafeSky")
	if brokenSky then
		brokenSky:Destroy()
	end

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.35
	atmo.Offset = 0.4
	atmo.Color = Color3.fromRGB(214, 180, 150)
	atmo.Decay = Color3.fromRGB(120, 90, 70)
	atmo.Glare = 0.25
	atmo.Haze = 1.6
	atmo.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 32
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function buildSkyBackdrop(parent: Instance)
	local old = parent:FindFirstChild("SkyBackdrop")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SkyBackdrop"
	folder.Parent = parent

	local plotWidth = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local streetLength = (PLOTS_PER_ROW - 1) * PLOT_SPACING + plotWidth
	local centreX = streetLength / 2
	local centreZ = -World.boulevardWidth / 2
	-- Keep the approved cloud image close enough to read from the isometric
	-- gameplay camera. It remains beyond every playable plot and is non-solid.
	local spanX = streetLength + 500
	local spanZ = World.boulevardWidth + 2 * TOTAL_DEPTH + 500
	local height = 500
	local image = Graphics.Surfaces.Sky

	local function backdrop(name: string, size: Vector3, cf: CFrame, face: Enum.NormalId)
		local wall = makePart(
			name,
			size,
			cf,
			Color3.fromRGB(110, 190, 225),
			folder,
			Enum.Material.SmoothPlastic
		)
		wall.CanCollide = false
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		local texture = Instance.new("Texture")
		texture.Name = "ApprovedClouds"
		texture.Face = face
		texture.Texture = image
		texture.StudsPerTileU = 420
		texture.StudsPerTileV = 420
		texture.Parent = wall
	end

	local northZ = centreZ + spanZ / 2
	local southZ = centreZ - spanZ / 2
	local eastX = centreX + spanX / 2
	local westX = centreX - spanX / 2
	backdrop(
		"CloudsNorth",
		Vector3.new(spanX, height, 2),
		CFrame.new(centreX, height / 2 - 60, northZ),
		Enum.NormalId.Front
	)
	backdrop(
		"CloudsSouth",
		Vector3.new(spanX, height, 2),
		CFrame.new(centreX, height / 2 - 60, southZ),
		Enum.NormalId.Back
	)
	backdrop(
		"CloudsEast",
		Vector3.new(2, height, spanZ),
		CFrame.new(eastX, height / 2 - 60, centreZ),
		Enum.NormalId.Left
	)
	backdrop(
		"CloudsWest",
		Vector3.new(2, height, spanZ),
		CFrame.new(westX, height / 2 - 60, centreZ),
		Enum.NormalId.Right
	)
end

-- A real two-lane boulevard with tiled sidewalks. The Store road images are
-- square modules, so each road tile is rotated as a part to align the painted
-- lane with the long X axis. Turn modules bookend the street.
local function buildRoadNetwork(parent: Instance)
	local old = parent:FindFirstChild("RoadNetwork")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "RoadNetwork"
	folder.Parent = parent

	local plotWidth = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local streetLength = (PLOTS_PER_ROW - 1) * PLOT_SPACING + plotWidth
	local tileSize = 24
	local firstX = -48
	local lastX = streetLength + 48
	local tileCount = math.floor((lastX - firstX) / tileSize) + 1
	for index = 0, tileCount - 1 do
		local image = if index == 0
			then Graphics.Surfaces.RoadLeft
			elseif index == tileCount - 1 then Graphics.Surfaces.RoadRight
			else Graphics.Surfaces.RoadStraight
		local road = makePart(
			if index == 0
				then "RoadTurnLeft"
				elseif index == tileCount - 1 then "RoadTurnRight"
				else "RoadStraight",
			Vector3.new(tileSize, 0.24, tileSize),
			CFrame.new(firstX + index * tileSize, -0.34, -World.boulevardWidth / 2)
				* CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(255, 255, 255),
			folder,
			Enum.Material.SmoothPlastic
		)
		applyTopTexture(road, image, tileSize, tileSize)
	end

	local sidewalkWidth = (World.boulevardWidth - tileSize) / 2
	local totalLength = lastX - firstX + tileSize
	local centreX = (firstX + lastX) / 2
	for _, z in
		{
			-sidewalkWidth / 2,
			-World.boulevardWidth + sidewalkWidth / 2,
		}
	do
		local sidewalk = makePart(
			"Sidewalk",
			Vector3.new(totalLength, 0.3, sidewalkWidth),
			CFrame.new(centreX, -0.28, z),
			Color3.fromRGB(205, 205, 200),
			folder,
			Enum.Material.Concrete
		)
		applyTopTexture(sidewalk, Graphics.Surfaces.Sidewalk, 10, 10)
	end
end

-- Street furniture: the owner's Creator Store picks when loaded (lampposts,
-- trees, mailboxes, hydrants), greybox lamps/trees as the fallback.
local function buildStreetDecor(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "StreetDecor"
	folder.Parent = parent

	local function placeWorld(key: string, x: number, y0: number, z: number): boolean
		local m: Model? = if AssetLibraryService then AssetLibraryService:GetWorld(key) else nil
		if not m then
			return false
		end
		m.Name = "Street_" .. key
		local _, size = m:GetBoundingBox()
		m:PivotTo(CFrame.new(x, y0 + size.Y / 2, z))
		m.Parent = folder
		return true
	end

	for i = 0, PLOTS_PER_ROW do
		local x = i * PLOT_SPACING - 6
		for _, lampZ in { -18, -(World.boulevardWidth - 18) } do
			if not placeWorld("street_lamp", x, -0.5, lampZ) then
				local pole = makePart(
					"LampPole",
					Vector3.new(0.6, 7, 0.6),
					CFrame.new(x, 3, lampZ),
					Color3.fromRGB(70, 60, 55),
					folder,
					Enum.Material.Metal
				)
				local head = makePart(
					"LampHead",
					Vector3.new(1.4, 1.4, 1.4),
					CFrame.new(x, 7, lampZ),
					Color3.fromRGB(255, 214, 150),
					folder,
					Enum.Material.Neon
				)
				head.Shape = Enum.PartType.Ball
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 205, 140)
				light.Range = 22
				light.Brightness = 1.1
				light.Parent = head
				pole.Name = "LampPole_" .. i
			end
		end
		-- Sidewalk accents between every few cafés.
		if i % 3 == 1 then
			placeWorld("mailbox", x + 10, -0.5, -14)
		end
		if i % 4 == 2 then
			placeWorld("hydrant", x + 10, -0.5, -(World.boulevardWidth - 14))
		end
	end

	for i = 1, 4 do
		local x = (i - 0.5) * (PLOTS_PER_ROW * PLOT_SPACING) / 4 - 12
		local z = -44
		if not placeWorld("tree", x, -0.5, z) then
			makePart(
				"Trunk",
				Vector3.new(1.4, 5, 1.4),
				CFrame.new(x, 2, z),
				Color3.fromRGB(110, 82, 60),
				folder,
				Enum.Material.Wood
			)
			local canopy = makePart(
				"Canopy",
				Vector3.new(7, 7, 7),
				CFrame.new(x, 6.4, z),
				Color3.fromRGB(105, 150, 88),
				folder,
				Enum.Material.Grass
			)
			canopy.Shape = Enum.PartType.Ball
		end
	end
end

-- Central plaza: paved circle, fountain, benches, planters, and the
-- neighbourhood board — the social heart of the street (master plan §19).
local function buildPlaza(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = parent

	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local midX = ((PLOTS_PER_ROW - 1) * PLOT_SPACING + width) / 2
	local plazaZ = -World.boulevardWidth / 2
	local centre = Vector3.new(midX, 0, plazaZ)

	local disc = makePart(
		"PlazaFloor",
		Vector3.new(0.5, 30, 30),
		CFrame.new(midX, -0.25, plazaZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(205, 185, 160),
		folder,
		Enum.Material.Cobblestone
	)
	disc.Shape = Enum.PartType.Cylinder

	-- The owner's plaza fountain when loaded; the greybox tiers otherwise.
	local libFountain: Model? = if AssetLibraryService
		then AssetLibraryService:GetWorld("fountain")
		else nil
	if libFountain then
		libFountain.Name = "PlazaFountain"
		local _, fSize = libFountain:GetBoundingBox()
		libFountain:PivotTo(CFrame.new(midX, fSize.Y / 2 - 0.4, plazaZ))
		libFountain.Parent = folder
	else
		local base = makePart(
			"FountainBase",
			Vector3.new(1.2, 10, 10),
			CFrame.new(midX, 0.6, plazaZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(180, 170, 155),
			folder,
			Enum.Material.Slate
		)
		base.Shape = Enum.PartType.Cylinder
		local water = makePart(
			"FountainWater",
			Vector3.new(0.4, 8.6, 8.6),
			CFrame.new(midX, 1.1, plazaZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(120, 175, 200),
			folder,
			Enum.Material.Glass
		)
		water.Shape = Enum.PartType.Cylinder
		water.Transparency = 0.35
		makePart(
			"FountainColumn",
			Vector3.new(1.6, 3, 1.6),
			CFrame.new(midX, 2.4, plazaZ),
			Color3.fromRGB(180, 170, 155),
			folder,
			Enum.Material.Slate
		)
		local bowl = makePart(
			"FountainBowl",
			Vector3.new(0.6, 4, 4),
			CFrame.new(midX, 4, plazaZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(180, 170, 155),
			folder,
			Enum.Material.Slate
		)
		bowl.Shape = Enum.PartType.Cylinder
	end

	for angle = 0, 270, 90 do
		local rot = CFrame.new(centre) * CFrame.Angles(0, math.rad(angle + 45), 0)
		makePart(
			"BenchSeat",
			Vector3.new(5, 0.5, 1.6),
			rot * CFrame.new(0, 0.85, 11),
			Color3.fromRGB(150, 110, 80),
			folder,
			Enum.Material.WoodPlanks
		)
		makePart(
			"BenchBack",
			Vector3.new(5, 1.4, 0.3),
			rot * CFrame.new(0, 1.7, 11.8),
			Color3.fromRGB(150, 110, 80),
			folder,
			Enum.Material.WoodPlanks
		)
		local planter = makePart(
			"Planter",
			Vector3.new(2, 1, 2),
			CFrame.new(centre) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0.5, 13),
			Color3.fromRGB(185, 115, 90),
			folder,
			Enum.Material.Concrete
		)
		local bush = makePart(
			"Bush",
			Vector3.new(2.2, 2.2, 2.2),
			planter.CFrame * CFrame.new(0, 1.4, 0),
			Color3.fromRGB(110, 155, 92),
			folder,
			Enum.Material.Grass
		)
		bush.Shape = Enum.PartType.Ball
	end

	local board = makePart(
		"NeighbourhoodBoard",
		Vector3.new(8, 4, 0.4),
		CFrame.new(midX, 3.4, plazaZ - 16) * CFrame.Angles(0, math.rad(180), 0),
		Color3.fromRGB(120, 90, 70),
		folder,
		Enum.Material.Wood
	)
	makePart(
		"BoardLegL",
		Vector3.new(0.5, 3.4, 0.5),
		CFrame.new(midX - 3.5, 1.7, plazaZ - 16),
		Color3.fromRGB(100, 75, 58),
		folder,
		Enum.Material.Wood
	)
	makePart(
		"BoardLegR",
		Vector3.new(0.5, 3.4, 0.5),
		CFrame.new(midX + 3.5, 1.7, plazaZ - 16),
		Color3.fromRGB(100, 75, 58),
		folder,
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 400)
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 246, 232)
	text.Text =
		"🏘️ Neighbourhood Board\nVisit your neighbours — leave a compliment!\nCommunity goals coming soon"
	text.TextWrapped = true
	text.Parent = gui

	-- Clients read this to detect "player reached the plaza" (tutorial).
	workspace:SetAttribute("PlazaCenter", centre)
end

-- Unowned cafés read as CLOSED: wooden shutters across the facade and a dark
-- interior. Claiming a plot visibly "opens" the café.
local function buildShutter(plot: Plot): Model
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local shutter = Instance.new("Model")
	shutter.Name = "ClosedShutter"

	makePart(
		"ShutterPanel",
		Vector3.new(width - 1, 5.4, 0.6),
		plot.origin * CFrame.new(width / 2, 2.7, -0.9),
		Color3.fromRGB(139, 112, 82),
		shutter,
		Enum.Material.WoodPlanks
	)
	for i = 0, 5 do
		makePart(
			"ShutterSlat",
			Vector3.new(width - 1, 0.18, 0.68),
			plot.origin * CFrame.new(width / 2, 0.9 + i * 0.9, -0.9),
			Color3.fromRGB(112, 88, 62),
			shutter,
			Enum.Material.Wood
		)
	end
	local board = makePart(
		"ClosedBoard",
		Vector3.new(6, 2.2, 0.3),
		plot.origin * CFrame.new(width / 2, 4, -1.4),
		Color3.fromRGB(96, 70, 52),
		shutter,
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 160)
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 236, 190)
	text.Text = "CLOSED\nOpening soon…"
	text.Parent = gui

	shutter.Parent = plot.model
	return shutter
end

local function setPlotClosed(plot: Plot)
	plot.ownerLabel.Text = "Opening soon…"
	if plot.shutter == nil then
		plot.shutter = buildShutter(plot)
	end
end

local function setPlotOpen(plot: Plot, player: Player)
	plot.ownerLabel.Text = player.DisplayName .. "'s Café"
	if plot.shutter then
		plot.shutter:Destroy()
		plot.shutter = nil
	end
end

function CafeService.GetPlotOrigin(_self: any, player: Player): CFrame?
	local plot = plotByUser[player.UserId]
	return if plot then plot.origin else nil
end

-- Shared service-pass geometry. Kitchen staff use the inside point, while the
-- waiter stays in the dining room and collects the finished dish outside.
function CafeService.GetKitchenPass(_self: any, player: Player): (CFrame?, Vector3?, Vector3?)
	local plot = plotByUser[player.UserId]
	if not plot then
		return nil, nil, nil
	end
	local passX = KITCHEN_W - KITCHEN_PASS_W / 2
	local surface = plot.origin * CFrame.new(passX, KITCHEN_DIVIDER_H + 0.55, KITCHEN_D + 0.15)
	local kitchenSide = (plot.origin * CFrame.new(passX, 2, KITCHEN_D - 3.5)).Position
	local diningSide = (plot.origin * CFrame.new(passX, 2, KITCHEN_D + 3.5)).Position
	return surface, kitchenSide, diningSide
end

function CafeService.GetFurnitureFolder(_self: any, player: Player): Folder?
	local plot = plotByUser[player.UserId]
	return if plot then plot.furnitureFolder else nil
end

-- The café sign doubles as the Buzz scoreboard (KitchenService drives it).
function CafeService.SetSignBuzz(_self: any, player: Player, buzz: number)
	local plot = plotByUser[player.UserId]
	if plot then
		plot.ownerLabel.Text = player.DisplayName .. "'s Café\n🔥 Buzz " .. tostring(buzz)
	end
end

-- Plot lookup by street index, for SocialService (visits/compliments).
function CafeService.GetPlotInfo(_self: any, index: number): (CFrame?, number?)
	local plot = plots[index]
	if not plot then
		return nil, nil
	end
	return plot.origin, plot.ownerUserId
end

-- Shared proximity guard for interactions that must happen at your own café.
-- Rect-based (distance to the plot rectangle), NOT distance-to-centre: on the
-- deep S2 plots the centre is ~70 studs from the front counters.
function CafeService.IsNearOwnPlot(_self: any, player: Player, maxDistance: number): boolean
	local plot = plotByUser[player.UserId]
	local character = player.Character
	if not plot or not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return false
	end
	return Grid.distanceToPlotRect(plot.origin, hrp.Position) <= maxDistance
end

-- Re-read the owner's expansionTier and rebuild the shell if it changed.
-- Called on join (after data load) and by the S4 buy-land flow.
function CafeService.RefreshTier(_self: any, player: Player)
	local plot = plotByUser[player.UserId]
	if not plot then
		return
	end
	local data = DataService:GetProfile(player)
	local tier = if data then math.max(0, math.floor(tonumber(data.expansionTier) or 0)) else 0
	if plot.tier ~= tier then
		rebuildShell(plot, tier)
	end
	player:SetAttribute("ExpansionTier", tier)
end

local function assignPlot(player: Player): Plot?
	for _, plot in plots do
		if plot.ownerUserId == nil then
			plot.ownerUserId = player.UserId
			setPlotOpen(plot, player)
			plotByUser[player.UserId] = plot
			-- Clients read these to find their own plot (placement, appliances).
			player:SetAttribute("PlotOrigin", plot.origin)
			plot.model:SetAttribute("ownerUserId", player.UserId)
			return plot
		end
	end
	return nil
end

local function teleportOnto(plot: Plot, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	-- Players never collide with NPCs (walk through your own queue freely).
	NpcNav.assignPlayerGroup(character)
	if hrp and hrp:IsA("BasePart") then
		-- Arrive on the street IN FRONT of your own café, facing the door —
		-- the "this is my restaurant" moment (owner request).
		local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
		local standAt = (plot.origin * CFrame.new(width / 2, 4, -8)).Position
		local lookAt = (plot.origin * CFrame.new(width / 2, 4, 10)).Position
		hrp.CFrame = CFrame.lookAt(standAt, lookAt)
	end
end

local function onPlayerAdded(player: Player)
	-- Idempotent: guard against PlayerAdded firing alongside the catch-up loop,
	-- which would otherwise assign the same player a second plot.
	if plotByUser[player.UserId] then
		return
	end
	local plot = assignPlot(player)
	if not plot then
		Log.warn("No free plot for", player.Name, "- server full")
		return
	end

	local tries = 0
	while not DataService:IsLoaded(player) and tries < 200 do
		task.wait(0.1)
		tries += 1
	end
	CafeService:RefreshTier(player)
	BuildService:RenderProfile(player)

	if player.Character then
		task.spawn(teleportOnto, plot, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		teleportOnto(plot, character)
	end)
end

local function onPlayerRemoving(player: Player)
	jumpStates[player] = nil
	local plot = plotByUser[player.UserId]
	if plot then
		plot.ownerUserId = nil
		plot.furnitureFolder:ClearAllChildren()
		plot.model:SetAttribute("ownerUserId", nil)
		if plot.tier ~= 0 then
			rebuildShell(plot, 0)
		end
		setPlotClosed(plot)
		plotByUser[player.UserId] = nil
	end
end

-- Hang the neon "Coffee Cup" sign on the café's exterior facade, above the
-- door, facing the street. Called from the OnReady redress (the mesh isn't
-- loaded when the static facade first builds).
local function placeCafeSign(plot: Plot)
	if not AssetLibraryService then
		return
	end
	local existing = plot.model:FindFirstChild("CafeSign")
	if existing then
		existing:Destroy()
	end
	local sign = AssetLibraryService:GetDecor("cafe_sign")
	if not sign then
		return
	end
	sign.Name = "CafeSign"
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	for _, d in sign:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	-- Native sign is flat (thin Y); stand it upright on the wall facing -Z.
	sign:PivotTo(
		plot.origin * CFrame.new(width / 2, DOOR_H + 3, -0.7) * CFrame.Angles(math.rad(90), 0, 0)
	)
	sign.Parent = plot.model
end

function CafeService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	BuildService = ServiceRegistry.get("BuildService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
end

function CafeService.Start(_self: any)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	for i = 1, NUM_PLOTS do
		plots[i] = buildPlot(i, plotsFolder)
		setPlotClosed(plots[i]) -- every café starts shuttered until claimed
	end

	-- Shared street ground so nobody falls into the void: spans both rows
	-- (café + garden) and the boulevard between them.
	local depthSpan = World.boulevardWidth + 2 * TOTAL_DEPTH + 80
	local ground = Instance.new("Part")
	ground.Name = "StreetGround"
	ground.Anchored = true
	ground.Size = Vector3.new(PLOTS_PER_ROW * PLOT_SPACING + 80, 1, depthSpan)
	ground.CFrame = CFrame.new(
		(PLOTS_PER_ROW * PLOT_SPACING) / 2 - PLOT_SPACING / 2,
		-1,
		-World.boulevardWidth / 2
	)
	ground.Color = Color3.fromRGB(158, 158, 148)
	ground.Material = Enum.Material.Concrete
	ground.Parent = workspace
	worldSafetyCenter = ground.Position
	worldSafetySize = ground.Size

	local boundary = Instance.new("Folder")
	boundary.Name = "WorldBoundary"
	boundary.Parent = workspace
	local height = World.mapBoundaryHeight
	local thickness = 4
	for _, wall in
		{
			{
				name = "West",
				size = Vector3.new(thickness, height, ground.Size.Z + thickness * 2),
				cf = CFrame.new(
					ground.Position.X - ground.Size.X / 2,
					height / 2 - 1,
					ground.Position.Z
				),
			},
			{
				name = "East",
				size = Vector3.new(thickness, height, ground.Size.Z + thickness * 2),
				cf = CFrame.new(
					ground.Position.X + ground.Size.X / 2,
					height / 2 - 1,
					ground.Position.Z
				),
			},
			{
				name = "North",
				size = Vector3.new(ground.Size.X + thickness * 2, height, thickness),
				cf = CFrame.new(
					ground.Position.X,
					height / 2 - 1,
					ground.Position.Z - ground.Size.Z / 2
				),
			},
			{
				name = "South",
				size = Vector3.new(ground.Size.X + thickness * 2, height, thickness),
				cf = CFrame.new(
					ground.Position.X,
					height / 2 - 1,
					ground.Position.Z + ground.Size.Z / 2
				),
			},
		}
	do
		local part = makePart(wall.name, wall.size, wall.cf, Color3.new(), boundary)
		part.Transparency = 1
		part.CanCollide = true
	end

	applyLighting()
	buildSkyBackdrop(workspace)
	buildRoadNetwork(workspace)
	buildStreetDecor(workspace)
	buildPlaza(workspace)

	-- The door watcher: swings any door whose approach zone has a character in it.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(tickDoors)
			if not ok then
				Log.warn("Door tick failed:", err)
			end
			local jumpOk, jumpErr = pcall(tickIndoorJumpLimits)
			if not jumpOk then
				Log.warn("Indoor jump tick failed:", jumpErr)
			end
			local safetyOk, safetyErr = pcall(tickWorldSafety)
			if not safetyOk then
				Log.warn("World safety tick failed:", safetyErr)
			end
		end
	end)

	-- The street/plaza/gardens build at boot, BEFORE the async asset load
	-- finishes — re-dress everything with the owner's world decor once ready.
	if AssetLibraryService then
		AssetLibraryService:OnReady(function()
			local sd = workspace:FindFirstChild("StreetDecor")
			if sd then
				sd:Destroy()
			end
			buildStreetDecor(workspace)
			local plaza = workspace:FindFirstChild("Plaza")
			if plaza then
				plaza:Destroy()
			end
			buildPlaza(workspace)
			for _, plot in plots do
				rebuildShell(plot, math.max(plot.tier, 0))
				placeCafeSign(plot)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Log.info("CafeService built", NUM_PLOTS, "plots (facade + garden architecture)")
end

return CafeService
