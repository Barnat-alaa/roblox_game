--!strict
-- Server-authoritative currency. The client can REQUEST a purchase; only this
-- service decides whether coins/reputation/xp actually change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Furniture = require(Shared.Config.Furniture)
local Ingredients = require(Shared.Config.Ingredients)
local EconomyConfig = require(Shared.Config.Economy)
local MarketMath = require(Shared.Utilities.MarketMath)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Remotes = require(Shared.Network.Remotes)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local EconomyService = {}
EconomyService.Name = "EconomyService"

local DataService: any
local ProgressionService: any
local GoalService: any

local buyLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

function EconomyService.TrySpendCoins(_self: any, player: Player, amount: number): boolean
	if amount < 0 then
		return false
	end
	local data = DataService:GetProfile(player)
	if not data or data.coins < amount then
		return false
	end
	data.coins -= amount
	DataService:Push(player)
	return true
end

function EconomyService.AddCoins(_self: any, player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	data.coins += amount
	data.stats.totalCoinsEarned += amount
	DataService:Push(player)
	if GoalService then
		GoalService:Bump(player, "earn_coins", amount)
	end
end

function EconomyService.AddReputation(_self: any, player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	data.reputation += amount
	data.cafeStars = ProgressionService:StarsFor(data.reputation)
	DataService:Push(player)
	ProgressionService:CheckRecipeUnlocks(player)
end

function EconomyService.AddExperience(_self: any, player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	data.experience += amount
	data.level = ProgressionService:LevelFor(data.experience)
	DataService:Push(player)
	ProgressionService:CheckRecipeUnlocks(player)
end

local function handlePurchase(player: Player, catalogId: unknown)
	if typeof(catalogId) ~= "string" then
		return
	end
	if not buyLimiter:check(player.UserId, os.clock()) then
		return
	end
	local def = Furniture[catalogId]
	if not def then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	if data.level < def.requiredLevel then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "level_locked" })
		return
	end
	if not EconomyService:TrySpendCoins(player, def.price) then
		Remotes.event("Notify")
			:FireClient(player, { kind = "error", reason = "insufficient_coins" })
		return
	end
	data.inventory[catalogId] = (data.inventory[catalogId] or 0) + 1
	DataService:Push(player)
	Remotes.event("Notify"):FireClient(player, { kind = "purchased", item = catalogId })
end

-- Bulk-buy ingredients into the pantry. The client sends only what it wants to
-- buy; this handler owns the quantity (whole, positive, capped), the price
-- (MarketMath, computed here — the client-sent total is never trusted) and the
-- unlock gate, mirroring handlePurchase.
local function handleBuyIngredient(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: any
	local ingredientId = p.ingredientId
	if typeof(ingredientId) ~= "string" or typeof(p.qty) ~= "number" then
		return
	end
	if not buyLimiter:check(player.UserId, os.clock()) then
		return
	end
	local def = Ingredients[ingredientId]
	if not def then
		return
	end
	local qty = math.floor(p.qty)
	if qty <= 0 or qty > EconomyConfig.maxIngredientBuy then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	if data.level < def.unlockLevel then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "level_locked" })
		return
	end
	local cost = MarketMath.costFor(ingredientId, qty)
	if cost <= 0 then
		return
	end
	if not EconomyService:TrySpendCoins(player, cost) then
		Remotes.event("Notify")
			:FireClient(player, { kind = "error", reason = "insufficient_coins" })
		return
	end
	if typeof(data.pantry) ~= "table" then
		(data :: any).pantry = {}
	end
	data.pantry[ingredientId] = (data.pantry[ingredientId] or 0) + qty
	DataService:Push(player)
	Remotes.event("Notify"):FireClient(player, {
		kind = "ingredient_bought",
		item = ingredientId,
		qty = qty,
		cost = cost,
	})
end

function EconomyService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	ProgressionService = ServiceRegistry.get("ProgressionService")
	GoalService = ServiceRegistry.get("GoalService")
end

function EconomyService.Start(_self: any)
	Remotes.event("PurchaseItem").OnServerEvent:Connect(handlePurchase)
	Remotes.event("MarketBuyIngredient").OnServerEvent:Connect(handleBuyIngredient)
	Players.PlayerRemoving:Connect(function(player)
		buyLimiter:clear(player.UserId)
	end)
	Log.info("EconomyService ready")
end

return EconomyService
