--!strict
-- Server-authoritative currency. The client can REQUEST a purchase; only this
-- service decides whether coins/reputation/xp actually change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Furniture = require(Shared.Config.Furniture)
local EconomyConfig = require(Shared.Config.Economy)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Remotes = require(Shared.Network.Remotes)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local EconomyService = {}
EconomyService.Name = "EconomyService"

local DataService: any
local ProgressionService: any

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

function EconomyService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	ProgressionService = ServiceRegistry.get("ProgressionService")
end

function EconomyService.Start(_self: any)
	Remotes.event("PurchaseItem").OnServerEvent:Connect(handlePurchase)
	Players.PlayerRemoving:Connect(function(player)
		buyLimiter:clear(player.UserId)
	end)
	Log.info("EconomyService ready")
end

return EconomyService
