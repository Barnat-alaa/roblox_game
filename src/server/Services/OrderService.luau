--!strict
-- Server-owned order lifecycle. Active owners must physically collect one
-- visible dish from the kitchen pass and carry it to the matching table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Recipes = require(Shared.Config.Recipes)
local EconomyConfig = require(Shared.Config.Economy)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local PlateFactory = require(script.Parent.Parent.PlateFactory)
local Fx = require(script.Parent.Parent.Fx)

local OrderService = {}
OrderService.Name = "OrderService"

local EconomyService: any
local CafeService: any
local CustomerService: any
local AnalyticsService: any
local RecipeService: any
local KitchenService: any
local AssetLibraryService: any

type CarriedOrder = {
	orderId: string,
	plate: Model,
	manualBonus: number,
}

type ServicePoints = {
	pickup: BasePart?,
	deliveryPrompt: ProximityPrompt?,
}

local activeOrders: { [string]: Types.Order } = {}
local servingLocks: { [string]: boolean } = {}
local carriedByUser: { [number]: CarriedOrder } = {}
local servicePoints: { [string]: ServicePoints } = {}
local nextId = 0
local claimLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

local function newOrderId(): string
	nextId += 1
	return "order_" .. nextId
end

local function notify(player: Player, reason: string)
	Remotes.event("Notify"):FireClient(player, { kind = "error", reason = reason })
end

local function destroyServicePoints(orderId: string)
	local points = servicePoints[orderId]
	if not points then
		return
	end
	if points.pickup and points.pickup.Parent ~= nil then
		points.pickup:Destroy()
	end
	if points.deliveryPrompt and points.deliveryPrompt.Parent ~= nil then
		points.deliveryPrompt:Destroy()
	end
	servicePoints[orderId] = nil
end

local function pickupOffset(userId: number): number
	local count = 0
	for _, order in activeOrders do
		if order.ownerUserId == userId and order.status == "pending" then
			count += 1
		end
	end
	return ((count - 1) % 3 - 1) * 2.2
end

