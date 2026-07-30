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
	elseif entry.kind == "yield_tier" then
		-- P4: permanent, and never a downgrade — buying a lower tier after a
		-- higher one (or re-buying the same) leaves you where you are.
		local mutable: any = data
		mutable.yieldTier = math.max(math.floor(tonumber(mutable.yieldTier) or 0), entry.tier)
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
		-- The yield ladder lives in its own table (it has a coin price too), so
		-- look there before giving up. productId 0 means "not created yet" and
		-- must never match a real receipt.
		for _, row in Products.yieldTiers do
			if row.productId ~= 0 and row.productId == receiptInfo.ProductId then
				entry = {
					kind = "yield_tier",
					key = "yield_tier_" .. tostring(row.tier),
					tier = row.tier,
					name = row.name,
					id = row.productId,
				}
				break
			end
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

-- P4 — the COIN half of the yield ladder. This is what keeps a permanent paid
-- multiplier off the pay-to-win rail: every tier Robux can buy is also buyable
-- with coins, so Robux only skips the grind (HANDOFF §1). Server-authoritative:
-- the client sends a tier number and nothing else, and the price, the ordering
-- and the spend all happen here.
local function handleBuyYieldTier(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: any
	if typeof(p.tier) ~= "number" or p.tier ~= math.floor(p.tier) then
		return
	end
	if not buyLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local row
	for _, candidate in Products.yieldTiers do
		if candidate.tier == p.tier then
			row = candidate
			break
		end
	end
	if not row then
		return
	end

	local current = math.floor(tonumber((data :: any).yieldTier) or 0)
	if current >= row.tier then
		Remotes.event("Notify"):FireClient(player, {
			kind = "upgrade_blocked",
			text = "You already have " .. row.name .. ".",
		})
		return
	end
	-- Strictly one rung at a time, so tier 3 can never be reached for tier 3's
	-- price alone.
	if row.tier ~= current + 1 then
		Remotes.event("Notify"):FireClient(player, {
			kind = "upgrade_blocked",
			text = "Buy the previous upgrade first.",
		})
		return
	end
	if not EconomyService:TrySpendCoins(player, row.coinCost) then
		Remotes.event("Notify"):FireClient(player, {
			kind = "upgrade_blocked",
			text = "Not enough coins — " .. row.coinCost .. " 🪙 needed.",
		})
		return
	end
	(data :: any).yieldTier = row.tier
	DataService:Push(player)
	Remotes.event("Notify"):FireClient(player, {
		kind = "upgrade_bought",
		text = row.name .. " unlocked! Every batch now yields " .. row.multiplier .. "×.",
	})
	if AnalyticsService then
		AnalyticsService:Track(player, "yield_tier_bought", { tier = row.tier, paidWith = "coins" })
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
	Remotes.event("BuyYieldTier").OnServerEvent:Connect(handleBuyYieldTier)

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
