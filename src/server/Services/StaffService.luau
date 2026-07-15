--!strict
-- Staff v2 (Phase 3b): three free employees per café, each visibly useful.
--   Mia  (barista) — static behind the counter; auto-serves any manual order
--                    left waiting past Economy.staffServeAfterSeconds.
--   Noah (waiter)  — walks plates from the counter to seated diners.
--   Pia  (cleaner) — clears dirty plates diners leave behind, +1 Buzz each.
-- All server-authoritative; grant paths stay in OrderService/KitchenService.
-- Hiring/wages arrive with monetisation-era balancing (Phase 6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local EconomyConfig = require(Shared.Config.Economy)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)

local StaffService = {}
StaffService.Name = "StaffService"

local DataService: any
local OrderService: any
local CafeService: any
local KitchenService: any
local AssetLibraryService: any

local CHECK_INTERVAL = 5
local STAFF_WALK_SPEED = 11
local STAFF_WALK_TIMEOUT = 8

type StaffNpc = {
	model: Model,
	bubble: TextLabel,
	humanoid: Humanoid?,
	root: BasePart?,
	home: CFrame,
	busy: boolean,
}

type Crew = {
	barista: StaffNpc?,
	waiter: StaffNpc?,
	cleaner: StaffNpc?,
}

local crewByUser: { [number]: Crew } = {}
local messQueues: { [number]: { BasePart } } = {}

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

			return {
				model = rig,
				bubble = label,
				humanoid = humanoid,
				root = root,
				home = base * CFrame.new(0, 2, 0),
				busy = false,
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
		humanoid = humanoid,
		root = if look.walker then root else nil,
		home = base * CFrame.new(0, 2, 0),
		busy = false,
	}
end

-- Straight-line staff walk with waddle + timeout teleport (same recovery
-- philosophy as customers).
local function staffWalk(npc: StaffNpc, target: Vector3)
	local humanoid = npc.humanoid
	local root = npc.root
	if not humanoid or not root then
		return
	end
	local deadline = os.clock() + STAFF_WALK_TIMEOUT
	local t0 = os.clock()
	while root.Parent ~= nil do
		local flat = (root.Position - target) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 1.6 then
			break
		end
		if os.clock() > deadline then
			npc.model:PivotTo(CFrame.new(target + Vector3.new(0, 2, 0)))
			break
		end
		humanoid:MoveTo(target)
		humanoid.HipHeight = 1 + 0.14 * math.abs(math.sin((os.clock() - t0) * 10))
		task.wait(0.1)
	end
	if root.Parent ~= nil then
		humanoid.HipHeight = 1
	end
end

local function crewOf(userId: number): Crew
	local crew = crewByUser[userId]
	if not crew then
		crew = {}
		crewByUser[userId] = crew
	end
	return crew
end

-- Waiter carries a plate to the seat and returns. Fire-and-forget; returns
-- false when he's mid-delivery so the caller can just spawn the plate.
function StaffService.RequestDelivery(_self: any, player: Player, target: Vector3): boolean
	local crew = crewOf(player.UserId)
	local waiter = crew.waiter
	if not waiter or waiter.busy or not waiter.root or waiter.root.Parent == nil then
		return false
	end
	waiter.busy = true
	task.spawn(function()
		local tray = Instance.new("Part")
		tray.Name = "Tray"
		tray.Shape = Enum.PartType.Cylinder
		tray.Size = Vector3.new(0.2, 1.4, 1.4)
		tray.Color = Color3.fromRGB(245, 242, 235)
		tray.CanCollide = false
		tray.CanQuery = false
		tray.Massless = true
		tray.CFrame = (waiter.root :: BasePart).CFrame
			* CFrame.new(0, 0.4, -1.2)
			* CFrame.Angles(0, 0, math.rad(90))
		tray.Parent = waiter.model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = waiter.root
		weld.Part1 = tray
		weld.Parent = waiter.root

		waiter.bubble.Text = "🍽️ Coming through!"
		staffWalk(waiter, target)
		task.wait(0.4)
		tray:Destroy()
		staffWalk(waiter, waiter.home.Position)
		waiter.bubble.Text = "Noah · Waiter"
		waiter.busy = false
	end)
	return true
end

-- Cleaner queue: dirty plates diners leave behind.
function StaffService.NotifyMess(_self: any, player: Player, mess: BasePart)
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
	cleaner.busy = true
	task.spawn(function()
		cleaner.bubble.Text = "🧹 On it!"
		staffWalk(cleaner, mess.Position)
		if mess.Parent ~= nil then
			Fx.floatText(
				mess.Position + Vector3.new(0, 1.2, 0),
				"+1 🔥",
				Color3.fromRGB(255, 180, 120)
			)
			mess:Destroy()
			KitchenService:AddBuzz(player, 1)
		end
		staffWalk(cleaner, cleaner.home.Position)
		cleaner.bubble.Text = "Pia · Cleaner"
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
		local npc = buildStaff(
			origin * CFrame.new(width / 2 + 4, 0, 2.4) * CFrame.Angles(0, math.rad(180), 0),
			{
				displayName = "Mia · Barista",
				role = "Barista",
				skin = Color3.fromRGB(235, 185, 150),
				shirt = Color3.fromRGB(90, 70, 60),
				hair = Color3.fromRGB(90, 55, 35),
				walker = false,
			}
		)
		crew.barista = npc
	end
	if crew.waiter == nil then
		crew.waiter = buildStaff(
			origin * CFrame.new(width / 2 - 6, 0, 8) * CFrame.Angles(0, math.rad(180), 0),
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
			buildStaff(origin * CFrame.new(4, 0, 8) * CFrame.Angles(0, math.rad(160), 0), {
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
					-- Cleaner: work the mess queue.
					runCleaner(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local crew = crewByUser[player.UserId]
		if crew then
			for _, npc in { crew.barista, crew.waiter, crew.cleaner } do
				if npc then
					npc.model:Destroy()
				end
			end
			crewByUser[player.UserId] = nil
		end
		messQueues[player.UserId] = nil
	end)
end

return StaffService
