--!strict
-- Server-level VIP event (docs/GAMEPLAY_DIRECTION.md §3, IMPLEMENTATION_MAP
-- "Feature 3"). A rare "brainrot" celebrity spawns on the boulevard, scores every
-- OPEN café by its Buzz, struts to the busiest one, pays the owner a premium
-- order, and leaves an EARNED gift box the owner opens for a weighted reward.
--
-- Deliberately NOT a branch in CustomerService (whose spawner is strictly
-- per-owner-café): this is one server-wide guest in its own workspace.VipGuests
-- folder. The brainrot asset is a non-humanoid display model, so it is welded onto
-- an invisible Humanoid and driven with NpcNav. It stays OUTSIDE at the entrance
-- (far too wide for the 6-stud door) — which the direction explicitly allows
-- ("drops a large gift box at the table or the café entrance").
--
-- Rails: server-authoritative; the box is EARNED and opened for FREE (never a paid
-- random box — HANDOFF §1); rewards are a data table (Config/Gifts), not code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vip = require(Shared.Config.Vip)
local World = require(Shared.Config.World)
local RewardMath = require(Shared.Utilities.RewardMath)
local StreetMath = require(Shared.Utilities.StreetMath)
local Recipes = require(Shared.Config.Recipes)
local Types = require(Shared.Types)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local NpcNav = require(script.Parent.Parent.NpcNav)
local Fx = require(script.Parent.Parent.Fx)

local VipService = {}
VipService.Name = "VipService"

local CafeService: any
local DataService: any
local AssetLibraryService: any
local KitchenService: any
local EconomyService: any
local AnalyticsService: any

local rng = Random.new()
local folder: Folder
local active = false -- at most one VIP at a time

-- ————— café scoring —————

type Target = { index: number, origin: CFrame, owner: Player, score: number }

-- The busiest OPEN café: highest Buzz wins, ties break to the lowest plot index.
local function bestCafe(): Target?
	local best: Target? = nil
	for index = 1, World.plotCount do
		local origin, ownerUserId = CafeService:GetPlotInfo(index)
		if origin and ownerUserId then
			local owner = Players:GetPlayerByUserId(ownerUserId)
			if owner then
				local score = (KitchenService:GetBuzz(owner) or 0) * Vip.buzzWeight
				if not best or score > best.score then
					best = { index = index, origin = origin, owner = owner, score = score }
				end
			end
		end
	end
	return best
end

