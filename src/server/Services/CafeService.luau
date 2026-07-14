--!strict
-- Builds the greybox neighbourhood street of plots, assigns one plot per player,
-- renders their saved furniture, and teleports them in. Each plot exposes a local
-- origin CFrame that the grid system uses for placement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local World = require(Shared.Config.World)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local CafeService = {}
CafeService.Name = "CafeService"

local DataService: any
local BuildService: any

local NUM_PLOTS = World.plotCount
local PLOTS_PER_ROW = World.plotsPerRow
local PLOT_SPACING = Grid.PLOT_WIDTH * Grid.CELL_SIZE + 12

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
}

local plots: { Plot } = {}
local plotByUser: { [number]: Plot } = {}

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

local function buildPlot(index: number, parent: Instance): Plot
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local depth = Grid.PLOT_DEPTH * Grid.CELL_SIZE
	local origin = plotOriginFor(index)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("plotIndex", index)

	-- Warm oak planks + deep maroon walls: the cosy interior read of the
	-- classic café sims (see docs/ART_DIRECTION.md).
	makePart(
		"Floor",
		Vector3.new(width, 1, depth),
		origin * CFrame.new(width / 2, -0.5, depth / 2),
		Color3.fromRGB(176, 132, 90),
		model,
		Enum.Material.WoodPlanks
	)

	local wallH = 8
	makePart(
		"WallBack",
		Vector3.new(width, wallH, 1),
		origin * CFrame.new(width / 2, wallH / 2, depth),
		Color3.fromRGB(150, 60, 50),
		model
	)
	makePart(
		"WallLeft",
		Vector3.new(1, wallH, depth),
		origin * CFrame.new(0, wallH / 2, depth / 2),
		Color3.fromRGB(158, 70, 58),
		model
	)
	makePart(
		"WallRight",
		Vector3.new(1, wallH, depth),
		origin * CFrame.new(width, wallH / 2, depth / 2),
		Color3.fromRGB(158, 70, 58),
		model
	)

	-- White-framed windows + a wooden door on the back wall.
	for _, fx in { 0.25, 0.72 } do
		makePart(
			"WindowFrame",
			Vector3.new(4.4, 3.6, 0.4),
			origin * CFrame.new(width * fx, 4.6, depth - 0.55),
			Color3.fromRGB(245, 242, 235),
			model
		)
		local glass = makePart(
			"WindowGlass",
			Vector3.new(3.6, 2.8, 0.3),
			origin * CFrame.new(width * fx, 4.6, depth - 0.62),
			Color3.fromRGB(170, 210, 230),
			model,
			Enum.Material.Glass
		)
		glass.Transparency = 0.15
	end
	makePart(
		"Door",
		Vector3.new(3.2, 5.6, 0.4),
		origin * CFrame.new(width * 0.5, 2.8, depth - 0.55),
		Color3.fromRGB(112, 78, 55),
		model,
		Enum.Material.Wood
	)

	local sign = makePart(
		"Sign",
		Vector3.new(width, 2, 0.5),
		origin * CFrame.new(width / 2, wallH + 1, depth),
		Color3.fromRGB(120, 90, 70),
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

	-- Doormat pad at the café front; the client attaches a "Visit Café" prompt.
	local pad = makePart(
		"VisitPad",
		Vector3.new(6, 0.3, 3),
		origin * CFrame.new(width / 2, 0.15, -2.5),
		Color3.fromRGB(196, 152, 112),
		model,
		Enum.Material.Fabric
	)
	pad:SetAttribute("plotIndex", index)

	local furnitureFolder = Instance.new("Folder")
	furnitureFolder.Name = "Furniture"
	furnitureFolder.Parent = model

	model.Parent = parent

	return {
		index = index,
		origin = origin,
		model = model,
		furnitureFolder = furnitureFolder,
		ownerLabel = label,
		ownerUserId = nil,
	}
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

-- Lamp posts and trees give the greybox street a silhouette.
local function buildStreetDecor(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "StreetDecor"
	folder.Parent = parent

	for i = 0, PLOTS_PER_ROW do
		local x = i * PLOT_SPACING - 6
		for _, lampZ in { -18, -(World.boulevardWidth - 18) } do
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

	for i = 1, 4 do
		local x = (i - 0.5) * (PLOTS_PER_ROW * PLOT_SPACING) / 4 - 12
		local z = -44
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
	local column = makePart(
		"FountainColumn",
		Vector3.new(1.6, 3, 1.6),
		CFrame.new(midX, 2.4, plazaZ),
		Color3.fromRGB(180, 170, 155),
		folder,
		Enum.Material.Slate
	)
	column.Name = "FountainColumn"
	local bowl = makePart(
		"FountainBowl",
		Vector3.new(0.6, 4, 4),
		CFrame.new(midX, 4, plazaZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(180, 170, 155),
		folder,
		Enum.Material.Slate
	)
	bowl.Shape = Enum.PartType.Cylinder

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

-- Unowned cafés read as CLOSED: wooden shutters across the open front and a
-- dark interior. Claiming a plot visibly "opens" the café — lobbies feel
-- alive with real neighbours instead of identical empty boxes.
local function buildShutter(plot: Plot): Model
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local shutter = Instance.new("Model")
	shutter.Name = "ClosedShutter"

	makePart(
		"ShutterPanel",
		Vector3.new(width - 1, 5.4, 0.6),
		plot.origin * CFrame.new(width / 2, 2.7, 0.4),
		Color3.fromRGB(139, 112, 82),
		shutter,
		Enum.Material.WoodPlanks
	)
	for i = 0, 5 do
		makePart(
			"ShutterSlat",
			Vector3.new(width - 1, 0.18, 0.68),
			plot.origin * CFrame.new(width / 2, 0.9 + i * 0.9, 0.4),
			Color3.fromRGB(112, 88, 62),
			shutter,
			Enum.Material.Wood
		)
	end
	local board = makePart(
		"ClosedBoard",
		Vector3.new(6, 2.2, 0.3),
		plot.origin * CFrame.new(width / 2, 4, -0.1),
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
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local depth = Grid.PLOT_DEPTH * Grid.CELL_SIZE
	local centre = (plot.origin * CFrame.new(width / 2, 0, depth / 2)).Position
	return (hrp.Position - centre).Magnitude <= maxDistance
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
	if hrp and hrp:IsA("BasePart") then
		-- Arrive on the street IN FRONT of your own café, facing it —
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
	BuildService:RenderProfile(player)

	if player.Character then
		task.spawn(teleportOnto, plot, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		teleportOnto(plot, character)
	end)
end

local function onPlayerRemoving(player: Player)
	local plot = plotByUser[player.UserId]
	if plot then
		plot.ownerUserId = nil
		plot.furnitureFolder:ClearAllChildren()
		plot.model:SetAttribute("ownerUserId", nil)
		setPlotClosed(plot)
		plotByUser[player.UserId] = nil
	end
end

function CafeService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	BuildService = ServiceRegistry.get("BuildService")
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
	-- and the boulevard between them.
	local depthSpan = World.boulevardWidth + 2 * Grid.PLOT_DEPTH * Grid.CELL_SIZE + 80
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

	applyLighting()
	buildStreetDecor(workspace)
	buildPlaza(workspace)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Log.info("CafeService built", NUM_PLOTS, "plots")
end

return CafeService
