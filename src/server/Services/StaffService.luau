--!strict
-- One automated employee (master plan §15 MVP): a barista who stands behind
-- your counter and auto-serves any order left waiting past
-- Economy.staffServeAfterSeconds. She pays out less than serving yourself
-- (staffPayoutMultiplier, half XP), so manual play stays king — but the café
-- keeps running while you build, shop, or visit. Server-authoritative:
-- OrderService.StaffServe owns the grant path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local EconomyConfig = require(Shared.Config.Economy)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local StaffService = {}
StaffService.Name = "StaffService"

local DataService: any
local OrderService: any
local CafeService: any

local CHECK_INTERVAL = 5

type Barista = {
	model: Model,
	bubble: TextLabel,
}

local baristaByUser: { [number]: Barista } = {}

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- Static chibi barista (anchored — she has one job and it isn't walking).
local function buildBarista(origin: CFrame): Barista
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	-- Behind the counter (the seed counter sits on the plot's front row).
	local base = origin * CFrame.new(width / 2 + 4, 0, 2.4) * CFrame.Angles(0, math.rad(180), 0)

	local model = Instance.new("Model")
	model.Name = "Barista"

	part(
		model,
		"Legs",
		Vector3.new(1.7, 1.2, 1),
		base * CFrame.new(0, 0.6, 0),
		Color3.fromRGB(50, 50, 60)
	)
	part(
		model,
		"Torso",
		Vector3.new(2, 2, 1.1),
		base * CFrame.new(0, 2.2, 0),
		Color3.fromRGB(90, 70, 60)
	)
	part(
		model,
		"Apron",
		Vector3.new(1.95, 1.5, 0.15),
		base * CFrame.new(0, 2, -0.62),
		Color3.fromRGB(245, 242, 235)
	)
	local head = part(
		model,
		"Head",
		Vector3.new(2.2, 2.2, 2.2),
		base * CFrame.new(0, 4.25, 0),
		Color3.fromRGB(235, 185, 150),
		Enum.PartType.Ball
	)
	part(
		model,
		"Hair",
		Vector3.new(2.3, 2.3, 2.3),
		base * CFrame.new(0, 4.53, 0.12),
		Color3.fromRGB(90, 55, 35),
		Enum.PartType.Ball
	)
	part(
		model,
		"Bun",
		Vector3.new(0.7, 0.7, 0.7),
		base * CFrame.new(0, 5.4, 0.25),
		Color3.fromRGB(90, 55, 35),
		Enum.PartType.Ball
	)
	for _, x in { -0.38, 0.38 } do
		part(
			model,
			"Eye",
			Vector3.new(0.1, 0.22, 0.22),
			base * CFrame.new(x, 4.37, -1.02) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(35, 30, 28),
			Enum.PartType.Cylinder
		)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromScale(5, 1.4)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "BubbleLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
	label.BackgroundTransparency = 0.25
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 248, 235)
	label.Text = "👩‍🍳 Barista"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	label.Parent = gui

	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "NameTag"
	nameGui.Size = UDim2.fromScale(4, 0.9)
	nameGui.StudsOffset = Vector3.new(0, 3.1, 0)
	nameGui.AlwaysOnTop = true
	nameGui.MaxDistance = 90
	nameGui.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextColor3 = Color3.fromRGB(255, 236, 190)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = "Mia"
	nameLabel.Parent = nameGui

	local staffFolder = workspace:FindFirstChild("Staff")
	if not staffFolder then
		staffFolder = Instance.new("Folder")
		staffFolder.Name = "Staff"
		staffFolder.Parent = workspace
	end
	model.Parent = staffFolder

	return { model = model, bubble = label }
end

local function flashBubble(barista: Barista, text: string)
	barista.bubble.Text = text
	task.delay(2.5, function()
		if barista.bubble.Parent ~= nil then
			barista.bubble.Text = "👩‍🍳 Barista"
		end
	end)
end

function StaffService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	OrderService = ServiceRegistry.get("OrderService")
	CafeService = ServiceRegistry.get("CafeService")
end

function StaffService.Start(_self: any)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) then
					local origin = CafeService:GetPlotOrigin(player)
					if origin then
						if baristaByUser[player.UserId] == nil then
							baristaByUser[player.UserId] = buildBarista(origin)
						end
						local order = OrderService:GetOldestPendingFor(player.UserId)
						if
							order
							and (os.clock() - order.createdAtClock)
								>= EconomyConfig.staffServeAfterSeconds
						then
							if OrderService:StaffServe(order.orderId) then
								flashBubble(baristaByUser[player.UserId], "☕ Coming right up!")
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local barista = baristaByUser[player.UserId]
		if barista then
			barista.model:Destroy()
			baristaByUser[player.UserId] = nil
		end
	end)
end

return StaffService
