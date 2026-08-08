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
local Vip = require(Shared.Config.Vip)
local Grid = require(Shared.Utilities.Grid)
local RewardMath = require(Shared.Utilities.RewardMath)
local SeatMath = require(Shared.Utilities.SeatMath)
local Remotes = require(Shared.Network.Remotes)
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
local AnalyticsService: any
local SocialService: any

local MAX_QUEUE = 3
-- Studs between line slots. 4 was less than a customer is WIDE once
-- AssetManifest.displayScale grew everything, so the three queuers stood inside
-- one another and read as a single person (owner 2026-08-06: "they all stay in
-- the same positions").
local QUEUE_SPACING = 7
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
	isVip: boolean?, -- the brainrot VIP: uses the welded rig + gift box on serve
	forcedRecipe: string?, -- VIP orders this exact (RARE) dish, not a random pick
	lureImmuneUntil: number?, -- os.clock() until which this customer can't be lured (Phase C-4b)
}

local queues: { [number]: { ActiveCustomer } } = {}
local customersByOrder: { [string]: ActiveCustomer } = {}
local allCustomers: { [ActiveCustomer]: boolean } = {}
local rng = Random.new()
local customersFolder: Folder
local vipActive = false -- at most one brainrot VIP on the whole server at a time

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
			string.format("COMBO ×%d  +%d coins", state.count, bonus),
			Color3.fromRGB(255, 224, 130)
		)
	end
end

