--!strict
-- Walk-in customer NPCs v3: a visible waiting LINE at the service window.
-- Up to MAX_QUEUE customers per café queue on the street side; only the
-- front customer places an order (OrderService still owns rewards), and the
-- whole line steps forward on every serve/cancel. Each customer rolls one of
-- eight original procedural styles (skin/shirt/pants/hair/accessory) plus a
-- floating first name. Navigation stays straight-line MoveTo with teleport
-- recovery — the queue lives in front of the plot, clear of all furniture.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Customers = require(Shared.Config.Customers)
local Recipes = require(Shared.Config.Recipes)
local Grid = require(Shared.Utilities.Grid)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local CustomerService = {}
CustomerService.Name = "CustomerService"

local DataService: any
local OrderService: any
local CafeService: any

local SPAWN_INTERVAL = 8
local MAX_QUEUE = 3
local QUEUE_SPACING = 4 -- studs between line slots
local WALK_SPEED = 9
local WALK_TIMEOUT = 12 -- stuck recovery: teleport to goal
local PATIENCE_SECONDS = 120 -- waiting cap AT THE WINDOW before leaving angry
local LINE_PATIENCE_SECONDS = 180 -- total time a customer tolerates the queue

-- Floating first names give walk-ins the classic café-sim personality.
local NAMES = {
	"Alicia",
	"Ben",
	"Mia",
	"Leo",
	"Sofia",
	"Omar",
	"Nina",
	"Marco",
	"Prisha",
	"Yara",
	"Kenji",
	"Zoe",
}

-- Eight original looks: skin tone, outfit, hair style + colour, accessory.
type StyleDef = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hairColor: Color3,
	hair: string,
	accessory: string?,
}

local STYLES: { StyleDef } = {
	{
		skin = Color3.fromRGB(255, 205, 170),
		shirt = Color3.fromRGB(90, 130, 200),
		pants = Color3.fromRGB(60, 60, 80),
		hairColor = Color3.fromRGB(60, 40, 30),
		hair = "flat",
	},
	{
		skin = Color3.fromRGB(240, 190, 150),
		shirt = Color3.fromRGB(200, 90, 80),
		pants = Color3.fromRGB(50, 50, 60),
		hairColor = Color3.fromRGB(30, 25, 22),
		hair = "spiky",
		accessory = "apron",
	},
	{
		skin = Color3.fromRGB(190, 140, 100),
		shirt = Color3.fromRGB(240, 220, 120),
		pants = Color3.fromRGB(80, 60, 50),
		hairColor = Color3.fromRGB(20, 18, 16),
		hair = "bob",
	},
	{
		skin = Color3.fromRGB(150, 105, 80),
		shirt = Color3.fromRGB(120, 180, 120),
		pants = Color3.fromRGB(45, 45, 55),
		hairColor = Color3.fromRGB(180, 60, 50),
		hair = "cap",
	},
	{
		skin = Color3.fromRGB(255, 215, 180),
		shirt = Color3.fromRGB(230, 150, 180),
		pants = Color3.fromRGB(90, 70, 90),
		hairColor = Color3.fromRGB(200, 170, 90),
		hair = "ponytail",
	},
	{
		skin = Color3.fromRGB(225, 175, 135),
		shirt = Color3.fromRGB(150, 120, 200),
		pants = Color3.fromRGB(60, 55, 70),
		hairColor = Color3.fromRGB(120, 70, 40),
		hair = "bun",
	},
	{
		skin = Color3.fromRGB(205, 155, 115),
		shirt = Color3.fromRGB(250, 250, 245),
		pants = Color3.fromRGB(40, 40, 45),
		hairColor = Color3.fromRGB(90, 90, 95),
		hair = "beanie",
		accessory = "scarf",
	},
	{
		skin = Color3.fromRGB(170, 120, 90),
		shirt = Color3.fromRGB(255, 140, 80),
		pants = Color3.fromRGB(70, 80, 95),
		hairColor = Color3.fromRGB(35, 30, 28),
		hair = "long",
	},
}

type ActiveCustomer = {
	userId: number,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	bubble: TextLabel,
	def: Types.CustomerDefinition,
	spawnClock: number,
	orderId: string?,
	served: boolean,
	leaving: boolean,
}

local queues: { [number]: { ActiveCustomer } } = {}
local rng = Random.new()
local customersFolder: Folder

