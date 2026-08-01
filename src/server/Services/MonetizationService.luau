--!strict
-- Robux monetisation (docs/MONETISATION.md). ProcessReceipt is IDEMPOTENT
-- (docs/SECURITY.md): every grant is keyed on receiptInfo.PurchaseId and recorded
-- in data.grantedReceipts, so a retried callback never double-grants. Grant
-- amounts come from Config/Products — the client never sends a reward.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Config.Products)
local Ingredients = require(Shared.Config.Ingredients)
local Types = require(Shared.Types)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local MonetizationService = {}
MonetizationService.Name = "MonetizationService"

local DataService: any
local CafeService: any
local KitchenService: any
local EconomyService: any
local AnalyticsService: any

local buyLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

-- Apply one product's reward to a loaded profile. Returns true on success (so
-- ProcessReceipt only records the grant + returns PurchaseGranted when it worked).
local function grantProduct(player: Player, entry: any): boolean
	local data = DataService:GetProfile(player)
	if not data then
		return false
	end
	if typeof(data.pantry) ~= "table" then
		(data :: any).pantry = {}
	end
	if typeof(data.boosts) ~= "table" then
		(data :: any).boosts = {}
	end

	if entry.kind == "bundle" then
		for item, qty in entry.ingredients do
			data.pantry[item] = (tonumber(data.pantry[item]) or 0) + qty
		end
	elseif entry.kind == "refill_all" then
		for id in Ingredients do
			data.pantry[id] = math.max(tonumber(data.pantry[id]) or 0, Products.refillLevel)
		end
	elseif entry.kind == "restock_low" then
		for id in Ingredients do
			if (tonumber(data.pantry[id]) or 0) < 6 then
				data.pantry[id] = Products.restockLevel
			end
		end
	elseif entry.kind == "boost" then
		-- Stack onto any remaining boost time rather than overwrite.
		local now = os.time()
		local current = math.max(now, tonumber(data.boosts[entry.boost]) or 0)
		data.boosts[entry.boost] = current + entry.seconds
	elseif entry.kind == "hire_all" then
		for _, m in data.staff do
			if m.hired == false then
				m.hired = true
			end
		end
	elseif entry.kind == "stock_pack" then
		-- A CONSUMABLE restock: top every unlocked dish up by `amount`, once.
		-- KitchenService owns the per-recipe cap and the save.
		if KitchenService:GrantStockPack(player, entry.amount) <= 0 then
			-- Nothing landed (every dish already at the cap). Refuse the grant so
			-- ProcessReceipt returns NotProcessedYet and Roblox retries later
			-- rather than charging for nothing.
			return false
		end
	else
		return false
	end

	DataService:Push(player)
	Remotes.event("Notify"):FireClient(player, { kind = "robux_reward", name = entry.name })
	return true
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left; Roblox will call again when they return.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService:GetProfile(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if typeof(data.grantedReceipts) ~= "table" then
		(data :: any).grantedReceipts = {}
	end
	local receiptKey = tostring(receiptInfo.PurchaseId)
	-- Idempotency: already granted → say so WITHOUT granting again.
	if data.grantedReceipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local entry = Products.developerProducts[receiptInfo.ProductId]
	if not entry then
		-- Stock packs live in their own table (they carry a coin price too), so
		-- look there before giving up.
		local pack = Products.stockPackForProduct(receiptInfo.ProductId)
		if pack then
			entry = {
				kind = "stock_pack",
				key = "stock_pack_" .. tostring(pack.amount),
				amount = pack.amount,
				name = pack.name,
				id = pack.productId,
			}
		end
	end
	if not entry then
		-- Unknown product (config not deployed yet): retry later, don't consume it.
		Log.warn("ProcessReceipt: unknown product", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = grantProduct(player, entry)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Record the grant BEFORE returning Granted; DataService persists it on the
	-- next save. (ProfileStore will make this crash-safe cross-server — SECURITY.md.)
	data.grantedReceipts[receiptKey] = true
	DataService:Push(player)
	Log.info("Granted", entry.key, "to", player.Name)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Cache which passes a player owns onto their profile (so perks read a flag
-- instead of an async query every time), on join and on purchase.
local function refreshPasses(player: Player)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	if typeof(data.ownedPasses) ~= "table" then
		(data :: any).ownedPasses = {}
	end
	local changed = false
	for passId, entry in Products.passes do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns and data.ownedPasses[entry.pass] ~= true then
			data.ownedPasses[entry.pass] = true
			changed = true
		end
	end
	if changed then
		DataService:Push(player)
	end
	-- Apply VIP perks as soon as ownership is confirmed (they otherwise wait for the
	-- next spawn / Buzz tick): faster walk + the 👑 café-sign badge. Idempotent, so
	-- it's safe to run on every join/purchase refresh.
	if data.ownedPasses.vip == true then
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Products.vipPerks.walkSpeed
		end
		if CafeService and KitchenService then
			CafeService:SetSignBuzz(player, KitchenService:GetBuzz(player) or 0)
		end
	end
end

function MonetizationService.OwnsPass(_self: any, player: Player, passKey: string): boolean
	local data = DataService:GetProfile(player)
	return data ~= nil and typeof(data.ownedPasses) == "table" and data.ownedPasses[passKey] == true
end

-- Is a timed boost active right now? (Consumed by EconomyService.)
function MonetizationService.BoostActive(
	_self: any,
	data: Types.PlayerData,
	boostKey: string
): boolean
	local boosts = (data :: any).boosts
	return typeof(boosts) == "table" and (tonumber(boosts[boostKey]) or 0) > os.time()
end

-- The COIN half of the stock packs. This is what keeps a paid restock off the
-- pay-to-win rail: every pack Robux can buy is also buyable with coins, so Robux
-- only skips the grind (HANDOFF §1). Server-authoritative — the client sends an
-- amount and nothing else; the price and the spend happen here.
local function handleBuyStockPack(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: any
	if typeof(p.amount) ~= "number" or p.amount ~= math.floor(p.amount) then
		return
	end
	if not buyLimiter:check(player.UserId, os.clock()) then
		return
	end
	local pack = Products.stockPackForAmount(p.amount)
	if not pack then
		return
	end
	if not DataService:GetProfile(player) then
		return
	end

	-- Charge only if the pack would actually deliver something: a café already at
	-- the per-recipe cap should not pay for nothing.
	if not EconomyService:TrySpendCoins(player, pack.coinCost) then
		Remotes.event("Notify"):FireClient(player, {
			kind = "upgrade_blocked",
			text = "Not enough coins — " .. pack.coinCost .. " needed.",
		})
		return
	end
	local granted = KitchenService:GrantStockPack(player, pack.amount)
	if granted <= 0 then
		-- Refund: nothing landed, so the spend is undone rather than pocketed.
		EconomyService:AddCoins(player, pack.coinCost)
		Remotes.event("Notify"):FireClient(player, {
			kind = "upgrade_blocked",
			text = "Your shelves are already full.",
		})
		return
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "upgrade_bought",
		text = pack.name .. " — " .. granted .. " items added to your stock!",
	})
	if AnalyticsService then
		AnalyticsService:Track(
			player,
			"stock_pack_bought",
			{ amount = pack.amount, granted = granted, paidWith = "coins" }
		)
	end
end

function MonetizationService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	CafeService = ServiceRegistry.get("CafeService")
	KitchenService = ServiceRegistry.get("KitchenService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function MonetizationService.Start(_self: any)
	MarketplaceService.ProcessReceipt = processReceipt
	Remotes.event("BuyStockPack").OnServerEvent:Connect(handleBuyStockPack)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased and Products.passes[passId] then
				task.spawn(refreshPasses, player)
				Remotes.event("Notify"):FireClient(player, {
					kind = "robux_reward",
					name = Products.passes[passId].name,
				})
			end
		end
	)

	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, refreshPasses, player) -- let the profile load first
	end)

	Log.info("MonetizationService ready")
end

return MonetizationService
