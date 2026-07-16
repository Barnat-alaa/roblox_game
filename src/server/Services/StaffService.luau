--!strict
-- Staff v3 (S2 service theater): four employees per café with DEFINED JOBS —
-- the full Café-World-style choreography (see docs/CAFE_WORLD_PARITY.md C/B):
--   Mia  (barista) — prepares DRINKS (Coffee/Tea) at the coffee machine; also
--                    rescues manual orders left waiting too long (v1 role).
--   Sam  (cook)    — prepares FOOD dishes at the oven/prep station.
--                    Both show a bubble with the dish icon when it's ready.
--   Noah (waiter)  — walks over, picks the finished plate up, carries it to
--                    the table and sets it in front of the customer.
--   Pia  (cleaner) — collects the emptied plate after the meal and carries it
--                    off to be washed (+1 Buzz per plate).
-- All server-authoritative; grant paths stay in OrderService/KitchenService —
-- this whole flow is post-payment theater, so it can never dupe a coin.
-- Hiring/wages arrive with monetisation-era balancing (Phase 6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local EconomyConfig = require(Shared.Config.Economy)
local Recipes = require(Shared.Config.Recipes)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)
local NpcAnimator = require(script.Parent.Parent.NpcAnimator)
local NpcNav = require(script.Parent.Parent.NpcNav)
local PlateFactory = require(script.Parent.Parent.PlateFactory)

local StaffService = {}
StaffService.Name = "StaffService"

local DataService: any
local OrderService: any
local CafeService: any
local KitchenService: any
local AssetLibraryService: any

local CHECK_INTERVAL = 5
local STAFF_WALK_SPEED = 11

type StaffNpc = {
	model: Model,
	bubble: TextLabel,
	displayName: string, -- bubble resting text, e.g. "Mia · Barista"
	humanoid: Humanoid?,
	root: BasePart?,
	home: CFrame,
	busy: boolean,
	baseHip: number, -- resting HipHeight (real rigs differ); the waddle bobs around it
}

type Crew = {
	barista: StaffNpc?,
	cook: StaffNpc?,
	waiter: StaffNpc?,
	cleaner: StaffNpc?,
}

local crewByUser: { [number]: Crew } = {}
local messQueues: { [number]: { Model } } = {}
local rng = Random.new()

local function crewList(crew: Crew): { StaffNpc }
	local list = {}
	for _, npc in { crew.barista, crew.cook, crew.waiter, crew.cleaner } do
		table.insert(list, npc)
	end
	return list
end

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

type StaffLook = {
	displayName: string,
	role: string,
	skin: Color3,
	shirt: Color3,
	hair: Color3,
	walker: boolean,
}

