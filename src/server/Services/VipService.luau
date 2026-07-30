--!strict
-- Server-level VIP event (docs/GAMEPLAY_DIRECTION.md §3, IMPLEMENTATION_MAP
-- "Feature 3"). A rare "brainrot" celebrity visits the busiest café on the
-- server. As of 2026-07-26 this service is only the SCHEDULER: it scores every
-- OPEN café by Buzz, then hands the winner to CustomerService:SpawnVip, which
-- walks the VIP in as a real customer — it enters, sits in an empty chair, orders
-- a RARE dish, WAITS to be served (owner/waiter), and leaves the earned gift box.
--
-- The old standalone instant-serve walker lived here; it is gone. Reusing the
-- customer lifecycle is why "sit → order → wait → served → tip/gift" all behave
-- identically for the VIP and everyone else (owner bug 2, fixed).
--
-- Rails: server-authoritative; the box is EARNED and opened for FREE (never a
-- paid random box — HANDOFF §1); rewards are a data table (Config/Gifts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vip = require(Shared.Config.Vip)
local World = require(Shared.Config.World)
local AssetManifest = require(Shared.Config.AssetManifest)
local Remotes = require(Shared.Network.Remotes)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local VipService = {}
VipService.Name = "VipService"

local CafeService: any
local KitchenService: any
local CustomerService: any
local AssetLibraryService: any
local AnalyticsService: any

-- ————— café scoring —————

type Target = { index: number, owner: Player, score: number }

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
					best = { index = index, owner = owner, score = score }
				end
			end
		end
	end
	return best
end

-- ————— the event —————

-- The next scheduled event, on the SERVER clock (workspace:GetServerTimeNow), so
-- every client's countdown agrees and a late joiner sees the same number as
-- everyone else. The client never computes this — it only renders it (P3).
local nextEventAt = 0

local function broadcastTimer()
	Remotes.event("VipEvent"):FireAllClients({
		kind = "timer",
		nextAt = nextEventAt,
		assetId = AssetManifest.vip and AssetManifest.vip.assetId or nil,
	})
end

-- Returns true if a VIP actually walked in, so the caller can decide between the
-- full interval and a short retry.
local function runVipEvent(): boolean
	local target = bestCafe()
	if not target then
		return false -- nobody's open; retry soon rather than losing the slot
	end
	local spawned = CustomerService:SpawnVip(target.owner)
	if not spawned then
		return false
	end
	if AnalyticsService then
		AnalyticsService:Track(target.owner, "vip_incoming", { score = target.score })
	end
	-- Tell the whole street, not just the winner: the countdown everyone watched
	-- should resolve visibly into "it went THERE".
	Remotes.event("VipEvent"):FireAllClients({
		kind = "arrived",
		cafe = target.owner.DisplayName,
		plotIndex = target.index,
	})
	return true
end

function VipService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	KitchenService = ServiceRegistry.get("KitchenService")
	CustomerService = ServiceRegistry.get("CustomerService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function VipService.Start(_self: any)
	if not Vip.enabled then
		Log.info("VipService disabled (Config/Vip.enabled = false)")
		return
	end

	local function loop()
		nextEventAt = workspace:GetServerTimeNow() + Vip.firstEventDelaySeconds
		broadcastTimer()
		while true do
			local wait = nextEventAt - workspace:GetServerTimeNow()
			if wait > 0 then
				task.wait(math.min(wait, 5)) -- wake often so a late joiner is served promptly
			end
			if workspace:GetServerTimeNow() >= nextEventAt then
				-- CustomerService owns the one-VIP-at-a-time guard; a busy or
				-- not-ready attempt returns false and we retry shortly instead of
				-- burning the whole 30-minute slot.
				local ok, landed = pcall(runVipEvent)
				if not ok then
					Log.warn("VIP event failed:", landed)
				end
				nextEventAt = workspace:GetServerTimeNow()
					+ (
						if ok and landed == true
							then Vip.eventIntervalSeconds
							else Vip.retryDelaySeconds
					)
				broadcastTimer()
			end
		end
	end

	-- A joiner mid-cycle needs the countdown immediately, not at the next tick.
	Players.PlayerAdded:Connect(function(player)
		if nextEventAt > 0 then
			Remotes.event("VipEvent"):FireClient(player, {
				kind = "timer",
				nextAt = nextEventAt,
				assetId = AssetManifest.vip and AssetManifest.vip.assetId or nil,
			})
		end
	end)

	-- Wait for the brainrot template to finish loading before the first attempt,
	-- so no early event is wasted on a not-yet-ready asset.
	if AssetLibraryService then
		AssetLibraryService:OnReady(function()
			task.spawn(loop)
		end)
	else
		task.spawn(loop)
	end
	Log.info("VipService ready (scheduled VIP event every " .. Vip.eventIntervalSeconds .. "s)")
end

return VipService
