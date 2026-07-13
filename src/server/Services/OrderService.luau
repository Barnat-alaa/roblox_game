--!strict
-- Order lifecycle + the security-critical serve/claim path.
-- The client sends ONLY an orderId; the server owns the reward decision.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local RewardMath = require(Shared.Utilities.RewardMath)
local Recipes = require(Shared.Config.Recipes)
local Customers = require(Shared.Config.Customers)
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

local activeOrders: { [string]: Types.Order } = {}
local nextId = 0
local claimLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)
local rng = Random.new()

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
	local w = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local d = Grid.PLOT_DEPTH * Grid.CELL_SIZE
	local centre = (origin * CFrame.new(w / 2, 0, d / 2)).Position
	return (hrp.Position - centre).Magnitude <= 60
end

local function handleClaim(player: Player, orderId: unknown, manualCook: unknown)
	if typeof(orderId) ~= "string" then
		return
	end
	local isManual = typeof(manualCook) == "boolean" and manualCook or false

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

	-- Mark claimed BEFORE granting so a duplicate request can never double-pay.
	order.claimed = true
	order.status = "served"
	activeOrders[orderId] = nil

	local recipe = Recipes[order.recipeId]
	local customer = Customers[order.customerId]
	local tipMult = if customer then customer.tipMultiplier else 1
	local payout = RewardMath.orderPayout(recipe, isManual)
	local tip = RewardMath.tipAmount(recipe, rng:NextInteger(1, 100), tipMult)

	EconomyService:AddCoins(player, payout + tip)
	EconomyService:AddReputation(player, EconomyConfig.reputationPerServe)
	EconomyService:AddExperience(player, EconomyConfig.xpPerServe)

	data.stats.customersServed += 1
	data.stats.recipesCooked += 1
	DataService:Push(player)

	if CustomerService then
		CustomerService:OnOrderResolved(player.UserId)
	end
	if AnalyticsService then
		AnalyticsService:TrackOnce(player, "first_customer_served", { recipe = order.recipeId })
		AnalyticsService:Track(
			player,
			"customer_served",
			{ recipe = order.recipeId, coins = payout + tip }
		)
	end

	Remotes.event("Notify"):FireClient(player, {
		kind = "served",
		coins = payout + tip,
		recipe = order.recipeId,
	})
end

function OrderService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	CafeService = ServiceRegistry.get("CafeService")
	CustomerService = ServiceRegistry.get("CustomerService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function OrderService.Start(_self: any)
	Remotes.event("ClaimOrder").OnServerEvent:Connect(handleClaim)
	Players.PlayerRemoving:Connect(function(player)
		claimLimiter:clear(player.UserId)
		for id, order in activeOrders do
			if order.ownerUserId == player.UserId then
				activeOrders[id] = nil
			end
		end
	end)
end

return OrderService