-- Build a chibi staff member. Walkers get a humanoid rig (unanchored root);
-- the barista stays a cheap anchored statue.
local function buildStaff(base: CFrame, look: StaffLook): StaffNpc
	-- Prefer a vetted Creator Store rig (Step S1); fall back to the procedural
	-- chibi staff below when no template is loaded.
	local rig: Model? = if AssetLibraryService then AssetLibraryService:GetStaff(look.role) else nil
	if rig then
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = rig:FindFirstChild("Head") :: BasePart?
		if humanoid and root and head then
			rig.Name = look.role
			humanoid.WalkSpeed = STAFF_WALK_SPEED
			humanoid.BreakJointsOnDeath = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			local _, size = rig:GetBoundingBox()
			rig:PivotTo(base * CFrame.new(0, size.Y / 2, 0))
			rig.PrimaryPart = root

			-- Role uniform: a coloured apron so staff on customer rig bases
			-- read as STAFF at a glance (waiter navy, cleaner green, …).
			local torso = rig:FindFirstChild("Torso") or rig:FindFirstChild("UpperTorso")
			if torso and torso:IsA("BasePart") then
				local apron = Instance.new("Part")
				apron.Name = "UniformApron"
				apron.Size = Vector3.new(torso.Size.X * 1.04, torso.Size.Y * 0.85, 0.16)
				apron.Color = look.shirt
				apron.Material = Enum.Material.Fabric
				apron.CanCollide = false
				apron.CanQuery = false
				apron.Massless = true
				apron.CFrame = torso.CFrame
					* CFrame.new(0, -torso.Size.Y * 0.08, -(torso.Size.Z / 2 + 0.1))
				apron.Parent = rig
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = torso
				weld.Part1 = apron
				weld.Parent = torso
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
			label.Text = look.displayName
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = label
			label.Parent = gui

			local staffFolder = workspace:FindFirstChild("Staff")
			if not staffFolder then
				staffFolder = Instance.new("Folder")
				staffFolder.Name = "Staff"
				staffFolder.Parent = workspace
			end
			rig.Parent = staffFolder
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			NpcAnimator.setup(humanoid)

			return {
				model = rig,
				bubble = label,
				displayName = look.displayName,
				humanoid = humanoid,
				root = root,
				home = base * CFrame.new(0, 2, 0),
				busy = false,
				baseHip = humanoid.HipHeight,
			}
		end
		rig:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = look.role

	local root: BasePart
	local humanoid: Humanoid? = nil

	if look.walker then
		local r = Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Size = Vector3.new(2, 2, 1.1)
		r.Color = look.shirt
		r.Material = Enum.Material.SmoothPlastic
		r.CFrame = base * CFrame.new(0, 2, 0)
		r.Parent = model
		root = r

		local legs = Instance.new("Part")
		legs.Name = "Legs"
		legs.Size = Vector3.new(1.7, 1.2, 1)
		legs.Color = Color3.fromRGB(50, 50, 60)
		legs.Material = Enum.Material.SmoothPlastic
		legs.CanCollide = false
		legs.CanQuery = false
		legs.Massless = true
		legs.CFrame = r.CFrame * CFrame.new(0, -1.55, 0)
		legs.Parent = model
		local legWeld = Instance.new("WeldConstraint")
		legWeld.Part0 = r
		legWeld.Part1 = legs
		legWeld.Parent = r

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(2.2, 2.2, 2.2)
		head.Color = look.skin
		head.Material = Enum.Material.SmoothPlastic
		head.CanCollide = false
		head.Massless = true
		head.CFrame = r.CFrame * CFrame.new(0, 2.05, 0)
		head.Parent = model
		local headWeld = Instance.new("WeldConstraint")
		headWeld.Part0 = r
		headWeld.Part1 = head
		headWeld.Parent = r

		local hair = Instance.new("Part")
		hair.Name = "Hair"
		hair.Shape = Enum.PartType.Ball
		hair.Size = Vector3.new(2.3, 2.3, 2.3)
		hair.Color = look.hair
		hair.Material = Enum.Material.SmoothPlastic
		hair.CanCollide = false
		hair.CanQuery = false
		hair.Massless = true
		hair.CFrame = head.CFrame * CFrame.new(0, 0.28, 0.12)
		hair.Parent = model
		local hairWeld = Instance.new("WeldConstraint")
		hairWeld.Part0 = head
		hairWeld.Part1 = hair
		hairWeld.Parent = head

		local apron = Instance.new("Part")
		apron.Name = "Apron"
		apron.Size = Vector3.new(1.95, 1.5, 0.15)
		apron.Color = Color3.fromRGB(245, 242, 235)
		apron.CanCollide = false
		apron.CanQuery = false
		apron.Massless = true
		apron.CFrame = r.CFrame * CFrame.new(0, -0.2, -0.62)
		apron.Parent = model
		local apronWeld = Instance.new("WeldConstraint")
		apronWeld.Part0 = r
		apronWeld.Part1 = apron
		apronWeld.Parent = r

		local h = Instance.new("Humanoid")
		h.RequiresNeck = false
		h.BreakJointsOnDeath = false
		h.WalkSpeed = STAFF_WALK_SPEED
		h.HipHeight = 1
		h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		h.Parent = model
		humanoid = h
		model.PrimaryPart = r
	else
		part(
			model,
			"Legs",
			Vector3.new(1.7, 1.2, 1),
			base * CFrame.new(0, 0.6, 0),
			Color3.fromRGB(50, 50, 60)
		)
		local torso =
			part(model, "Torso", Vector3.new(2, 2, 1.1), base * CFrame.new(0, 2.2, 0), look.shirt)
		part(
			model,
			"Apron",
			Vector3.new(1.95, 1.5, 0.15),
			base * CFrame.new(0, 2, -0.62),
			Color3.fromRGB(245, 242, 235)
		)
		part(
			model,
			"Head",
			Vector3.new(2.2, 2.2, 2.2),
			base * CFrame.new(0, 4.25, 0),
			look.skin,
			Enum.PartType.Ball
		)
		part(
			model,
			"Hair",
			Vector3.new(2.3, 2.3, 2.3),
			base * CFrame.new(0, 4.53, 0.12),
			look.hair,
			Enum.PartType.Ball
		)
		root = torso
	end

	for _, x in { -0.38, 0.38 } do
		local head = model:FindFirstChild("Head") :: BasePart
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Cylinder
		eye.Size = Vector3.new(0.1, 0.22, 0.22)
		eye.Color = Color3.fromRGB(35, 30, 28)
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Massless = true
		eye.Anchored = not look.walker
		eye.CFrame = head.CFrame * CFrame.new(x, 0.12, -1.02) * CFrame.Angles(0, math.rad(90), 0)
		eye.Parent = model
		if look.walker then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = eye
			weld.Parent = head
		end
	end

	local head = model:FindFirstChild("Head") :: BasePart
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
	label.Text = look.displayName
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	label.Parent = gui

	local staffFolder = workspace:FindFirstChild("Staff")
	if not staffFolder then
		staffFolder = Instance.new("Folder")
		staffFolder.Name = "Staff"
		staffFolder.Parent = workspace
	end
	model.Parent = staffFolder
	if look.walker and root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end

	return {
		model = model,
		bubble = label,
		displayName = look.displayName,
		humanoid = humanoid,
		root = if look.walker then root else nil,
		home = base * CFrame.new(0, 2, 0),
		busy = false,
		baseHip = 1,
	}