local function pickUnlockedRecipe(data: Types.PlayerData): string?
	local pool: { string } = {}
	for recipeId, unlocked in data.unlockedRecipes do
		if unlocked then
			table.insert(pool, recipeId)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function pickCustomer(): Types.CustomerDefinition
	local ids: { string } = {}
	for id in Customers do
		table.insert(ids, id)
	end
	return Customers[ids[rng:NextInteger(1, #ids)]]
end

local function cosmetic(
	model: Model,
	weldTo: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = weldTo
	weld.Part1 = part
	weld.Parent = weldTo
	return part
end

-- Chibi block-person with one of eight procedural styles.
local function buildNpcModel(
	def: Types.CustomerDefinition,
	style: StyleDef
): (Model, Humanoid, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "Customer_" .. def.id

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1.1)
	root.Color = style.shirt
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model

	-- Lower body (trousers) fills the hip-height gap under the torso.
	cosmetic(
		model,
		root,
		"Legs",
		Vector3.new(1.7, 1.2, 1),
		root.CFrame * CFrame.new(0, -1.55, 0),
		style.pants
	)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.Color = style.skin
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Massless = true
	head.CFrame = root.CFrame * CFrame.new(0, 2.05, 0)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = root
	headWeld.Part1 = head
	headWeld.Parent = root

	-- Simple face: two dot eyes on the walking direction (-Z).
	for _, x in { -0.38, 0.38 } do
		local eye = cosmetic(
			model,
			head,
			"Eye",
			Vector3.new(0.1, 0.22, 0.22),
			head.CFrame * CFrame.new(x, 0.12, -1.02) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(35, 30, 28)
		)
		eye.Shape = Enum.PartType.Cylinder
	end

	-- Hair: shared dome + per-style extras.
	local dome = cosmetic(
		model,
		head,
		"Hair",
		Vector3.new(2.3, 2.3, 2.3),
		head.CFrame * CFrame.new(0, 0.28, 0.12),
		style.hairColor
	)
	dome.Shape = Enum.PartType.Ball
	if style.hair == "spiky" then
		for i, x in { -0.5, 0, 0.5 } do
			cosmetic(
				model,
				head,
				"Spike",
				Vector3.new(0.35, 0.7, 0.35),
				head.CFrame * CFrame.new(x, 1.25, 0) * CFrame.Angles(0, 0, math.rad((i - 2) * 14)),
				style.hairColor
			)
		end
	elseif style.hair == "bob" then
		cosmetic(
			model,
			head,
			"BobBack",
			Vector3.new(1.9, 1.1, 0.6),
			head.CFrame * CFrame.new(0, -0.25, 0.95),
			style.hairColor
		)
	elseif style.hair == "cap" then
		cosmetic(
			model,
			head,
			"CapBrim",
			Vector3.new(1.5, 0.14, 0.9),
			head.CFrame * CFrame.new(0, 0.5, -1.15),
			style.hairColor
		)
	elseif style.hair == "ponytail" then
		local tail = cosmetic(
			model,
			head,
			"Ponytail",
			Vector3.new(0.75, 0.75, 0.75),
			head.CFrame * CFrame.new(0, -0.05, 1.15),
			style.hairColor
		)
		tail.Shape = Enum.PartType.Ball
	elseif style.hair == "bun" then
		local bun = cosmetic(
			model,
			head,
			"Bun",
			Vector3.new(0.7, 0.7, 0.7),
			head.CFrame * CFrame.new(0, 1.15, 0.25),
			style.hairColor
		)
		bun.Shape = Enum.PartType.Ball
	elseif style.hair == "beanie" then
		dome.CFrame = head.CFrame * CFrame.new(0, 0.42, 0)
	elseif style.hair == "long" then
		cosmetic(
			model,
			head,
			"LongBack",
			Vector3.new(2, 1.9, 0.5),
			head.CFrame * CFrame.new(0, -0.5, 1),
			style.hairColor
		)
	end

	if style.accessory == "apron" then
		cosmetic(
			model,
			root,
			"Apron",
			Vector3.new(1.95, 1.5, 0.15),
			root.CFrame * CFrame.new(0, -0.2, -0.62),
			Color3.fromRGB(245, 242, 235)
		)
	elseif style.accessory == "scarf" then
		cosmetic(
			model,
			root,
			"Scarf",
			Vector3.new(2.06, 0.42, 1.16),
			root.CFrame * CFrame.new(0, 0.92, 0),
			Color3.fromRGB(196, 60, 50)
		)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.HipHeight = 1
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromScale(6, 1.6)
	gui.StudsOffset = Vector3.new(0, 2.1, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "BubbleLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
	label.BackgroundTransparency = 0.25
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 248, 235)
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 12)
	labelCorner.Parent = label
	label.Parent = gui

	-- Floating first name above the bubble.
	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "NameTag"
	nameGui.Size = UDim2.fromScale(4, 0.9)
	nameGui.StudsOffset = Vector3.new(0, 3.2, 0)
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
	nameLabel.Text = NAMES[rng:NextInteger(1, #NAMES)]
	nameLabel.Parent = nameGui

	model.PrimaryPart = root
	return model, humanoid, root, label
end

-- Line slot 1 is the service window; the rest trail toward the street.
local function slotPosition(origin: CFrame, slot: number): Vector3
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	return (origin * CFrame.new(width / 2, 2, -3 - (slot - 1) * QUEUE_SPACING)).Position
end

-- Walk with a deadline; teleport to the goal on timeout (MVP stuck recovery).
local function walkTo(cust: ActiveCustomer, target: Vector3)
	local deadline = os.clock() + WALK_TIMEOUT
	while not cust.leaving and cust.root.Parent ~= nil do
		local flat = (cust.root.Position - target) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 1.5 then
			return
		end
		if os.clock() > deadline then
			cust.model:PivotTo(CFrame.new(target + Vector3.new(0, 2, 0)))
			return
		end
		cust.humanoid:MoveTo(target)
		task.wait(0.4)
	end
end

local function myIndex(cust: ActiveCustomer): number?
	local q = queues[cust.userId]
	return if q then table.find(q, cust) else nil
end

local function removeFromQueue(cust: ActiveCustomer)
	local q = queues[cust.userId]
	local i = q and table.find(q, cust)
	if q and i then
		table.remove(q, i)
	end
end

-- Leave the line (already removed or removing now), walk out, despawn.
local function depart(cust: ActiveCustomer, streetPos: Vector3)
	removeFromQueue(cust)
	if cust.root.Parent ~= nil and not cust.leaving then
		walkTo(cust, streetPos)
	end
	cust.model:Destroy()
end

local function runVisit(player: Player, cust: ActiveCustomer, origin: CFrame)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local streetPos = (origin * CFrame.new(width / 2 + rng:NextNumber(-10, 10), 2, -14)).Position

	cust.model:PivotTo(CFrame.lookAt(streetPos, slotPosition(origin, 1)))
	cust.model.Parent = customersFolder
	pcall(function()
		cust.root:SetNetworkOwner(nil)
	end)
	cust.bubble.Text = "…"

	-- Queue phase: walk to my slot; step forward whenever the line advances.
	local lastSlot = -1
	while not cust.leaving do
		local slot = myIndex(cust)
		if slot == nil then
			cust.model:Destroy()
			return
		end
		if slot == 1 then
			break -- my turn at the window
		end
		if slot ~= lastSlot then
			lastSlot = slot
			cust.bubble.Text = "⏳"
			walkTo(cust, slotPosition(origin, slot))
		end
		if os.clock() - cust.spawnClock > LINE_PATIENCE_SECONDS then
			cust.bubble.Text = "😤"
			task.wait(1)
			depart(cust, streetPos)
			return
		end
		task.wait(0.3)
	end
	if cust.leaving then
		depart(cust, streetPos)
		return
	end

	-- Front of the line: step to the window and order.
	cust.bubble.Text = "…"
	walkTo(cust, slotPosition(origin, 1))
	if cust.leaving then
		depart(cust, streetPos)
		return
	end

	local data = DataService:GetProfile(player)
	local recipeId = if data then pickUnlockedRecipe(data) else nil
	local orderId = if recipeId
		then OrderService:CreateOrder(player, recipeId, cust.def.id)
		else nil
	if not orderId then
		depart(cust, streetPos)
		return
	end
	cust.orderId = orderId
	local recipe = Recipes[recipeId :: string]
	cust.bubble.Text = "🗨️ " .. recipe.displayName

	local deadline = os.clock() + PATIENCE_SECONDS
	while os.clock() < deadline and cust.orderId ~= nil and not cust.leaving do
		task.wait(0.25)
	end

	if cust.leaving then
		if cust.orderId ~= nil then
			OrderService:CancelOrder(cust.orderId)
		end
		depart(cust, streetPos)
		return
	end
	if cust.orderId ~= nil then
		-- Patience ran out at the window: cancel and leave visibly unhappy.
		OrderService:CancelOrder(cust.orderId)
		cust.orderId = nil
		cust.bubble.Text = "😠 Too slow…"
	end
	task.wait(1.4) -- let the reaction (happy or angry) read before walking off

	depart(cust, streetPos)
end

-- Called by OrderService when the order is served, with the coins awarded.
-- Only the front customer can hold an order, so match on orderId presence.
function CustomerService.OnOrderResolved(_self: any, userId: number, coinsAwarded: number?)
	local q = queues[userId]
	local front = q and q[1]
	if front and front.orderId ~= nil then
		front.orderId = nil
		front.served = true
		front.bubble.Text = if coinsAwarded ~= nil
			then "😊 +" .. tostring(coinsAwarded) .. " 🪙"
			else "😊"
	end
end

function CustomerService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	OrderService = ServiceRegistry.get("OrderService")
	CafeService = ServiceRegistry.get("CafeService")
end

function CustomerService.Start(_self: any)
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = workspace

	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) then
					local q = queues[player.UserId]
					if q == nil then
						q = {}
						queues[player.UserId] = q
					end
					local origin = CafeService:GetPlotOrigin(player)
					if origin and #q < MAX_QUEUE then
						local def = pickCustomer()
						local style = STYLES[rng:NextInteger(1, #STYLES)]
						local model, humanoid, root, bubble = buildNpcModel(def, style)
						local cust: ActiveCustomer = {
							userId = player.UserId,
							model = model,
							humanoid = humanoid,
							root = root,
							bubble = bubble,
							def = def,
							spawnClock = os.clock(),
							orderId = nil,
							served = false,
							leaving = false,
						}
						table.insert(q, cust)
						task.spawn(runVisit, player, cust, origin)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local q = queues[player.UserId]
		if q then
			for _, cust in q do
				cust.leaving = true
				cust.model:Destroy()
			end
			queues[player.UserId] = nil
		end
	end)
end

return CustomerService
