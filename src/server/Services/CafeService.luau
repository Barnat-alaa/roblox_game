--!strict
-- Builds the greybox neighbourhood street of plots, assigns one plot per player,
-- renders their saved furniture, and teleports them in. Each plot exposes a local
-- origin CFrame that the grid system uses for placement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local CafeService = {}
CafeService.Name = "CafeService"

local DataService: any
local BuildService: any

local NUM_PLOTS = 6
local PLOT_SPACING = Grid.PLOT_WIDTH * Grid.CELL_SIZE + 12

type Plot = {
	index: number,
	origin: CFrame,
	model: Model,
	furnitureFolder: Folder,
	ownerLabel: TextLabel,
	ownerUserId: number?,
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
	local origin = CFrame.new((index - 1) * PLOT_SPACING, 0, 0)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index

	makePart(
		"Floor",
		Vector3.new(width, 1, depth),
		origin * CFrame.new(width / 2, -0.5, depth / 2),
		Color3.fromRGB(225, 210, 185),
		model,
		Enum.Material.WoodPlanks
	)

	local wallH = 8
	makePart(
		"WallBack",
		Vector3.new(width, wallH, 1),
		origin * CFrame.new(width / 2, wallH / 2, depth),
		Color3.fromRGB(205, 125, 95),
		model
	)
	makePart(
		"WallLeft",
		Vector3.new(1, wallH, depth),
		origin * CFrame.new(0, wallH / 2, depth / 2),
		Color3.fromRGB(210, 178, 150),
		model
	)
	makePart(
		"WallRight",
		Vector3.new(1, wallH, depth),
		origin * CFrame.new(width, wallH / 2, depth / 2),
		Color3.fromRGB(210, 178, 150),
		model
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

function CafeService.GetPlotOrigin(_self: any, player: Player): CFrame?
	local plot = plotByUser[player.UserId]
	return if plot then plot.origin else nil
end

function CafeService.GetFurnitureFolder(_self: any, player: Player): Folder?
	local plot = plotByUser[player.UserId]
	return if plot then plot.furnitureFolder else nil
end

local function assignPlot(player: Player): Plot?
	for _, plot in plots do
		if plot.ownerUserId == nil then
			plot.ownerUserId = player.UserId
			plot.ownerLabel.Text = player.DisplayName .. "'s Café"
			plotByUser[player.UserId] = plot
			-- Client reads this to compute grid coordinates for placement previews.
			player:SetAttribute("PlotOrigin", plot.origin)
			return plot
		end
	end
	return nil
end

local function teleportOnto(plot: Plot, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp and hrp:IsA("BasePart") then
		local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
		hrp.CFrame = plot.origin * CFrame.new(width / 2, 5, 6)
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
		plot.ownerLabel.Text = "Empty Café"
		plot.furnitureFolder:ClearAllChildren()
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
	end

	-- Shared street ground so nobody falls into the void.
	local ground = Instance.new("Part")
	ground.Name = "StreetGround"
	ground.Anchored = true
	ground.Size = Vector3.new(NUM_PLOTS * PLOT_SPACING + 80, 1, 220)
	ground.CFrame = CFrame.new((NUM_PLOTS * PLOT_SPACING) / 2 - PLOT_SPACING / 2, -1, 60)
	ground.Color = Color3.fromRGB(158, 158, 148)
	ground.Material = Enum.Material.Concrete
	ground.Parent = workspace

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Log.info("CafeService built", NUM_PLOTS, "plots")
end

return CafeService