end

-- Staff walk: pathfinding around collidable furniture (NpcNav), waddle +
-- timeout teleport as last resort — same recovery philosophy as customers.
-- (The waiter used to "teleport" constantly: his straight-line walk hit the
-- now-solid tables and fell into the timeout recovery every trip.)
local function staffWalk(npc: StaffNpc, target: Vector3)
	local humanoid = npc.humanoid
	local root = npc.root
	if not humanoid or not root then
		return
	end
	NpcNav.walkTo(npc.model, humanoid, root, target, { baseHip = npc.baseHip })
end

local function crewOf(userId: number): Crew
	local crew = crewByUser[userId]
	if not crew then
		crew = {}
		crewByUser[userId] = crew
	end
	return crew
end

-- Wait (bounded) for a staff member to be free. Returns true when claimed.
local function claimStaff(npc: StaffNpc?, timeout: number): boolean
	if not npc then
		return false
	end
	local deadline = os.clock() + timeout
	while npc.busy do
		if os.clock() > deadline or npc.model.Parent == nil then
			return false
		end
		task.wait(0.25)
	end
	if npc.model.Parent == nil or not npc.root or (npc.root :: BasePart).Parent == nil then
		return false
	end
	npc.busy = true
	return true
end

-- Hold a plate in front of a staff member while they walk; returns a release
-- function. The plate is anchored, so a light follow loop beats welds here.
local function carryPlate(npc: StaffNpc, plate: Model): () -> ()
	local carrying = true
	task.spawn(function()
		while carrying and plate.Parent ~= nil do
			local root = npc.root
			if not root or root.Parent == nil then
				break
			end
			plate:PivotTo(CFrame.new((root.CFrame * CFrame.new(0, 0.2, -1.4)).Position))
			task.wait(0.06)
		end
	end)
	return function()
		carrying = false
	end
end

-- Find where a dish gets prepared: the matching placed appliance, and a spot
-- BESIDE it to stand (the appliance itself is a collidable navmesh obstacle).
local function prepStationFor(player: Player, recipe: any, fallback: Vector3): (Vector3, Vector3)
	local wanted: { string } = if recipe.category == "Coffee" or recipe.category == "Tea"
		then { "coffee_machine", "counter" }
		else { recipe.applianceId, "oven", "prep_station", "counter" }
	local folder = CafeService:GetFurnitureFolder(player)
	if folder then
		for _, name in wanted do
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child.Name == name then
					local station = child:GetPivot().Position
					local away = (fallback - station) * Vector3.new(1, 0, 1)
					local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
					return station, station + dir * 3
				end
			end
		end
	end
	return fallback, fallback
end