local function isAtKitchenPass(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local passCf = CafeService:GetKitchenPass(player)
	return root ~= nil
		and root:IsA("BasePart")
		and passCf ~= nil
		and (root.Position - (passCf :: CFrame).Position).Magnitude <= 15
end

local function stopCarrying(player: Player): CarriedOrder?
	local carried = carriedByUser[player.UserId]
	if carried then
		carriedByUser[player.UserId] = nil
		if carried.plate.Parent ~= nil then
			carried.plate:Destroy()
		end
	end
	return carried
end

local function startCarryVisual(player: Player, orderId: string, plate: Model)
	for _, descendant in plate:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	plate.Name = "CarriedOrder_" .. orderId
	plate.Parent = workspace
	task.spawn(function()
		while true do
			local carried = carriedByUser[player.UserId]
			if not carried or carried.orderId ~= orderId or plate.Parent == nil then
				break
			end
			local character = player.Character
			local hand = character
				and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if hand and hand:IsA("BasePart") then
				local position = (hand.CFrame * CFrame.new(0, -0.7, -0.35)).Position
				plate:PivotTo(CFrame.new(position))
			elseif root and root:IsA("BasePart") then
				plate:PivotTo(CFrame.new((root.CFrame * CFrame.new(1.05, 0.2, -1.35)).Position))
			end
			task.wait(0.04)
		end
	end)
end

local function pickupOrder(player: Player, orderId: string)
	if not claimLimiter:check(player.UserId, os.clock()) then
		return
	end
	local order = activeOrders[orderId]
	if not order or order.ownerUserId ~= player.UserId or order.status ~= "pending" then
		return
	end
	if carriedByUser[player.UserId] then
		notify(player, "already_carrying")
		return
	end
	if not isAtKitchenPass(player) then
		notify(player, "go_to_pass")
		return
	end
	if servingLocks[orderId] then
		return
	end
	servingLocks[orderId] = true

	local manualReady = RecipeService:ConsumeManualCook(player, orderId)
	local taken = KitchenService:TakeServing(player, order.recipeId)
	if not taken and manualReady and KitchenService:AddEmergencyServing(player, order.recipeId) then
		taken = KitchenService:TakeServing(player, order.recipeId)
	end
	if not taken then
		servingLocks[orderId] = nil
		notify(player, "not_in_stock")
		return
	end

	local recipe = Recipes[order.recipeId]
	local plate = PlateFactory.make(AssetLibraryService, recipe)
	local payout = KitchenService:servingPayout(recipe)
	local bonus = if manualReady then math.max(1, math.floor(payout * 0.25)) else 0
	order.claimed = true
	order.status = "ready"
	carriedByUser[player.UserId] = {
		orderId = orderId,
		plate = plate,
		manualBonus = bonus,
	}
	startCarryVisual(player, orderId, plate)
	local points = servicePoints[orderId]
	if points and points.pickup and points.pickup.Parent ~= nil then
		points.pickup:Destroy()
		points.pickup = nil
	end
	servingLocks[orderId] = nil
	Remotes.event("Notify"):FireClient(player, {
		kind = "order_picked_up",
		orderId = orderId,
		recipe = recipe.displayName,
		tableLabel = order.tableLabel,
	})
end

local function deliverOrder(player: Player, orderId: string)
	local carried = carriedByUser[player.UserId]
	if not carried then
		notify(player, "pick_up_first")
		return
	end
	if carried.orderId ~= orderId then
		notify(player, "wrong_table")
		return
	end
	local order = activeOrders[orderId]
	if not order or order.ownerUserId ~= player.UserId or order.status ~= "ready" then
		return
	end
	if servingLocks[orderId] then
		return
	end
	servingLocks[orderId] = true
	local payout = KitchenService:CompleteTakenServing(player, order.recipeId)
	if payout == nil then
		servingLocks[orderId] = nil
		return
	end
	if carried.manualBonus > 0 then
		EconomyService:AddCoins(player, carried.manualBonus)
	end
	EconomyService:AddExperience(player, EconomyConfig.xpPerServe)
	local total = payout + carried.manualBonus
	stopCarrying(player)
	order.status = "served"
	activeOrders[orderId] = nil
	servingLocks[orderId] = nil
	destroyServicePoints(orderId)
	if CustomerService then
		CustomerService:OnOrderResolved(orderId, total, true)
	end
	if AnalyticsService then
		AnalyticsService:TrackOnce(player, "first_customer_served", { recipe = order.recipeId })
		AnalyticsService:Track(player, "customer_served", {
			recipe = order.recipeId,
			coins = total,
			manualDelivery = true,
		})
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Fx.coinBurst(root.Position + Vector3.new(0, 2, 0), 8)
		Fx.floatText(root.Position + Vector3.new(0, 4, 0), "PERFECT DELIVERY! +" .. total)
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "served",
		orderId = orderId,
		coins = total,
		recipe = order.recipeId,
		manualDelivery = true,
	})
end

local function createPickupPoint(player: Player, order: Types.Order)
	local passCf = CafeService:GetKitchenPass(player)
	local folder = CafeService:GetFurnitureFolder(player)
	local recipe = Recipes[order.recipeId]
	if not passCf or not folder or not recipe then
		return
	end
	local point = Instance.new("Part")
	point.Name = "OrderPickup_" .. order.orderId
	point.Size = Vector3.new(1.5, 0.25, 1.5)
	point.CFrame = (passCf :: CFrame) * CFrame.new(pickupOffset(player.UserId), 0.55, 0)
	point.Color = Color3.fromRGB(255, 190, 78)
	point.Material = Enum.Material.Neon
	point.Transparency = 0.18
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.Parent = folder.Parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(185, 48)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 85
	gui.Parent = point
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
	label.BackgroundTransparency = 0.08
	label.TextColor3 = Color3.fromRGB(255, 244, 216)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Text = recipe.displayName .. "  >  " .. (order.tableLabel or "TABLE")
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUpOrder"
	prompt.ActionText = "Pick up " .. recipe.displayName
	prompt.ObjectText = order.tableLabel or "Customer order"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function(who)
		if who == player then
			pickupOrder(player, order.orderId)
		end
	end)
	servicePoints[order.orderId] = { pickup = point, deliveryPrompt = nil }
end

