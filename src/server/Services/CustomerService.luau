--!strict
-- Walk-in customer NPCs v3: a visible waiting LINE at the service window.
-- Up to MAX_QUEUE customers per café queue on the street side; only the
-- front customer places an order (OrderService still owns rewards), and the
-- whole line steps forward on every serve/cancel. Each customer rolls one of
-- eight original procedural styles (skin/shirt/pants/hair/accessory) plus a
-- floating first name. Real Creator Store rigs are dressed with the same
-- bubble/name tag when available (else the chibi fallback). Navigation uses a
-- PathfindingService route around collidable furniture, with straight-line
-- MoveTo + teleport recovery as the fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Customers = require(Shared.Config.Customers)
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Kitchen = require(Shared.Config.Kitchen)
local Operations = require(Shared.Config.Operations)
local World = require(Shared.Config.World)
local Grid = require(Shared.Utilities.Grid)
local RewardMath = require(Shared.Utilities.RewardMath)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)
local NpcAnimator = require(script.Parent.Parent.NpcAnimator)
local NpcNav = require(script.Parent.Parent.NpcNav)
local PlateFactory = require(script.Parent.Parent.PlateFactory)

local CustomerService = {}
CustomerService.Name = "CustomerService"

local DataService: any
local OrderService: any
local CafeService: any
local KitchenService: any
local EconomyService: any
local StaffService: any
local GoalService: any
local AssetLibraryService: any
local CafeOperationsService: any

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

type MoodUi = {
	gui: BillboardGui,
	face: TextLabel,
	fill: Frame,
}

type ActiveCustomer = {
	userId: number,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	bubble: TextLabel,
	def: Types.CustomerDefinition,
	baseHip: number, -- resting HipHeight (differs per rig); waddle bobs around it
	anim: NpcAnimator.AnimHandle?, -- real-rig animation control (nil on chibis)
	name: string,
	regular: boolean, -- a returning customer (S2 feelings pass)
	favourite: string?, -- the regular's favourite recipeId
	mood: MoodUi?, -- face + patience bar over the head while they wait
	spawnClock: number,
	orderId: string?,
	served: boolean,
	leaving: boolean,
	seatCf: CFrame?,
	seatId: string?,
	tableLabel: string?,
	resolvedPay: number?,
	resolvedManual: boolean?,
}

local queues: { [number]: { ActiveCustomer } } = {}
local customersByOrder: { [string]: ActiveCustomer } = {}
local allCustomers: { [ActiveCustomer]: boolean } = {}
local rng = Random.new()
local customersFolder: Folder

-- Personal-service COMBO (S2 gameplay): chaining hands-on actions (serving
-- orders, cleaning tables) within 45s builds a streak that pays bonus coins —
-- an active owner visibly out-earns an idle one.
local COMBO_WINDOW = 45
local combos: { [number]: { count: number, lastAt: number } } = {}

local function bumpCombo(player: Player, position: Vector3)
	local now = os.clock()
	local state = combos[player.UserId]
	if state and now - state.lastAt <= COMBO_WINDOW then
		state.count += 1
		state.lastAt = now
	else
		state = { count = 1, lastAt = now }
		combos[player.UserId] = state
	end
	if state.count >= 2 and EconomyService then
		local bonus = math.min(state.count, 10) * 2
		EconomyService:AddCoins(player, bonus)
		Fx.floatText(
			position + Vector3.new(0, 5.6, 0),
			string.format("COMBO ×%d  +%d 🪙", state.count, bonus),
			Color3.fromRGB(255, 224, 130)
		)
	end
end

local function pickUnlockedRecipe(data: Types.PlayerData): string?
	local pool: { string } = {}
	for recipeId, unlocked in data.unlockedRecipes do
		if unlocked and KitchenService:IsOnMenu(data, recipeId) then
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

-- Order bubble (returned label) + floating first name, parented to any head.
-- Shared by the procedural chibi and the Creator Store rigs.
local function attachBubbles(head: BasePart, name: string): TextLabel
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
	nameLabel.Text = name
	nameLabel.Parent = nameGui

	return label
end