-- The S2 service theater: the right preparer (barista for drinks, cook for
-- food) walks to their appliance and finishes the dish (bubble shows its
-- icon), then the waiter carries the plate to the table. Yields until the
-- plate is in front of the customer. Every stage degrades gracefully — busy
-- or missing staff just means the plate appears at the next stage directly —
-- so a customer is never blocked on theater. Returns (plate, food) or nil.
function StaffService.DeliverMeal(
	_self: any,
	player: Player,
	recipeId: string,
	seatCf: CFrame
): (Model?, Instance?)
	local recipe = Recipes[recipeId]
	local folder = CafeService:GetFurnitureFolder(player)
	if not recipe or not folder then
		return nil, nil
	end
	local plotModel = folder.Parent :: Model
	local crew = crewOf(player.UserId)
	local icon = recipe.icon or "🍽️"
	-- Where the finished plate must land: on the table, in front of the chair.
	local tableCf = CFrame.new(seatCf.Position + seatCf.LookVector * 1.8 + Vector3.new(0, 1.15, 0))

	local isDrink = recipe.category == "Coffee" or recipe.category == "Tea"
	local preparer = if isDrink then (crew.barista or crew.cook) else (crew.cook or crew.barista)
	local fallbackPos = if preparer then preparer.home.Position else seatCf.Position
	local station, standAt = prepStationFor(player, recipe, fallbackPos)

	local plate: Model, food: Instance
	-- STAGE 1 — preparation, with the "dish ready" icon bubble.
	if preparer and claimStaff(preparer, 6) then
		preparer.bubble.Text = if isDrink then "☕ Preparing…" else "🍳 Preparing…"
		staffWalk(preparer, standAt)
		task.wait(1.6)
		preparer.bubble.Text = icon .. " " .. recipe.displayName .. " ✓"
		plate, food = PlateFactory.make(AssetLibraryService, recipe)
		plate:PivotTo(CFrame.new(station.X, 3.3, station.Z))
		plate.Parent = plotModel
		task.delay(1.4, function()
			if preparer.model.Parent ~= nil then
				staffWalk(preparer, preparer.home.Position)
				preparer.bubble.Text = preparer.displayName
			end
			preparer.busy = false
		end)
	else
		plate, food = PlateFactory.make(AssetLibraryService, recipe)
		plate:PivotTo(CFrame.new(station.X, 3.3, station.Z))
		plate.Parent = plotModel
	end

	-- STAGE 2 — the waiter picks the plate up and carries it to the table.
	local waiter = crew.waiter
	if waiter and claimStaff(waiter, 6) then
		waiter.bubble.Text = "🍽️ Coming through!"
		staffWalk(waiter, plate:GetPivot().Position)
		local release = carryPlate(waiter, plate)
		staffWalk(waiter, seatCf.Position + seatCf.RightVector * 2.4)
		release()
		plate:PivotTo(tableCf)
		task.spawn(function()
			task.wait(0.4)
			if waiter.model.Parent ~= nil then
				staffWalk(waiter, waiter.home.Position)
				waiter.bubble.Text = waiter.displayName
			end
			waiter.busy = false
		end)
	else
		task.wait(0.8) -- beat so the "ready" bubble reads even with no waiter
		plate:PivotTo(tableCf)
	end

	return plate, food
end

-- Cleaner queue: emptied plates diners leave behind (whole plate models).
function StaffService.NotifyMess(_self: any, player: Player, mess: Model)
	local queue = messQueues[player.UserId]
	if not queue then
		queue = {}
		messQueues[player.UserId] = queue
	end
	table.insert(queue, mess)
	-- Failsafe despawn so a missing cleaner never litters forever.
	task.delay(180, function()
		if mess.Parent ~= nil then
			mess:Destroy()
		end
	end)
end

-- Pia collects the empty plate and carries it off to be washed (+1 Buzz).
local function runCleaner(player: Player)
	local crew = crewOf(player.UserId)
	local cleaner = crew.cleaner
	local queue = messQueues[player.UserId]
	if not cleaner or cleaner.busy or not queue or #queue == 0 then
		return
	end
	local mess = table.remove(queue, 1)
	if not mess or mess.Parent == nil then
		return
	end
	if not claimStaff(cleaner, 0.1) then
		table.insert(queue, 1, mess)
		return
	end
	task.spawn(function()
		cleaner.bubble.Text = "🧹 On it!"
		staffWalk(cleaner, mess:GetPivot().Position)
		if mess.Parent ~= nil then
			Fx.floatText(
				mess:GetPivot().Position + Vector3.new(0, 1.2, 0),
				"+1 🔥",
				Color3.fromRGB(255, 180, 120)
			)
			KitchenService:AddBuzz(player, 1)
			-- Carry the dirty plate back to the kitchen and wash it.
			local release = carryPlate(cleaner, mess)
			staffWalk(cleaner, cleaner.home.Position)
			release()
			cleaner.bubble.Text = "🧼 Washing…"
			task.wait(1.4)
			if mess.Parent ~= nil then
				mess:Destroy()
			end
		else
			staffWalk(cleaner, cleaner.home.Position)
		end
		cleaner.bubble.Text = cleaner.displayName
		cleaner.busy = false
	end)
end