function OrderService.CreateOrder(
	_self: any,
	player: Player,
	recipeId: string,
	customerId: string,
	seatId: string?,
	tableLabel: string?,
	deliveryPart: BasePart?
): string?
	if not Recipes[recipeId] then
		return nil
	end
	local id = newOrderId()
	local order: Types.Order = {
		orderId = id,
		ownerUserId = player.UserId,
		recipeId = recipeId,
		customerId = customerId,
		status = "pending",
		createdAtClock = os.clock(),
		claimed = false,
		seatId = seatId,
		tableLabel = tableLabel,
	}
	activeOrders[id] = order
	createPickupPoint(player, order)
	if deliveryPart then
		local recipe = Recipes[recipeId]
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DeliverOrder"
		prompt.ActionText = "Deliver " .. recipe.displayName
		prompt.ObjectText = tableLabel or "Correct table"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = deliveryPart
		prompt.Triggered:Connect(function(who)
			if who == player then
				deliverOrder(player, id)
			end
		end)
		local points = servicePoints[id] or { pickup = nil, deliveryPrompt = nil }
		points.deliveryPrompt = prompt
		servicePoints[id] = points
	end
	Remotes.event("OrderCreated"):FireClient(player, order)
	return id
end

-- The compact HUD button is a convenience, not a remote serve: it only works
-- when the owner has physically reached the pass.
local function handleClaim(player: Player, orderId: unknown, _unused: unknown)
	if typeof(orderId) == "string" then
		pickupOrder(player, orderId)
	end
end

function OrderService.GetActiveOrder(_self: any, orderId: string): Types.Order?
	return activeOrders[orderId]
end

function OrderService.GetOldestPendingFor(_self: any, userId: number): Types.Order?
	local best: Types.Order? = nil
	for _, order in activeOrders do
		if order.ownerUserId == userId and order.status == "pending" and not order.claimed then
			if best == nil or order.createdAtClock < (best :: Types.Order).createdAtClock then
				best = order
			end
		end
	end
	return best
end

function OrderService.StaffServe(_self: any, orderId: string): boolean
	local order = activeOrders[orderId]
	if not order or order.status ~= "pending" or order.claimed then
		return false
	end
	local player = Players:GetPlayerByUserId(order.ownerUserId)
	if not player or servingLocks[orderId] then
		return false
	end
	servingLocks[orderId] = true
	local ate, payout = KitchenService:ConsumeSpecific(player, order.recipeId)
	if not ate or payout == nil then
		servingLocks[orderId] = nil
		return false
	end
	order.claimed = true
	order.status = "served"
	activeOrders[orderId] = nil
	servingLocks[orderId] = nil
	destroyServicePoints(orderId)
	EconomyService:AddExperience(
		player,
		math.floor(EconomyConfig.xpPerServe * EconomyConfig.staffXpMultiplier)
	)
	if CustomerService then
		CustomerService:OnOrderResolved(orderId, payout, false)
	end
	if AnalyticsService then
		AnalyticsService:Track(player, "staff_served", { recipe = order.recipeId })
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "served",
		orderId = orderId,
		coins = payout,
		recipe = order.recipeId,
		staff = true,
	})
	return true
end

function OrderService.CancelOrder(_self: any, orderId: string, silent: boolean?): boolean
	local order = activeOrders[orderId]
	if not order or order.status == "served" then
		return false
	end
	if servingLocks[orderId] then
		return false
	end
	local player = Players:GetPlayerByUserId(order.ownerUserId)
	local carried = player and carriedByUser[player.UserId]
	if player and carried and carried.orderId == orderId then
		stopCarrying(player)
	end
	activeOrders[orderId] = nil
	destroyServicePoints(orderId)
	if player and silent ~= true then
		Remotes.event("Notify"):FireClient(player, {
			kind = "order_cancelled",
			orderId = orderId,
			reason = "customer_left",
		})
	end
	return true
end

function OrderService.Init(_self: any)
	EconomyService = ServiceRegistry.get("EconomyService")
	CafeService = ServiceRegistry.get("CafeService")
	CustomerService = ServiceRegistry.get("CustomerService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	RecipeService = ServiceRegistry.get("RecipeService")
	KitchenService = ServiceRegistry.get("KitchenService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
end

function OrderService.Start(_self: any)
	Remotes.event("ClaimOrder").OnServerEvent:Connect(handleClaim)
	Players.PlayerRemoving:Connect(function(player)
		claimLimiter:clear(player.UserId)
		stopCarrying(player)
		for id, order in activeOrders do
			if order.ownerUserId == player.UserId then
				activeOrders[id] = nil
				servingLocks[id] = nil
				destroyServicePoints(id)
			end
		end
	end)
	Log.info("OrderService ready (physical one-at-a-time table delivery)")
end

return OrderService