-- Mood face + draining patience bar over the head (Café World B6/B7): green
-- and smiling while fresh, amber, then red and angry as patience runs out.
local function attachMood(head: BasePart): MoodUi
	local gui = Instance.new("BillboardGui")
	gui.Name = "Mood"
	gui.Size = UDim2.fromScale(3.4, 0.7)
	gui.StudsOffset = Vector3.new(0, 4.15, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = head

	local face = Instance.new("TextLabel")
	face.Name = "Face"
	face.Size = UDim2.fromScale(0.24, 1)
	face.BackgroundTransparency = 1
	face.TextScaled = true
	face.Text = "😊"
	face.Parent = gui

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.Size = UDim2.fromScale(0.72, 0.42)
	barBack.Position = UDim2.fromScale(0.28, 0.29)
	barBack.BackgroundColor3 = Color3.fromRGB(45, 35, 32)
	barBack.BackgroundTransparency = 0.35
	barBack.BorderSizePixel = 0
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = barBack
	barBack.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = barBack

	return { gui = gui, face = face, fill = fill }
end

local function setMood(cust: ActiveCustomer, fraction: number)
	local mood = cust.mood
	if not mood or mood.gui.Parent == nil then
		return
	end
	local f = math.clamp(fraction, 0, 1)
	mood.fill.Size = UDim2.fromScale(f, 1)
	if f > 0.55 then
		mood.face.Text = "😊"
		mood.fill.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
	elseif f > 0.25 then
		mood.face.Text = "😐"
		mood.fill.BackgroundColor3 = Color3.fromRGB(240, 200, 90)
	else
		mood.face.Text = "😠"
		mood.fill.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
	end
end

local function clearMood(cust: ActiveCustomer)
	if cust.mood then
		cust.mood.gui:Destroy()
		cust.mood = nil
	end
end

-- Angry walkout drama: the Buzz loss is something you SEE, not just a number.
local function stormOut(cust: ActiveCustomer, buzzDelta: number, reason: string?)
	cust.bubble.Text = reason or "😠 Too slow…"
	clearMood(cust)
	cust.humanoid.WalkSpeed = WALK_SPEED + 5
	Fx.floatText(
		cust.root.Position + Vector3.new(0, 4.6, 0),
		string.format("%d 🔥", buzzDelta),
		Color3.fromRGB(235, 90, 80)
	)
end

-- Three little hearts for delightful service (regular's favourite, personal
-- serves) — floats staggered so they read as a burst.
local function hearts(position: Vector3)
	for i = 1, 3 do
		task.delay((i - 1) * 0.18, function()
			Fx.floatText(
				position + Vector3.new((i - 2) * 1.1, 3.4 + i * 0.4, 0),
				"❤️",
				Color3.fromRGB(235, 100, 110)
			)
		end)
	end
end

-- Chibi block-person with one of eight procedural styles.
local function buildNpcModel(
	def: Types.CustomerDefinition,
	style: StyleDef,
	name: string
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

	local label = attachBubbles(head, name)

	model.PrimaryPart = root
	return model, humanoid, root, label
end

-- Try a vetted Creator Store rig (real clothed customer); fall back to the
-- procedural chibi. Either way we attach our own order bubble + name tag and
-- return the same tuple the rest of the lifecycle expects.
local function spawnCustomerModel(
	def: Types.CustomerDefinition,
	name: string
): (Model, Humanoid, BasePart, TextLabel)
	local rig: Model? = if AssetLibraryService then AssetLibraryService:GetCustomerRig() else nil
	if rig then
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = rig:FindFirstChild("Head") :: BasePart?
		if humanoid and root and head then
			rig.Name = "Customer_" .. def.id
			humanoid.WalkSpeed = WALK_SPEED
			humanoid.BreakJointsOnDeath = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			local label = attachBubbles(head, name)
			rig.PrimaryPart = root
			return rig, humanoid, root, label
		end
		rig:Destroy()
	end
	local style = STYLES[rng:NextInteger(1, #STYLES)]
	return buildNpcModel(def, style, name)
end

-- 35% of spawns are RETURNING regulars once the café has some: same name,
-- and they'll order their favourite dish (Café World B8).
local function pickRegular(data: Types.PlayerData?): (string?, string?)
	if not data or typeof((data :: any).regulars) ~= "table" then
		return nil, nil
	end
	local names: { string } = {}
	for name in (data :: any).regulars do
		table.insert(names, name)
	end
	if #names == 0 or rng:NextNumber() > 0.35 then
		return nil, nil
	end
	local name = names[rng:NextInteger(1, #names)]
	local entry = (data :: any).regulars[name]
	return name, if typeof(entry) == "table" then entry.favourite else nil
end

-- The queue now lives INSIDE the café (S2 facade): customers path through the
-- front door and line up in front of the counter area; slot 1 is the deepest.
local function slotPosition(origin: CFrame, slot: number): Vector3
	local diningX = (World.kitchenWidthCells + 1.5) * Grid.CELL_SIZE
	local firstZ = (World.kitchenDepthCells + 1) * Grid.CELL_SIZE
	return (origin * CFrame.new(diningX, 2, firstZ - (slot - 1) * QUEUE_SPACING)).Position
end

-- Walk routing around collidable furniture, straight-line + teleport recovery
-- as fallback — shared with staff via NpcNav.
local function walkTo(cust: ActiveCustomer, target: Vector3)
	NpcNav.walkTo(cust.model, cust.humanoid, cust.root, target, {
		baseHip = cust.baseHip,
		straightTimeout = WALK_TIMEOUT,
		cancelled = function()
			return cust.leaving
		end,
	})
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

-- ————— seated dining (Phase 2; plate visuals live in PlateFactory) —————

-- instanceId → true, per user, for chairs currently holding a diner.
local occupiedSeats: { [number]: { [string]: boolean } } = {}

-- Pick a free placed chair; returns its world CFrame + instanceId.
local function claimSeat(player: Player): (CFrame?, string?, string?)
	local data = DataService:GetProfile(player)
	local origin = CafeService:GetPlotOrigin(player)
	if not data or not origin then
		return nil, nil, nil
	end
	local taken = occupiedSeats[player.UserId]
	if not taken then
		taken = {}
		occupiedSeats[player.UserId] = taken
	end
	local seatNumber = 0
	for _, placed in data.placedFurniture do
		local def = Furniture[placed.catalogId]
		if def and def.seatCount > 0 then
			seatNumber += 1
		end
		local w, d = 0, 0
		if def then
			w, d = Grid.footprintSize(def.width, def.depth, placed.rotation)
		end
		local seatX = placed.gridX + w / 2
		local seatZ = placed.gridY + d / 2
		local inKitchen = seatX < World.kitchenWidthCells and seatZ < World.kitchenDepthCells
		if def and def.seatCount > 0 and not inKitchen and not taken[placed.instanceId] then
			taken[placed.instanceId] = true
			local cf = Grid.cellToWorld(
				origin,
				placed.gridX,
				placed.gridY,
				def.width,
				def.depth,
				placed.rotation,
				def.height
			)
			return cf, placed.instanceId, "TABLE " .. tostring(seatNumber)
		end
	end
	return nil, nil, nil
end

local function releaseSeat(player: Player, seatId: string?)
	local taken = occupiedSeats[player.UserId]
	if taken and seatId then
		taken[seatId] = nil
	end
end

-- Drop a collectible tip at the seat: the owner taps it for coins + a burst.
local function dropTip(player: Player, seatCf: CFrame, amount: number)
	local folder = CafeService:GetFurnitureFolder(player)
	local plotModel = folder and folder.Parent
	if not plotModel then
		return
	end
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Cylinder
	tip.Size = Vector3.new(0.25, 1.1, 1.1)
	tip.Color = Color3.fromRGB(240, 195, 80)
	tip.Material = Enum.Material.Metal
	tip.Anchored = true
	tip.CanCollide = false
	tip.CFrame = CFrame.new(seatCf.Position + Vector3.new(0, 1.4, 0))
		* CFrame.Angles(0, 0, math.rad(90))

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2.6, 0.9)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = tip
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 224, 130)
	label.TextStrokeTransparency = 0.3
	label.Text = "🪙 Tip!"
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take tip"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = tip

	local claimed = false
	prompt.Triggered:Connect(function(who)
		-- Only the café owner pockets tips left in their café.
		if claimed or who ~= player then
			return
		end
		claimed = true
		EconomyService:AddCoins(player, amount)
		Fx.coinBurst(tip.Position, 5)
		Fx.floatText(tip.Position + Vector3.new(0, 1, 0), "+" .. tostring(amount) .. " 🪙")
		if GoalService then
			GoalService:Bump(player, "collect_tips", 1)
		end
		tip:Destroy()
	end)

	tip.Parent = plotModel
	task.delay(120, function()
		if tip.Parent ~= nil then
			tip:Destroy()
		end
	end)
end

-- The full dining moment after the correct table receives its dish.
local function eatMeal(
	player: Player,
	cust: ActiveCustomer,
	streetPos: Vector3,
	recipeId: string,
	announcedPay: number?
)
	removeFromQueue(cust)
	local recipe = Recipes[recipeId]
	if announcedPay ~= nil then
		cust.bubble.Text = (
			if recipe then (recipe.icon or "🍽️") .. " " .. recipe.displayName else recipeId
		)
	end

	local seatCf, seatId = cust.seatCf, cust.seatId
	if seatCf and not cust.leaving and cust.root.Parent ~= nil then
		if not cust.root.Anchored then
			walkTo(cust, Vector3.new(seatCf.Position.X, 2, seatCf.Position.Z))
		end
		if not cust.leaving and cust.root.Parent ~= nil then
			-- Sit: lower onto the seat, face the chair's way, and lock in.
			-- setSeated stops the walk cycle (anchored roots never fire
			-- Running(0), which left seated legs pedalling — owner bug).
			local sitPos = Vector3.new(seatCf.Position.X, 2.05, seatCf.Position.Z)
			cust.root.Anchored = true
			cust.model:PivotTo(CFrame.lookAt(sitPos, sitPos + seatCf.LookVector))
			if cust.anim then
				cust.anim.setSeated(true)
			end

			-- S2 service theater: barista/cook prepares the dish (icon bubble),
			-- the waiter carries the plate over and sets it on the table.
			local plate: Model?, food: Instance?
			if not cust.resolvedManual and StaffService and StaffService.DeliverMeal then
				plate, food = StaffService:DeliverMeal(player, recipeId, seatCf)
			end
			if not plate then
				-- No staff at all: the plate simply appears on the table.
				plate, food = PlateFactory.make(AssetLibraryService, recipe)
				plate:PivotTo(
					CFrame.new(seatCf.Position + seatCf.LookVector * 1.8 + Vector3.new(0, 1.15, 0))
				)
				local folder = CafeService:GetFurnitureFolder(player)
				plate.Parent = (folder and folder.Parent) or cust.model
			end

			-- A regular getting their FAVOURITE is a heart moment (+1 Buzz).
			if cust.regular and cust.favourite == recipeId and not cust.leaving then
				KitchenService:AddBuzz(player, 1)
				hearts(cust.model:GetPivot().Position)
				Fx.floatText(
					cust.model:GetPivot().Position + Vector3.new(0, 5, 0),
					"❤️ My favourite! +1 🔥",
					Color3.fromRGB(235, 100, 110)
				)
			end

			-- Eat with a happy bob.
			local basePivot = cust.model:GetPivot()
			for i = 1, 12 do
				if cust.leaving or cust.root.Parent == nil then
					break
				end
				cust.model:PivotTo(basePivot * CFrame.new(0, (i % 2) * 0.12, 0))
				if i == 6 then
					cust.bubble.Text = "😋"
				end
				task.wait(0.55)
			end

			if cust.leaving or cust.root.Parent == nil then
				-- Left mid-meal (despawn): don't leave theater props behind.
				if plate then
					plate:Destroy()
				end
			else
				-- The food is eaten; the EMPTY plate stays on the table until
				-- the cleaner collects it for washing (+1 Buzz).
				if food then
					food:Destroy()
				end
				if plate then
					plate.Name = "DirtyPlate"
					-- Owner participation: clean the table yourself for the
					-- same +1 Buzz Pia would earn — first one there wins.
					local dishPart = plate.PrimaryPart
					if dishPart then
						local cleanPrompt = Instance.new("ProximityPrompt")
						cleanPrompt.Name = "CleanUp"
						cleanPrompt.ObjectText = "Dirty plate"
						cleanPrompt.ActionText = "Clean up"
						cleanPrompt.HoldDuration = 0.25
						cleanPrompt.MaxActivationDistance = 10
						cleanPrompt.RequiresLineOfSight = false
						cleanPrompt.Parent = dishPart
						local cleaned = false
						cleanPrompt.Triggered:Connect(function(who)
							if cleaned or who ~= player or plate.Parent == nil then
								return
							end
							cleaned = true
							KitchenService:AddBuzz(player, 1)
							Fx.floatText(
								plate:GetPivot().Position + Vector3.new(0, 1.2, 0),
								"+1 🔥",
								Color3.fromRGB(255, 180, 120)
							)
							bumpCombo(player, plate:GetPivot().Position)
							plate:Destroy()
						end)
					end
					if StaffService then
						StaffService:NotifyMess(player, plate)
					else
						task.delay(60, function()
							if plate.Parent ~= nil then
								plate:Destroy()
							end
						end)
					end
				end

				-- Tips are the seated-dining exclusive: reward for having chairs.
				if recipe then
					local tip = RewardMath.tipAmount(
						recipe,
						rng:NextInteger(1, 100),
						cust.def.tipMultiplier
					)
					if tip > 0 then
						dropTip(player, seatCf, tip)
					end
				end

				-- Remember this diner as a REGULAR: next time they may come
				-- back by name asking for today's dish (persisted, max 8).
				local data = DataService:GetProfile(player)
				if data then
					if typeof((data :: any).regulars) ~= "table" then
						(data :: any).regulars = {}
					end
					local regs = (data :: any).regulars
					local count = 0
					for _ in regs do
						count += 1
					end
					if regs[cust.name] ~= nil or count < 8 then
						local entry = regs[cust.name]
						if typeof(entry) ~= "table" then
							entry = { favourite = recipeId, visits = 0 }
						end
						entry.visits += 1
						entry.favourite = recipeId
						regs[cust.name] = entry
						DataService:Push(player)
					end
				end
			end
			if cust.anim then
				cust.anim.setSeated(false)
			end
			if cust.root.Parent ~= nil then
				cust.root.Anchored = false
			end
		end
	else
		-- No chair free: a quick standing bite at the window.
		task.wait(2.2)
	end
	releaseSeat(player, seatId)
	cust.seatCf = nil
	cust.seatId = nil

	if cust.root.Parent ~= nil then
		cust.bubble.Text = if announcedPay ~= nil
			then "😊 +" .. tostring(announcedPay) .. " 🪙"
			else "😊"
		task.wait(1)
		walkTo(cust, streetPos)
	end
	cust.model:Destroy()
end

-- Leave the line (already removed or removing now), walk out, despawn.
local function depart(cust: ActiveCustomer, streetPos: Vector3)
	removeFromQueue(cust)
	if cust.root.Parent ~= nil and not cust.leaving then
		cust.root.Anchored = false
		if cust.anim then
			cust.anim.setSeated(false)
		end
		walkTo(cust, streetPos)
	end
	cust.model:Destroy()
end

-- Active table-service visit. Customers now enter from distant sidewalk
-- points, claim a numbered seat, order there, and wait for either the finite
-- waiter shift or the owner's physical pass-to-table delivery.
local function runActiveVisit(player: Player, cust: ActiveCustomer, origin: CFrame)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local doorX = width * World.doorCenterFrac
	local doorStreetPos = (origin * CFrame.new(doorX, 2, -14)).Position
	local streetStart = (origin * CFrame.new(doorX + side * rng:NextNumber(50, 95), 2, -14)).Position
	local streetExit = (origin * CFrame.new(doorX - side * rng:NextNumber(55, 105), 2, -14)).Position
	local streetLength = (World.plotsPerRow - 1) * (width + World.plotGap) + width
	streetStart = Vector3.new(math.clamp(streetStart.X, -30, streetLength + 30), 2, streetStart.Z)
	streetExit = Vector3.new(math.clamp(streetExit.X, -30, streetLength + 30), 2, streetExit.Z)

	cust.model:PivotTo(CFrame.lookAt(streetStart, doorStreetPos))
	cust.model.Parent = customersFolder
	NpcNav.assignNpcGroup(cust.model)
	pcall(function()
		cust.root:SetNetworkOwner(nil)
	end)
	cust.anim = NpcAnimator.setup(cust.humanoid)
	cust.bubble.Text = "Walking to café…"
	local moodHead = cust.model:FindFirstChild("Head")
	if moodHead and moodHead:IsA("BasePart") then
		cust.mood = attachMood(moodHead)
	end
	walkTo(cust, doorStreetPos)
	if cust.leaving or cust.root.Parent == nil then
		cust.model:Destroy()
		return
	end
	if cust.regular then
		Fx.floatText(
			cust.root.Position + Vector3.new(0, 5, 0),
			"💚 " .. cust.name .. " is back!",
			Color3.fromRGB(150, 220, 140)
		)
	end

	local lastSlot = -1
	while not cust.leaving do
		local slot = myIndex(cust)
		if slot == nil then
			cust.model:Destroy()
			return
		end
		if slot == 1 then
			break
		end
		if slot ~= lastSlot then
			lastSlot = slot
			cust.bubble.Text = "⏳ Waiting in line"
			walkTo(cust, slotPosition(origin, slot))
		end
		setMood(cust, 1 - (os.clock() - cust.spawnClock) / LINE_PATIENCE_SECONDS)
		if os.clock() - cust.spawnClock > LINE_PATIENCE_SECONDS then
			stormOut(cust, Kitchen.buzzPerWalkout, "😡 THIS LINE IS TOO LONG!")
			KitchenService:AddBuzz(player, Kitchen.buzzPerWalkout)
			CafeOperationsService:AdjustSatisfaction(player, -Operations.satisfactionWalkoutLoss)
			task.wait(1.2)
			depart(cust, streetExit)
			return
		end
		task.wait(0.3)
	end
	if cust.leaving then
		depart(cust, streetExit)
		return
	end

	walkTo(cust, slotPosition(origin, 1))
	local cleanliness = CafeOperationsService:GetCleanliness(player)
	if cleanliness < Operations.dirtyRejectThreshold then
		stormOut(cust, Kitchen.buzzPerWalkout, "🤢 TOO DIRTY! I'M LEAVING!")
		KitchenService:AddBuzz(player, Kitchen.buzzPerWalkout)
		CafeOperationsService:AdjustSatisfaction(player, -Operations.satisfactionDirtyLoss)
		task.wait(1.4)
		depart(cust, streetExit)
		return
	end

	local seatCf, seatId, tableLabel = claimSeat(player)
	if not seatCf or not seatId then
		stormOut(cust, Kitchen.buzzPerWalkout, "😡 NO EMPTY CHAIR!")
		KitchenService:AddBuzz(player, Kitchen.buzzPerWalkout)
		CafeOperationsService:AdjustSatisfaction(player, -Operations.satisfactionNoSeatLoss)
		task.wait(1.4)
		depart(cust, streetExit)
		return
	end
	removeFromQueue(cust)
	cust.seatCf = seatCf
	cust.seatId = seatId
	cust.tableLabel = tableLabel
	walkTo(cust, Vector3.new(seatCf.Position.X, 2, seatCf.Position.Z))
	if cust.leaving or cust.root.Parent == nil then
		releaseSeat(player, seatId)
		cust.model:Destroy()
		return
	end
	local sitPos = Vector3.new(seatCf.Position.X, 2.05, seatCf.Position.Z)
	cust.root.Anchored = true
	cust.model:PivotTo(CFrame.lookAt(sitPos, sitPos + seatCf.LookVector))
	if cust.anim then
		cust.anim.setSeated(true)
	end

	local data = DataService:GetProfile(player)
	local recipeId = if data then pickUnlockedRecipe(data) else nil
	if cust.favourite and data and KitchenService:IsOnMenu(data, cust.favourite) then
		recipeId = cust.favourite
	end
	if not recipeId then
		releaseSeat(player, seatId)
		cust.root.Anchored = false
		depart(cust, streetExit)
		return
	end
	local orderId =
		OrderService:CreateOrder(player, recipeId, cust.def.id, seatId, tableLabel, cust.root)
	if not orderId then
		releaseSeat(player, seatId)
		cust.root.Anchored = false
		depart(cust, streetExit)
		return
	end
	cust.orderId = orderId
	customersByOrder[orderId] = cust
	local recipe = Recipes[recipeId]
	cust.bubble.Text = (tableLabel or "TABLE")
		.. "  •  "
		.. (recipe.icon or "🍽️")
		.. " "
		.. recipe.displayName

	local satisfaction = CafeOperationsService:GetSatisfaction(player)
	local patienceMultiplier = 0.7 + satisfaction / 200
	if cleanliness < Operations.dirtyPatienceThreshold then
		patienceMultiplier *= math.max(
			Operations.minPatienceMultiplier,
			cleanliness / Operations.dirtyPatienceThreshold
		)
	end
	local patience = PATIENCE_SECONDS * patienceMultiplier
	local deadline = os.clock() + patience
	while os.clock() < deadline and not cust.served and not cust.leaving do
		setMood(cust, (deadline - os.clock()) / patience)
		task.wait(0.25)
	end

	customersByOrder[orderId] = nil
	if cust.leaving then
		OrderService:CancelOrder(orderId)
		releaseSeat(player, seatId)
		cust.root.Anchored = false
		depart(cust, streetExit)
		return
	end
	if cust.served then
		cust.orderId = nil
		clearMood(cust)
		eatMeal(player, cust, streetExit, recipeId, cust.resolvedPay)
		return
	end

	OrderService:CancelOrder(orderId)
	cust.orderId = nil
	stormOut(cust, Kitchen.buzzPerWalkout, "😡 MY ORDER NEVER CAME!")
	KitchenService:AddBuzz(player, Kitchen.buzzPerWalkout)
	CafeOperationsService:AdjustSatisfaction(player, -Operations.satisfactionWalkoutLoss)
	releaseSeat(player, seatId)
	cust.seatId = nil
	cust.seatCf = nil
	cust.root.Anchored = false
	if cust.anim then
		cust.anim.setSeated(false)
	end
	task.wait(1.5)
	depart(cust, streetExit)
end

function CustomerService.OnOrderResolved(
	_self: any,
	orderId: string,
	coinsAwarded: number?,
	manual: boolean?
)
	local cust = customersByOrder[orderId]
	if cust and cust.orderId == orderId then
		cust.served = true
		cust.resolvedPay = coinsAwarded
		cust.resolvedManual = manual == true
		cust.bubble.Text = if coinsAwarded ~= nil
			then "😊 +" .. tostring(coinsAwarded) .. " 🪙"
			else "😊"
	end
end

function CustomerService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	OrderService = ServiceRegistry.get("OrderService")
	CafeService = ServiceRegistry.get("CafeService")
	KitchenService = ServiceRegistry.get("KitchenService")
	EconomyService = ServiceRegistry.get("EconomyService")
	StaffService = ServiceRegistry.get("StaffService")
	GoalService = ServiceRegistry.get("GoalService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
	CafeOperationsService = ServiceRegistry.get("CafeOperationsService")
end

function CustomerService.Start(_self: any)
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = workspace

	-- Buzz drives the crowd: high-Buzz cafés get customers every few seconds.
	local nextSpawnAt: { [number]: number } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) then
					local q = queues[player.UserId]
					if q == nil then
						q = {}
						queues[player.UserId] = q
					end
					local origin = CafeService:GetPlotOrigin(player)
					local due = os.clock() >= (nextSpawnAt[player.UserId] or 0)
					if origin and #q < MAX_QUEUE and due then
						local demandPerMinute = KitchenService:GetDemandRate(player)
						local interval = 60 / math.max(0.2, demandPerMinute)
						nextSpawnAt[player.UserId] = os.clock() + interval
						local def = pickCustomer()
						local data = DataService:GetProfile(player)
						local regularName, favourite = pickRegular(data)
						local name = regularName or NAMES[rng:NextInteger(1, #NAMES)]
						local model, humanoid, root, bubble = spawnCustomerModel(def, name)
						local cust: ActiveCustomer = {
							userId = player.UserId,
							model = model,
							humanoid = humanoid,
							root = root,
							bubble = bubble,
							def = def,
							baseHip = humanoid.HipHeight,
							name = name,
							regular = regularName ~= nil,
							favourite = favourite,
							spawnClock = os.clock(),
							orderId = nil,
							served = false,
							leaving = false,
						}
						table.insert(q, cust)
						allCustomers[cust] = true
						cust.model.Destroying:Connect(function()
							allCustomers[cust] = nil
						end)
						task.spawn(runActiveVisit, player, cust, origin)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for cust in allCustomers do
			if cust.userId == player.UserId then
				if cust.orderId then
					customersByOrder[cust.orderId] = nil
				end
				cust.leaving = true
				if cust.model.Parent ~= nil then
					cust.model:Destroy()
				end
			end
		end
		local q = queues[player.UserId]
		if q then
			for _, cust in q do
				if cust.orderId then
					customersByOrder[cust.orderId] = nil
				end
				cust.leaving = true
				cust.model:Destroy()
			end
			queues[player.UserId] = nil
		end
		combos[player.UserId] = nil
	end)
end

return CustomerService