local function ensureCrew(player: Player)
	local origin = CafeService:GetPlotOrigin(player)
	if not origin then
		return
	end
	local crew = crewOf(player.UserId)
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE

	if crew.barista == nil then
		-- Walker now: she walks to the coffee machine to prepare drinks (S2).
		crew.barista = buildStaff(
			origin * CFrame.new(width / 2 - 10, 0, 18) * CFrame.Angles(0, math.rad(180), 0),
			{
				displayName = "Mia · Barista",
				role = "Barista",
				skin = Color3.fromRGB(235, 185, 150),
				shirt = Color3.fromRGB(90, 70, 60),
				hair = Color3.fromRGB(90, 55, 35),
				walker = true,
			}
		)
	end
	if crew.cook == nil then
		-- The chef prepares every FOOD dish at the oven/prep station (S2).
		crew.cook = buildStaff(
			origin * CFrame.new(width / 2 - 22, 0, 19) * CFrame.Angles(0, math.rad(180), 0),
			{
				displayName = "Sam · Cook",
				role = "Cook",
				skin = Color3.fromRGB(215, 165, 125),
				shirt = Color3.fromRGB(245, 242, 235),
				hair = Color3.fromRGB(60, 45, 35),
				walker = true,
			}
		)
	end
	if crew.waiter == nil then
		crew.waiter = buildStaff(
			origin * CFrame.new(width / 2 + 6, 0, 16) * CFrame.Angles(0, math.rad(180), 0),
			{
				displayName = "Noah · Waiter",
				role = "Waiter",
				skin = Color3.fromRGB(200, 150, 110),
				shirt = Color3.fromRGB(70, 90, 120),
				hair = Color3.fromRGB(35, 30, 28),
				walker = true,
			}
		)
	end
	if crew.cleaner == nil then
		crew.cleaner =
			buildStaff(origin * CFrame.new(8, 0, 16) * CFrame.Angles(0, math.rad(160), 0), {
				displayName = "Pia · Cleaner",
				role = "Cleaner",
				skin = Color3.fromRGB(255, 210, 175),
				shirt = Color3.fromRGB(120, 150, 110),
				hair = Color3.fromRGB(200, 170, 90),
				walker = true,
			})
	end
end

function StaffService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	OrderService = ServiceRegistry.get("OrderService")
	CafeService = ServiceRegistry.get("CafeService")
	KitchenService = ServiceRegistry.get("KitchenService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
end

function StaffService.Start(_self: any)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) then
					ensureCrew(player)
					-- Barista: rescue overdue manual orders (v1 behaviour).
					local order = OrderService:GetOldestPendingFor(player.UserId)
					if
						order
						and (os.clock() - order.createdAtClock)
							>= EconomyConfig.staffServeAfterSeconds
					then
						if OrderService:StaffServe(order.orderId) then
							local crew = crewOf(player.UserId)
							if crew.barista then
								crew.barista.bubble.Text = "☕ Coming right up!"
								task.delay(2.5, function()
									if crew.barista and crew.barista.bubble.Parent ~= nil then
										crew.barista.bubble.Text = "Mia · Barista"
									end
								end)
							end
						end
					end
					-- Cleaner: work the mess queue, or sweep somewhere between
					-- jobs so she reads as WORKING, not idling (owner request:
					-- every employee visibly does their job).
					runCleaner(player)
					local crew = crewOf(player.UserId)
					local cleaner = crew.cleaner
					local queue = messQueues[player.UserId]
					if
						cleaner
						and not cleaner.busy
						and (queue == nil or #queue == 0)
						and rng:NextNumber() < 0.3
					then
						local origin = CafeService:GetPlotOrigin(player)
						if origin and claimStaff(cleaner, 0.1) then
							task.spawn(function()
								local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
								local spot = (origin * CFrame.new(
									rng:NextNumber(width * 0.15, width * 0.85),
									2,
									rng:NextNumber(4, 22)
								)).Position
								staffWalk(cleaner, spot)
								cleaner.bubble.Text = "🧹"
								task.wait(1.4)
								staffWalk(cleaner, cleaner.home.Position)
								cleaner.bubble.Text = cleaner.displayName
								cleaner.busy = false
							end)
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local crew = crewByUser[player.UserId]
		if crew then
			for _, npc in crewList(crew) do
				npc.model:Destroy()
			end
			crewByUser[player.UserId] = nil
		end
		messQueues[player.UserId] = nil
	end)

	-- Crews spawned before the async asset load finishes are procedural; drop
	-- them once the library is ready so the next tick rebuilds with real rigs.
	if AssetLibraryService then
		AssetLibraryService:OnReady(function()
			for userId, crew in crewByUser do
				for _, npc in crewList(crew) do
					npc.model:Destroy()
				end
				crewByUser[userId] = nil
			end
		end)
	end
end

return StaffService
