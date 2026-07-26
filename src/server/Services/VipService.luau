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
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local VipService = {}
VipService.Name = "VipService"

local CafeService: any
local KitchenService: any
local CustomerService: any
local AssetLibraryService: any
local AnalyticsService: any

local rng = Random.new()

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

local function runVipEvent()
	local target = bestCafe()
	if not target then
		return -- nobody's open; try again next interval
	end
	local spawned = CustomerService:SpawnVip(target.owner)
	if spawned and AnalyticsService then
		AnalyticsService:Track(target.owner, "vip_incoming", { score = target.score })
	end
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
		while true do
			task.wait(rng:NextNumber(Vip.spawnIntervalMinSeconds, Vip.spawnIntervalMaxSeconds))
			-- CustomerService owns the one-VIP-at-a-time guard; a busy or not-ready
			-- attempt simply returns false and we retry next interval.
			local ok, err = pcall(runVipEvent)
			if not ok then
				Log.warn("VIP event failed:", err)
			end
		end
	end

	-- Wait for the brainrot template to finish loading before the first attempt,
	-- so no early event is wasted on a not-yet-ready asset.
	if AssetLibraryService then
		AssetLibraryService:OnReady(function()
			task.spawn(loop)
		end)
	else
		task.spawn(loop)
	end
	Log.info("VipService ready (brainrot VIP via CustomerService)")
end

return VipService