-- What this diner asks for. Prefers the menu, but NEVER comes up empty while the
-- player has unlocked anything at all (owner 2026-08-06: "every time they enter
-- they should order").
--
-- The menu is derived from the production plan — `ProductionService` sets
-- `kitchen.menu[id] = count > 0` — so a player who zeroes their plan empties the
-- menu without realising it. This used to return nil, and the customer then sat
-- down, ordered nothing and walked back out: the single most confusing thing the
-- café could do, because it looked like the game had forgotten them. Falling back
-- to any unlocked dish means the order is always placed. If nothing is stocked it
-- goes unserved and costs Buzz, which is the honest signal that the café has
-- nothing for sale — and `menuIsEmpty` below turns that into a plain-English
-- toast rather than leaving the player to guess.
local function pickUnlockedRecipe(data: Types.PlayerData): (string?, boolean)
	local onMenu: { string } = {}
	local anyUnlocked: { string } = {}
	for recipeId, unlocked in data.unlockedRecipes do
		if unlocked then
			table.insert(anyUnlocked, recipeId)
			if KitchenService:IsOnMenu(data, recipeId) then
				table.insert(onMenu, recipeId)
			end
		end
	end
	local menuIsEmpty = #onMenu == 0
	local pool = if menuIsEmpty then anyUnlocked else onMenu
	if #pool == 0 then
		return nil, menuIsEmpty
	end
	-- Stable order before the roll: pairs() over a map is not deterministic, and
	-- an unstable pool makes "why did they order that" impossible to reason about.
	table.sort(pool)
	return pool[rng:NextInteger(1, #pool)], menuIsEmpty
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

-- ————— the brainrot VIP, as a real seated customer (Bug 2, 2026-07-26) —————
-- The VIP now behaves like any walk-in — enters, sits, orders a RARE dish, and
-- WAITS to be served — instead of the old standalone instant-serve path. It is
-- just an ActiveCustomer with isVip + a forced recipe + the welded brainrot rig.
-- VipService stays the scheduler (picks the #1-Buzz café, calls SpawnVip).

-- The VIP's own customer profile: a single, patient, generous guest (its reward
-- is the earned gift box, not the tip roll — see eatMeal). Kept out of
-- Config/Customers so the normal spawner never rolls it.
local VIP_DEF: Types.CustomerDefinition = {
	id = "vip",
	displayName = "VIP",
	patiencePenaltyPerSecond = 0.2,
	tipMultiplier = 2.0,
	color = Color3.fromRGB(255, 210, 120),
}

-- Build the VIP as the non-humanoid brainrot display model welded onto an
-- invisible Humanoid rig (mirrors the old VipService walker) so the shared
-- customer lifecycle can drive it. Returns nils if the brainrot asset has not
-- finished loading, so the caller simply skips this VIP attempt.
local function spawnVipModel(name: string): (Model?, Humanoid?, BasePart?, TextLabel?)
	local brainrot = if AssetLibraryService then AssetLibraryService:GetVip() else nil
	if not brainrot or not brainrot.PrimaryPart then
		if brainrot then
			brainrot:Destroy()
		end
		return nil, nil, nil, nil
	end

	local model = Instance.new("Model")
	model.Name = "BrainrotVip"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HipHeight = Vip.hipHeight
	humanoid.WalkSpeed = WALK_SPEED -- match the crowd; the VIP is a patron now
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model
	model.PrimaryPart = root

	-- Sit the brainrot on the root so its feet meet the ground, then weld every
	-- part rigidly to the root (its scripts were stripped on load — a solid rig).
	local _, size = brainrot:GetBoundingBox()
	brainrot:PivotTo(root.CFrame * CFrame.new(0, size.Y / 2 - Vip.hipHeight + Vip.rigYOffset, 0))
	for _, d in brainrot:GetDescendants() do
		if d:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = root
		end
	end
	brainrot.Parent = model

	-- An invisible "Head" the shared bubble/mood billboards adornee (the brainrot
	-- prop has no Head of its own); attachMood also looks up a child named "Head".
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Transparency = 1
	head.CanCollide = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = root.CFrame * CFrame.new(0, 2, 0)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = root
	headWeld.Part1 = head
	headWeld.Parent = root

	local label = attachBubbles(head, name)
	return model, humanoid, root, label
end

-- The RARE dish the VIP orders: the fanciest UNLOCKED, on-menu recipe that is
-- NOT a Coffee/Tea drink. Falls back to the priciest on-menu dish if the café
-- has only drinks unlocked, so the VIP always orders something it can be served.
local function pickVipRecipe(data: Types.PlayerData): string?
	local bestRare: string?, bestRarePrice = nil, -1
	local bestAny: string?, bestAnyPrice = nil, -1
	for recipeId, unlocked in data.unlockedRecipes do
		local r = Recipes[recipeId]
		if unlocked and r and KitchenService:IsOnMenu(data, recipeId) then
			if r.basePrice > bestAnyPrice then
				bestAny, bestAnyPrice = recipeId, r.basePrice
			end
			local isDrink = r.category == "Coffee" or r.category == "Tea"
			if not isDrink and r.basePrice > bestRarePrice then
				bestRare, bestRarePrice = recipeId, r.basePrice
			end
		end
	end
	return bestRare or bestAny
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

-- Which chairs are occupied is DERIVED from the live diners, never held in a
-- side table. Any customer still alive, not leaving, and holding a seatId is
-- sitting in that chair. The old mutable "taken" map LEAKED reservations
-- whenever a customer coroutine ended without hitting releaseSeat — an error
-- mid-visit, a furniture re-place changing instanceIds, or a player leaving all
-- stranded a seat as "taken" forever, so new arrivals found the café full while
-- the chairs sat visibly empty (owner bug, 2026-07-26). Deriving occupancy from
-- reality on every scan cannot drift, so a genuinely-free chair is always taken.
local function occupiedSeatIds(userId: number, exclude: ActiveCustomer?): { [string]: boolean }
	local held: { [string]: boolean } = {}
	for other in allCustomers do
		if
			other ~= exclude
			and other.userId == userId
			and not other.leaving
			and other.seatId ~= nil
		then
			held[other.seatId :: string] = true
		end
	end
	return held
end

-- Where seat `slot` sits on a piece that seats more than one (owner haul
-- 2026-08-06: table-and-chairs SETS). A single chair keeps the placement CFrame
-- untouched, which preserves BuildService.autoFaceSeats turning it toward its
-- table. Multi-seat pieces place their diners around the footprint and turn each
-- to look at the middle, so a four-top reads as four people sharing a table
-- rather than four people stacked on its centre.
--
-- The offsets are geometric, not read from the model: a Creator Store set does
-- not tell us where its chairs are, and 0.3 of the footprint lands on them for
-- every set in the catalogue (checked against each one's own proportions).
local function seatSlotCFrame(centre: CFrame, def: any, slot: number): CFrame
	local count = math.max(1, math.floor(tonumber(def.seatCount) or 1))
	if count <= 1 then
		return centre
	end
	local w = (tonumber(def.width) or 1) * Grid.CELL_SIZE
	local d = (tonumber(def.depth) or 1) * Grid.CELL_SIZE
	local offsets
	if count == 2 then
		-- Two chairs face each other across the LONGER axis of the piece.
		offsets = if w >= d
			then { Vector3.new(-w * 0.3, 0, 0), Vector3.new(w * 0.3, 0, 0) }
			else { Vector3.new(0, 0, -d * 0.3), Vector3.new(0, 0, d * 0.3) }
	else
		offsets = {
			Vector3.new(-w * 0.3, 0, 0),
			Vector3.new(w * 0.3, 0, 0),
			Vector3.new(0, 0, -d * 0.3),
			Vector3.new(0, 0, d * 0.3),
		}
	end
	local offset = offsets[((slot - 1) % #offsets) + 1]
	local seatPos = (centre * CFrame.new(offset)).Position
	-- Look at the centre of the piece, keeping the seat's own height.
	local target = Vector3.new(centre.Position.X, seatPos.Y, centre.Position.Z)
	if (target - seatPos).Magnitude < 0.05 then
		return CFrame.new(seatPos) * centre.Rotation
	end
	return CFrame.lookAt(seatPos, target)
end

-- Pick a genuinely-free placed seat; returns its world CFrame + a seat key.
--
-- The key is `instanceId#slot`, so one placed piece can hold as many diners as
-- its `seatCount`. It used to be the bare instanceId, which capped every piece
-- at one diner however many chairs its model showed — that is why a set with
-- four chairs would have seated one person and left three chairs empty.
-- `occupiedSeatIds` keys on whatever string this returns, so it needed no change.
local function claimSeat(player: Player, cust: ActiveCustomer): (CFrame?, string?, string?)
	local data = DataService:GetProfile(player)
	local origin = CafeService:GetPlotOrigin(player)
	if not data or not origin then
		return nil, nil, nil
	end
	local taken = occupiedSeatIds(player.UserId, cust)
	local seatNumber = 0
	for _, placed in data.placedFurniture do
		local def = Furniture[placed.catalogId]
		if def and def.seatCount > 0 then
			local w, d = Grid.footprintSize(def.width, def.depth, placed.rotation)
			local seatX = placed.gridX + w / 2
			local seatZ = placed.gridY + d / 2
			local inKitchen = seatX < World.kitchenWidthCells and seatZ < World.kitchenDepthCells
			if not inKitchen then
				local cf = Grid.cellToWorld(
					origin,
					placed.gridX,
					placed.gridY,
					def.width,
					def.depth,
					placed.rotation,
					def.height
				)
				for slot = 1, def.seatCount do
					seatNumber += 1
					local key = placed.instanceId .. "#" .. tostring(slot)
					if not taken[key] then
						return seatSlotCFrame(cf, def, slot), key, "TABLE " .. tostring(seatNumber)
					end
				end
			end
		end
	end
	return nil, nil, nil
end

-- Free this diner's chair immediately (occupancy is derived from seatId, so
-- clearing it is the whole release).
local function releaseSeat(cust: ActiveCustomer)
	cust.seatId = nil
	cust.seatCf = nil
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
	label.Text = "Tip!"
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
		Fx.floatText(tip.Position + Vector3.new(0, 1, 0), "+" .. tostring(amount) .. " coins")
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

-- The EARNED VIP gift box, dropped at the table when the VIP is served (moved
-- here from the old standalone VipService). A GIFT, not a loot box: opened for
-- free, its weighted odds never touch money (Config/Gifts, HANDOFF §1). Modelled
-- on dropTip — the shared prompt/claim/despawn pattern (a factory is owed once a
-- fourth copy appears; see IMPLEMENTATION_MAP "known risks").
local function dropVipGift(player: Player, seatCf: CFrame)
	local folder = CafeService:GetFurnitureFolder(player)
	local plotModel = folder and folder.Parent
	if not plotModel then
		return
	end
	local boxCf = CFrame.new(seatCf.Position + seatCf.LookVector * 1.6 + Vector3.new(0, 1.5, 0))

	local box = Instance.new("Part")
	box.Name = "VipGift"
	box.Size = Vector3.new(2.4, 2.4, 2.4)
	box.Color = Color3.fromRGB(230, 90, 140)
	box.Material = Enum.Material.SmoothPlastic
	box.Anchored = true
	box.CanCollide = false
	box.CFrame = boxCf

	local ribbon = Instance.new("Part")
	ribbon.Name = "Ribbon"
	ribbon.Size = Vector3.new(2.55, 0.4, 2.55)
	ribbon.Color = Color3.fromRGB(255, 220, 120)
	ribbon.Material = Enum.Material.SmoothPlastic
	ribbon.Anchored = true
	ribbon.CanCollide = false
	ribbon.CFrame = boxCf
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = box
	weld.Part1 = ribbon
	weld.Parent = box
	ribbon.Parent = box

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4.5, 1.4)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 235, 170)
	label.TextStrokeTransparency = 0.3
	label.Text = "🎁 VIP Gift — open!"
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open gift"
	prompt.ObjectText = "VIP Gift"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = box

	local claimed = false
	prompt.Triggered:Connect(function(who)
		-- Only the café owner opens the gift left in their own café.
		if claimed or who ~= player then
			return
		end
		claimed = true
		local reward = RewardMath.rollGift(rng:NextNumber(), rng:NextNumber())
		if reward.kind == "reputation" then
			EconomyService:AddReputation(who, reward.amount)
		else
			EconomyService:AddCoins(who, reward.amount)
		end
		Fx.coinBurst(box.Position, 14)
		Fx.floatText(
			box.Position + Vector3.new(0, 1.6, 0),
			"🎁 +" .. tostring(reward.amount) .. " " .. reward.label
		)
		if AnalyticsService then
			AnalyticsService:Track(
				who,
				"vip_gift_opened",
				{ kind = reward.kind, amount = reward.amount }
			)
		end
		box:Destroy()
	end)

	box.Parent = plotModel
	task.delay(Vip.giftDespawnSeconds, function()
		if box.Parent ~= nil then
			box:Destroy()
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

	local seatCf = cust.seatCf
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

			-- Eat with a happy bob. The bob count is derived from
			-- Kitchen.diningSeconds so table time is tuned in config rather than by
			-- counting animation frames here.
			local basePivot = cust.model:GetPivot()
			local bobs = math.max(4, math.floor((tonumber(Kitchen.diningSeconds) or 6.6) / 0.55))
			local midBob = math.floor(bobs / 2)
			for i = 1, bobs do
				if cust.leaving or cust.root.Parent == nil then
					break
				end
				cust.model:PivotTo(basePivot * CFrame.new(0, (i % 2) * 0.12, 0))
				if i == midBob then
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
							if cleaned or plate.Parent == nil then
								return
							end
							-- P2c: the owner, or a visitor working in their café.
							-- The Buzz still goes to the OWNER; the helper is paid
							-- separately inside TryWork.
							if
								not (
									SocialService
									and SocialService:TryWork(who, player, "clean_plate")
								)
							then
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

				-- The VIP leaves the EARNED gift box (its premium) plus a small
				-- reputation bump for the visit; everyone else may leave a tip —
				-- the seated-dining exclusive that rewards having chairs.
				if cust.isVip then
					dropVipGift(player, seatCf)
					EconomyService:AddReputation(player, Vip.premiumReputation)
					Fx.floatText(
						seatCf.Position + Vector3.new(0, 5, 0),
						"⭐ The VIP loved it! +" .. tostring(Vip.premiumReputation) .. " rep",
						Color3.fromRGB(255, 220, 120)
					)
				elseif recipe then
					local tip = RewardMath.tipAmount(
						recipe,
						rng:NextInteger(1, 100),
						cust.def.tipMultiplier
					)
					if tip > 0 then
						dropTip(player, seatCf, tip)
					end
				end

				-- Remember this diner as a REGULAR: next time they may come back
				-- by name asking for today's dish (persisted, max 8). The VIP is a
				-- one-off server event, never a named regular.
				local data = if cust.isVip then nil else DataService:GetProfile(player)
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
			-- Sit on after the plate is cleared. This is the half of a visit that
			-- actually FILLS the room (Kitchen.lingerSeconds — the study lives in
			-- that config). Without it a seat turned over every 30 seconds and the
			-- café measured as empty at every one of the ten stages.
			local linger = math.max(0, tonumber(Kitchen.lingerSeconds) or 0)
			if linger > 0 then
				cust.bubble.Text = "☕"
				local leaveAt = os.clock() + linger
				while os.clock() < leaveAt do
					if cust.leaving or cust.root.Parent == nil then
						break
					end
					task.wait(0.5)
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
	releaseSeat(cust)

	if cust.root.Parent ~= nil then
		cust.bubble.Text = if announcedPay ~= nil
			then "😊 +" .. tostring(announcedPay) .. " coins"
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
	if cust.isVip then
		Fx.floatText(
			cust.root.Position + Vector3.new(0, 6, 0),
			"⭐ A VIP has arrived!",
			Color3.fromRGB(255, 220, 120)
		)
	elseif cust.regular then
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
			-- Come to a full stop on the mark. Without this the humanoid keeps the
			-- last move vector and drifts off its slot, so a queue that was spaced
			-- correctly on arrival slowly collapses back into a huddle.
			cust.humanoid:Move(Vector3.zero)
			if cust.anim then
				cust.anim.setSeated(false)
			end
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

	local seatCf, seatId, tableLabel = claimSeat(player, cust)
	if not seatCf or not seatId then
		stormOut(cust, Kitchen.buzzPerWalkout, "😡 NO EMPTY CHAIR!")
		KitchenService:AddBuzz(player, Kitchen.buzzPerWalkout)
		CafeOperationsService:AdjustSatisfaction(player, -Operations.satisfactionNoSeatLoss)
		-- The one walkout a new player cannot diagnose: the café looks finished,
		-- but nothing sells because no chair was ever placed. Every other income
		-- source keeps ticking (session gifts), so the till still moves and the
		-- cause stays invisible. Point at the fix — which is free — and let the
		-- client's per-key rate limit stop it becoming a nag.
		local seatData = DataService:GetProfile(player)
		if seatData then
			Remotes.event("Notify"):FireClient(player, {
				kind = "offer",
				offer = if SeatMath.seatsInInventory(seatData) > 0
					then "no_seats"
					else "no_seats_buy",
			})
		end
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
		releaseSeat(cust)
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
	local recipeId, menuIsEmpty = nil, false
	if data then
		recipeId, menuIsEmpty = pickUnlockedRecipe(data)
	end
	if menuIsEmpty then
		-- Say it once per arrival rather than silently serving nothing.
		Remotes.event("Notify"):FireClient(player, {
			kind = "error",
			text = "Nothing is on your menu — set a dish in PANTRY → AUTO PRODUCTION.",
		})
	end
	if cust.favourite and data and KitchenService:IsOnMenu(data, cust.favourite) then
		recipeId = cust.favourite
	end
	-- The VIP orders the exact RARE dish chosen at spawn (overrides any pick),
	-- as long as it is still on the menu.
	if cust.forcedRecipe and data and KitchenService:IsOnMenu(data, cust.forcedRecipe) then
		recipeId = cust.forcedRecipe
	end
	if not recipeId then
		releaseSeat(cust)
		cust.root.Anchored = false
		depart(cust, streetExit)
		return
	end
	local orderId =
		OrderService:CreateOrder(player, recipeId, cust.def.id, seatId, tableLabel, cust.root)
	if not orderId then
		releaseSeat(cust)
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
		releaseSeat(cust)
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
	releaseSeat(cust)
	cust.root.Anchored = false
	if cust.anim then
		cust.anim.setSeated(false)
	end
	task.wait(1.5)
	depart(cust, streetExit)
end

-- Construct one normal walk-in for `player` and start its visit. Shared by the
-- Buzz-driven spawner (Start) and the mischief recruit path — a lured customer
-- re-appears here at the caster's café. `immuneUntil` (os.clock) marks a freshly
-- lured customer as un-lurable for a grace period (Phase C-4b).
local function spawnWalkIn(player: Player, origin: CFrame, immuneUntil: number?)
	local q = queues[player.UserId]
	if q == nil then
		q = {}
		queues[player.UserId] = q
	end
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
		lureImmuneUntil = immuneUntil,
	}
	table.insert(q, cust)
	allCustomers[cust] = true
	cust.model.Destroying:Connect(function()
		allCustomers[cust] = nil
	end)
	task.spawn(runActiveVisit, player, cust, origin)
end

-- A customer at `fromUserId`'s café eligible to be lured away (Phase C-4b): still
-- WAITING (not served, not seated, no order yet), NOT the VIP (VIPs resist), not
-- already leaving, and past any immunity grace. nil = nobody to take.
local function eligibleLureTarget(fromUserId: number): ActiveCustomer?
	for cust in allCustomers do
		if
			cust.userId == fromUserId
			and not cust.leaving
			and not cust.served
			and not cust.isVip
			and cust.seatId == nil
			and cust.orderId == nil
			and (cust.lureImmuneUntil == nil or os.clock() >= cust.lureImmuneUntil)
		then
			return cust
		end
	end
	return nil
end

-- Spawn the brainrot VIP as a real customer at `target`'s café (called by
-- VipService, the scheduler that picks the #1-Buzz café). Returns false — so
-- VipService just retries next interval — if a VIP is already out, the profile/
-- café isn't ready, the café has nothing servable, or the brainrot asset hasn't
-- loaded. The VIP then enters, sits, orders its RARE dish and waits like anyone.
function CustomerService.SpawnVip(_self: any, target: Player): boolean
	if vipActive then
		return false
	end
	if not DataService:IsLoaded(target) then
		return false
	end
	local origin = CafeService:GetPlotOrigin(target)
	local data = DataService:GetProfile(target)
	if not origin or not data then
		return false
	end
	local recipeId = pickVipRecipe(data)
	if not recipeId then
		return false -- the café has no on-menu dish yet
	end
	local model, humanoid, root, bubble = spawnVipModel(VIP_DEF.displayName)
	if not model or not humanoid or not root or not bubble then
		return false -- brainrot template still loading; skip this attempt
	end

	vipActive = true
	local q = queues[target.UserId]
	if q == nil then
		q = {}
		queues[target.UserId] = q
	end
	local cust: ActiveCustomer = {
		userId = target.UserId,
		model = model,
		humanoid = humanoid,
		root = root,
		bubble = bubble,
		def = VIP_DEF,
		baseHip = humanoid.HipHeight,
		name = VIP_DEF.displayName,
		regular = false,
		favourite = nil,
		spawnClock = os.clock(),
		orderId = nil,
		served = false,
		leaving = false,
		isVip = true,
		forcedRecipe = recipeId,
	}
	table.insert(q, cust)
	allCustomers[cust] = true
	cust.model.Destroying:Connect(function()
		allCustomers[cust] = nil
		vipActive = false -- free the single-VIP slot the moment this one despawns
	end)
	task.spawn(runActiveVisit, target, cust, origin)
	-- Failsafe: no legitimate visit outlasts line + serve patience (~5.5 min); if
	-- the coroutine ever dies mid-visit the model would strand vipActive forever,
	-- so force the despawn (which frees the slot via Destroying) well past that.
	task.delay(600, function()
		if cust.model.Parent ~= nil then
			cust.leaving = true
			cust.model:Destroy()
		end
	end)
	return true
end

-- Is there a customer at `fromUserId`'s café eligible to be lured? MischiefService
-- peeks with this before committing a smell bomb / recruit roll (Phase C-4b).
function CustomerService.HasLureTarget(_self: any, fromUserId: number): boolean
	return eligibleLureTarget(fromUserId) ~= nil
end

-- Pull ONE eligible waiting customer from `fromPlayer` to `toPlayer` (Phase C-4b
-- mischief; the guardrails live in MischiefService). The victim's customer leaves
-- CALMLY — no Buzz/coin/satisfaction penalty, so there is no permanent loss — and
-- a fresh, temporarily lure-immune walk-in appears at the caster's café. Returns
-- false if the caster has no café or nobody was eligible.
function CustomerService.LureOne(
	_self: any,
	fromPlayer: Player,
	toPlayer: Player,
	immunitySeconds: number
): boolean
	local toOrigin = CafeService:GetPlotOrigin(toPlayer)
	if not toOrigin then
		return false
	end
	local victim = eligibleLureTarget(fromPlayer.UserId)
	if not victim then
		return false
	end
	-- Leave the neighbour calmly: the queue loop turns cust.leaving into a plain
	-- depart() (walk out) with NO penalty — unlike an angry walkout.
	victim.bubble.Text = "🚶 Off to another café…"
	victim.leaving = true
	-- The "recruited" customer re-appears at the caster's café, immune for a grace
	-- period so it can't be instantly ping-ponged back.
	spawnWalkIn(toPlayer, toOrigin, os.clock() + immunitySeconds)
	return true
end

-- Drive EVERY customer out of `fromPlayer`'s café (P2b smell bomb). Unlike the
-- lure, nobody transfers to the caster — they simply walk out. They leave via the
-- existing `leaving` path, which cancels any order, frees the seat and walks them
-- to the street with NO Buzz, satisfaction or reputation penalty (an angry
-- walkout, by contrast, costs all three). VIPs resist, as they do every other
-- mischief, and anyone already served keeps the meal they paid for. Returns how
-- many were driven out, so the caller can refuse to spend a bomb on an empty room.
function CustomerService.ScareAll(_self: any, fromPlayer: Player): number
	local count = 0
	for cust in allCustomers do
		if
			cust.userId == fromPlayer.UserId
			and not cust.leaving
			and not cust.served
			and not cust.isVip
		then
			cust.bubble.Text = "🤢 Ugh — what IS that smell?!"
			cust.leaving = true
			count += 1
		end
	end
	return count
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
			then "😊 +" .. tostring(coinsAwarded) .. " coins"
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
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	SocialService = ServiceRegistry.get("SocialService")
end

function CustomerService.Start(_self: any)
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = workspace

	-- Buzz drives the crowd: high-Buzz cafés get customers every few seconds.
	local nextSpawnAt: { [number]: number } = {}
	-- Arrivals still owed to a player's WELCOME RUSH. Seeded on join and counted
	-- down here, so the burst uses the same spawn path as everything else — one
	-- queue, one cap, one lifecycle.
	local rushLeft: { [number]: number } = {}
	local function armRush(player: Player)
		rushLeft[player.UserId] = math.max(0, math.floor(Kitchen.welcomeRushCount or 0))
		nextSpawnAt[player.UserId] = 0 -- first one lands immediately
	end
	for _, player in Players:GetPlayers() do
		armRush(player)
	end
	Players.PlayerAdded:Connect(armRush)
	Players.PlayerRemoving:Connect(function(player)
		rushLeft[player.UserId] = nil
		nextSpawnAt[player.UserId] = nil
	end)

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
						local owed = rushLeft[player.UserId] or 0
						-- The rush WAITS FOR A CHAIR. Measured 2026-08-06 on a
						-- brand-new profile, which places none: six arrivals in the
						-- first sixty seconds, none of them ever seated, and
						-- "😡 NO EMPTY CHAIR!" seventeen times — about −12 Buzz from
						-- a starting 10, before the player had done anything at all.
						-- A rush at an unfurnished café is not a busy café, it is a
						-- riot. Banking the credits instead means the rush lands the
						-- moment the tutorial's first chairs go down, which is
						-- exactly when it reads as the café coming alive.
						local data = DataService:GetProfile(player)
						local hasSeat = data ~= nil and SeatMath.usableSeats(data) > 0
						local interval
						if owed > 0 and hasSeat then
							rushLeft[player.UserId] = owed - 1
							interval = Kitchen.welcomeRushIntervalSeconds or 3.5
						else
							local demandPerMinute = KitchenService:GetDemandRate(player)
							interval = 60 / math.max(0.2, demandPerMinute)
						end
						nextSpawnAt[player.UserId] = os.clock() + interval
						spawnWalkIn(player, origin)
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
