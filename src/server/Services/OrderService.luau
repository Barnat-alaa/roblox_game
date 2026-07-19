--!strict
-- Order lifecycle + the security-critical serve/claim path.
-- The client sends ONLY an orderId; the server owns the reward decision.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Recipes = require(Shared.Config.Recipes)
local EconomyConfig = require(Shared.Config.Economy)
local Grid = require(Shared.Utilities.Grid)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local OrderService = {}
OrderService.Name = "OrderService"

local DataService: any
local EconomyService: any
local CafeService: any
local CustomerService: any
local AnalyticsService: any
local RecipeService: any
local KitchenService: any

local activeOrders: { [string]: Types.Order } = {}
local servingLocks: { [string]: boolean } = {}
local nextId = 0
local claimLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

local function newOrderId(): string
	nextId += 1
	return "order_" .. nextId
end

function OrderService.CreateOrder(
	_self: any,
	player: Player,
	recipeId: string,
	customerId: string
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
	}
	activeOrders[id] = order
	Remotes.event("OrderCreated"):FireClient(player, order)
	return id
end

-- Is the player physically at their own café? Guards against remote-spam claims.
local function isNearOwnCafe(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return false
	end
	local origin = CafeService:GetPlotOrigin(player)
	if not origin then
		return false
	end
	-- Rect distance, not centre distance: the S2 plots are deep, so a radius
	-- from the centre would reject a player standing at their own front counter.
	return Grid.distanceToPlotRect(origin, hrp.Position) <= 40
end

local function handleClaim(player: Player, orderId: unknown, _manualCook: unknown)
	if typeof(orderId) ~= "string" then
		return
	end
	-- NOTE: the client's manualCook argument is deliberately IGNORED. The only
	-- path to the manual bonus is a server-verified brew (RecipeService).

	if not claimLimiter:check(player.UserId, os.clock()) then
		Log.warn("Rate-limited claim from", player.Name)
		return
	end

	local order = activeOrders[orderId]
	if not order then
		return
	end
	if order.ownerUserId ~= player.UserId then
		return
	end
	if order.claimed then
		return
	end

	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	if data.unlockedRecipes[order.recipeId] ~= true then
		return
	end
	if not isNearOwnCafe(player) then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "too_far" })
		return
	end
	if servingLocks[orderId] then
		return
	end
	servingLocks[orderId] = true

	local manualReady = RecipeService:ConsumeManualCook(player, orderId)
	local ate, payout = KitchenService:ConsumeSpecific(player, order.recipeId, true)
	if not ate and manualReady then
		local madeServing = KitchenService:AddEmergencyServing(player, order.recipeId)
		if madeServing then
			ate, payout = KitchenService:ConsumeSpecific(player, order.recipeId, true)
		end
	end
	if not ate or payout == nil then
		servingLocks[orderId] = nil
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "not_in_stock" })
		return
	end

	-- Mark claimed only after the atomic FIFO reservation committed.
	order.claimed = true
	order.status = "served"
	activeOrders[orderId] = nil
	servingLocks[orderId] = nil
	local manualBonus = if manualReady then math.max(1, math.floor(payout * 0.25)) else 0
	if manualBonus > 0 then
		EconomyService:AddCoins(player, manualBonus)
	end
	EconomyService:AddExperience(player, EconomyConfig.xpPerServe)

	if CustomerService then
		CustomerService:OnOrderResolved(player.UserId, payout + manualBonus)
	end
	if AnalyticsService then
		AnalyticsService:TrackOnce(player, "first_customer_served", { recipe = order.recipeId })
		AnalyticsService:Track(
			player,
			"customer_served",
			{ recipe = order.recipeId, coins = payout + manualBonus }
		)
	end

	Remotes.event("Notify"):FireClient(player, {
		kind = "served",
		coins = payout + manualBonus,
		recipe = order.recipeId,
	})
end

-- Server-internal lookup for sibling services (never exposed to clients).
function OrderService.GetActiveOrder(_self: any, orderId: string): Types.Order?
	return activeOrders[orderId]
end

-- Oldest unclaimed order for a user (StaffService polls this).
function OrderService.GetOldestPendingFor(_self: any, userId: number): Types.Order?
	local best: Types.Order? = nil
	for _, order in activeOrders do
		if order.ownerUserId == userId and not order.claimed then
			if best == nil or order.createdAtClock < (best :: Types.Order).createdAtClock then
				best = order
			end
		end
	end
	return best
end

-- Server-internal: the barista fulfils an order. Mirrors the claim grant path
-- but with the staff cut and half XP — automation never beats manual play.
function OrderService.StaffServe(_self: any, orderId: string): boolean
	local order = activeOrders[orderId]
	if not order or order.claimed then
		return false
	end
	local player = Players:GetPlayerByUserId(order.ownerUserId)
	if not player then
		return false
	end
	local data = DataService:GetProfile(player)
	if not data then
		return false
	end
	if servingLocks[orderId] then
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

	EconomyService:AddExperience(
		player,
		math.floor(EconomyConfig.xpPerServe * EconomyConfig.staffXpMultiplier)
	)

	if CustomerService then
		CustomerService:OnOrderResolved(player.UserId, payout)
	end
	if AnalyticsService then
		AnalyticsService:Track(player, "staff_served", { recipe = order.recipeId })
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "served",
		coins = payout,
		recipe = order.recipeId,
		staff = true,
	})
	return true
end

-- Server-internal (called by CustomerService when patience runs out, or
-- silently when counter stock feeds the waiting customer instead).
-- Never grants anything; a claimed order can no longer be cancelled.
function OrderService.CancelOrder(_self: any, orderId: string, silent: boolean?): boolean
	local order = activeOrders[orderId]
	if not order or order.claimed then
		return false
	end
	if servingLocks[orderId] then
		return false
	end
	activeOrders[orderId] = nil
	local player = Players:GetPlayerByUserId(order.ownerUserId)
	if player and silent ~= true then
		Remotes.event("Notify"):FireClient(player, {
			kind = "order_cancelled",
			reason = "customer_left",
		})
	end
	if player and silent == true then
		-- Clear the client's order banner without the sad toast.
		Remotes.event("Notify"):FireClient(player, { kind = "order_fed_from_stock" })
	end
	return true
end

function OrderService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	CafeService = ServiceRegistry.get("CafeService")
	CustomerService = ServiceRegistry.get("CustomerService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	RecipeService = ServiceRegistry.get("RecipeService")
	KitchenService = ServiceRegistry.get("KitchenService")
end

function OrderService.Start(_self: any)
	Remotes.event("ClaimOrder").OnServerEvent:Connect(handleClaim)
	Players.PlayerRemoving:Connect(function(player)
		claimLimiter:clear(player.UserId)
		for id, order in activeOrders do
			if order.ownerUserId == player.UserId then
				activeOrders[id] = nil
				servingLocks[id] = nil
			end
		end
	end)
end

return OrderService