-- A point just in front of a café's door, out toward the boulevard. Local -Z is
-- the street side for BOTH rows (origin carries the row's rotation), matching
-- PedestrianService.doorApproach.
local function frontPoint(origin: CFrame, outStuds: number): Vector3
	return (origin * CFrame.new(StreetMath.plotWidth() * World.doorCenterFrac, 2, -outStuds)).Position
end

-- A point INSIDE the café, straight in from the door — where the VIP sits to eat.
local function interiorPoint(origin: CFrame, depthStuds: number): Vector3
	return (origin * CFrame.new(StreetMath.plotWidth() * World.doorCenterFrac, 2, depthStuds)).Position
end

-- The fanciest dish the café can make (highest menu price among UNLOCKED recipes)
-- — the "very difficult" thing the VIP orders. nil if the profile isn't loaded.
local function hardestDish(owner: Player): Types.RecipeDefinition?
	local data = DataService:GetProfile(owner)
	if not data then
		return nil
	end
	local best: Types.RecipeDefinition? = nil
	for id, r in Recipes do
		if data.unlockedRecipes[id] == true and (not best or r.basePrice > best.basePrice) then
			best = r
		end
	end
	return best
end

-- ————— the brainrot walker —————

-- Build the VIP as an invisible Humanoid rig with the brainrot display model
-- welded on, so NpcNav can walk it. Returns nils if the asset failed to load.
local function buildVip(): (Model?, Humanoid?, BasePart?)
	local brainrot = if AssetLibraryService then AssetLibraryService:GetVip() else nil
	if not brainrot or not brainrot.PrimaryPart then
		if brainrot then
			brainrot:Destroy()
		end
		return nil, nil, nil
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
	humanoid.WalkSpeed = Vip.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model
	model.PrimaryPart = root

	-- Sit the brainrot on the root so its feet meet the ground, then weld every
	-- part rigidly to the root. Its own scripts were stripped on load, so nothing
	-- animates it — a solid gliding statue, which is what we want.
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

	return model, humanoid, root
end

local function makeBanner(root: BasePart, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipBanner"
	gui.Size = UDim2.fromScale(9, 2)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Adornee = root
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 225, 120)
	label.TextStrokeTransparency = 0.25
	label.Text = text
	label.Parent = gui
	return label
end

-- ————— the earned gift box (modelled on CustomerService.dropTip) —————

local function dropGift(target: Target)
	local ffolder = CafeService:GetFurnitureFolder(target.owner)
	local plotModel: Instance = (ffolder and ffolder.Parent) or folder
	local boxCf = CFrame.new(interiorPoint(target.origin, Vip.insideDepth) + Vector3.new(0, 1.5, 0))

	local box = Instance.new("Part")
	box.Name = "VipGift"
	box.Size = Vector3.new(3, 3, 3)
	box.Color = Color3.fromRGB(230, 90, 140)
	box.Material = Enum.Material.SmoothPlastic
	box.Anchored = true
	box.CanCollide = false
	box.CFrame = boxCf

	local ribbon = Instance.new("Part")
	ribbon.Name = "Ribbon"
	ribbon.Size = Vector3.new(3.15, 0.5, 3.15)
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
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
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
		-- Only the winning café's owner opens their own gift.
		if claimed or who ~= target.owner then
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
			AnalyticsService:Track(who, "vip_gift_opened", {
				kind = reward.kind,
				amount = reward.amount,
			})
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

-- ————— the event —————

local function runVipEvent()
	local target = bestCafe()
	if not target then
		return -- nobody's open; try again next interval
	end
	local model, humanoid, root = buildVip()
	if not model or not humanoid or not root then
		Log.warn("VipService: brainrot asset unavailable, skipping event")
		return
	end

	-- Spawn out on the boulevard in front of the winning café.
	model:PivotTo(CFrame.new(frontPoint(target.origin, 18) + Vector3.new(0, Vip.hipHeight + 3, 0)))
	model.Parent = folder
	NpcNav.assignNpcGroup(model)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local banner = makeBanner(root, Vip.bannerText)
	if AnalyticsService then
		AnalyticsService:Track(target.owner, "vip_incoming", { score = target.score })
	end

	local opts = { baseHip = Vip.hipHeight, straightTimeout = 18, legTimeout = 6 }
	-- Approach the door, then walk INSIDE (the brainrot is scaled to fit the doorway).
	NpcNav.walkTo(model, humanoid, root, frontPoint(target.origin, 6), opts)
	if root.Parent == nil then
		return
	end
	NpcNav.walkTo(model, humanoid, root, interiorPoint(target.origin, Vip.insideDepth), opts)
	if root.Parent == nil then
		return
	end

	-- Order the fanciest dish on the menu — served INSTANTLY. The owner is paid a
	-- big premium scaled to how fancy that dish is.
	local dish = hardestDish(target.owner)
	local dishName = if dish then dish.displayName else "the special"
	banner.Text = "😋 VIP is eating " .. dishName .. "!"
	if target.owner.Parent ~= nil then
		local premium = if dish
			then math.floor(dish.basePrice * Vip.premiumMultiplier)
			else Vip.premiumCoins
		EconomyService:AddCoins(target.owner, premium)
		EconomyService:AddReputation(target.owner, Vip.premiumReputation)
		Fx.floatText(
			interiorPoint(target.origin, Vip.insideDepth) + Vector3.new(0, 5, 0),
			"⭐ VIP ordered " .. dishName .. "! +" .. tostring(premium) .. " 🪙"
		)
		if AnalyticsService then
			AnalyticsService:Track(target.owner, "vip_served", {
				coins = premium,
				dish = if dish then dish.id else "none",
			})
		end
	end

	-- Eat, then leave the earned gift box by the table.
	task.wait(Vip.lingerSeconds)
	dropGift(target)

	-- Stroll out through the door and despawn.
	NpcNav.walkTo(model, humanoid, root, frontPoint(target.origin, 10), opts)
	task.wait(Vip.leaveAfterSeconds)
	if model.Parent ~= nil then
		model:Destroy()
	end
end

function VipService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	DataService = ServiceRegistry.get("DataService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
	KitchenService = ServiceRegistry.get("KitchenService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function VipService.Start(_self: any)
	if not Vip.enabled then
		Log.info("VipService disabled (Config/Vip.enabled = false)")
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "VipGuests"
	folder.Parent = workspace

	local function loop()
		while true do
			task.wait(rng:NextNumber(Vip.spawnIntervalMinSeconds, Vip.spawnIntervalMaxSeconds))
			if not active then
				active = true
				local ok, err = pcall(runVipEvent)
				if not ok then
					Log.warn("VIP event failed:", err)
				end
				active = false
			end
		end
	end

	-- Wait for the brainrot template to finish loading before the first attempt,
	-- so no early event is skipped for a not-yet-ready asset.
	if AssetLibraryService then
		AssetLibraryService:OnReady(function()
			task.spawn(loop)
		end)
	else
		task.spawn(loop)
	end
	Log.info("VipService ready (brainrot VIP + gift box)")
end

return VipService
