--!strict
-- Visible walk-in customer NPCs (Day 3). One customer per café at a time:
-- spawn on the street → walk to the service spot → place the order (via
-- OrderService, which owns rewards) → wait with a recipe bubble → react to
-- the serve → walk out. Navigation is straight-line MoveTo with teleport
-- recovery, which is safe under the MVP constraints (grid furniture, open
-- café front, one floor). Patience runs out after PATIENCE_SECONDS and the
-- order is cancelled server-side.

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
local WALK_SPEED = 9
local WALK_TIMEOUT = 12 -- seconds before a walking NPC is teleported to its goal
local PATIENCE_SECONDS = 120 -- waiting cap before the customer leaves angry

type ActiveCustomer = {
	userId: number,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	bubble: TextLabel,
	def: Types.CustomerDefinition,
	orderId: string?,
	served: boolean,
	leaving: boolean,
}

local activeByUser: { [number]: ActiveCustomer } = {}
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

-- Greybox block-person: coloured body + head ball, zero asset dependencies.
local function buildNpcModel(def: Types.CustomerDefinition): (Model, Humanoid, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "Customer_" .. def.id

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2.6, 1)
	root.Color = def.color
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = def.color:Lerp(Color3.new(1, 1, 1), 0.35)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CFrame = root.CFrame * CFrame.new(0, 2, 0)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.HipHeight = 0.35
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromScale(6, 1.6)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
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

	model.PrimaryPart = root
	return model, humanoid, root, label
end

-- Walk with a deadline; teleport to the goal on timeout (MVP stuck recovery).
local function walkTo(cust: ActiveCustomer, target: Vector3)
	local deadline = os.clock() + WALK_TIMEOUT
	while not cust.leaving and cust.root.Parent ~= nil do
		local flat = (cust.root.Position - target) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 2 then
			return
		end
		if os.clock() > deadline then
			cust.model:PivotTo(CFrame.new(target + Vector3.new(0, 2, 0)))
			return
		end
		-- Re-issued every tick: MoveTo natively expires after 8 seconds.
		cust.humanoid:MoveTo(target)
		task.wait(0.5)
	end
end

local function finish(cust: ActiveCustomer)
	if activeByUser[cust.userId] == cust then
		activeByUser[cust.userId] = nil
	end
	cust.model:Destroy()
end

local function runVisit(player: Player, cust: ActiveCustomer, origin: CFrame)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local streetPos = (origin * CFrame.new(width / 2 + rng:NextNumber(-8, 8), 2, -12)).Position
	local servicePos = (origin * CFrame.new(width / 2, 2, 10)).Position

	cust.model:PivotTo(
		CFrame.lookAt(streetPos, Vector3.new(servicePos.X, streetPos.Y, servicePos.Z))
	)
	cust.model.Parent = customersFolder
	pcall(function()
		cust.root:SetNetworkOwner(nil)
	end)
	cust.bubble.Text = "…"

	walkTo(cust, servicePos)
	if cust.leaving then
		finish(cust)
		return
	end

	-- At the counter: place the order. OrderService owns the reward path.
	local data = DataService:GetProfile(player)
	local recipeId = if data then pickUnlockedRecipe(data) else nil
	local orderId = if recipeId
		then OrderService:CreateOrder(player, recipeId, cust.def.id)
		else nil
	if not orderId then
		finish(cust)
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
		finish(cust)
		return
	end

	if cust.orderId ~= nil then
		-- Patience ran out: cancel server-side, leave visibly unhappy.
		OrderService:CancelOrder(cust.orderId)
		cust.orderId = nil
		cust.bubble.Text = "😠 Too slow…"
	end
	task.wait(1.4) -- let the reaction (happy or angry) read before walking off

	walkTo(cust, streetPos)
	finish(cust)
end

-- Called by OrderService when the order is served, with the coins awarded.
function CustomerService.OnOrderResolved(_self: any, userId: number, coinsAwarded: number?)
	local cust = activeByUser[userId]
	if cust and cust.orderId ~= nil then
		cust.orderId = nil
		cust.served = true
		cust.bubble.Text = if coinsAwarded ~= nil
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
				if activeByUser[player.UserId] == nil and DataService:IsLoaded(player) then
					local origin = CafeService:GetPlotOrigin(player)
					if origin then
						local def = pickCustomer()
						local model, humanoid, root, bubble = buildNpcModel(def)
						local cust: ActiveCustomer = {
							userId = player.UserId,
							model = model,
							humanoid = humanoid,
							root = root,
							bubble = bubble,
							def = def,
							orderId = nil,
							served = false,
							leaving = false,
						}
						activeByUser[player.UserId] = cust
						task.spawn(runVisit, player, cust, origin)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local cust = activeByUser[player.UserId]
		if cust then
			cust.leaving = true
		end
	end)
end

return CustomerService
