--!strict
-- Phase C-4b mischief (docs/GAMEPLAY_DIRECTION.md §4b, IMPLEMENTATION_MAP
-- "Feature 4 / 4b"). The ONE rails-BRUSHING mechanic — owner-approved, but ONLY
-- with the FULL guardrails in Config/Mischief, all enforced here. Three actions on
-- the single `Mischief` remote (method-tagged, validated up front):
--   • buy_bomb   — spend coins for one smell bomb (a consumable).
--   • smell_bomb — consume a bomb; a GUARANTEED pull if an eligible customer exists.
--   • recruit    — free; success scales with your REPUTATION.
-- The actual pull is CustomerService:LureOne (the victim's WAITING customer leaves
-- calmly — no penalty, no permanent loss — and re-appears at the caster's café).
--
-- Every guardrail (Config/Mischief): bought consumable + per-caster COOLDOWN;
-- proximity to the target; VIPs never eligible (resistance); only NOT-YET-SERVED,
-- un-seated customers; per-customer IMMUNITY + per-victim MAX-STOLEN cap; a VISIBLE
-- green-vapour telegraph. Server-authoritative; ships behind `enabled`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Mischief = require(Shared.Config.Mischief)
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)
local Recipes = require(Shared.Config.Recipes)
local Grid = require(Shared.Utilities.Grid)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)

local MischiefService = {}
MischiefService.Name = "MischiefService"

local CafeService: any
local DataService: any
local EconomyService: any
local CustomerService: any
local KitchenService: any
local AnalyticsService: any

local rng = Random.new()
local limiter = RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)
-- Per-caster cooldown (os.clock of the last attempt) and per-victim steal window.
local lastAttemptAt: { [number]: number } = {}
local stolen: { [number]: { windowStart: number, count: number } } = {}
-- Theft (P2a) keeps its OWN cooldown + victim window: lures and thefts are
-- different actions and sharing a timer would let one silently block the other.
local lastTheftAt: { [number]: number } = {}
local itemsStolen: { [number]: { windowStart: number, count: number } } = {}

local METHODS: { [string]: boolean } =
	{ buy_bomb = true, smell_bomb = true, recruit = true, steal = true }

local function tell(player: Player, kind: string, text: string?)
	Remotes.event("Notify"):FireClient(player, { kind = kind, text = text })
end

-- Proximity: 0 while inside the café, grows outside (copied from SocialService so
-- deep S2 plots measure by rect distance, not centre).
local function isNearPlot(player: Player, origin: CFrame, maxDistance: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return false
	end
	return Grid.distanceToPlotRect(origin, hrp.Position) <= maxDistance
end

local function cooldownLeft(userId: number): number
	local last = lastAttemptAt[userId]
	if last == nil then
		return 0
	end
	return math.max(0, math.ceil(Mischief.cooldownSeconds - (os.clock() - last)))
end

-- Victim protection: a café loses at most maxStolenPerWindow customers per window.
local function victimAtCap(victimUserId: number): boolean
	local s = stolen[victimUserId]
	if s == nil or os.clock() - s.windowStart >= Mischief.windowSeconds then
		return false
	end
	return s.count >= Mischief.maxStolenPerWindow
end

local function noteStolen(victimUserId: number)
	local s = stolen[victimUserId]
	if s == nil or os.clock() - s.windowStart >= Mischief.windowSeconds then
		stolen[victimUserId] = { windowStart = os.clock(), count = 1 }
	else
		s.count += 1
	end
end

-- The same cooldown/cap shape as the lure, on the theft's own timers.
local function theftCooldownLeft(userId: number): number
	local last = lastTheftAt[userId]
	if last == nil then
		return 0
	end
	return math.max(0, math.ceil(Mischief.theftCooldownSeconds - (os.clock() - last)))
end

local function victimAtItemCap(victimUserId: number): boolean
	local s = itemsStolen[victimUserId]
	if s == nil or os.clock() - s.windowStart >= Mischief.theftVictimWindowSeconds then
		return false
	end
	return s.count >= Mischief.theftMaxPerVictimWindow
end

local function noteItemStolen(victimUserId: number)
	local s = itemsStolen[victimUserId]
	if s == nil or os.clock() - s.windowStart >= Mischief.theftVictimWindowSeconds then
		itemsStolen[victimUserId] = { windowStart = os.clock(), count = 1 }
	else
		s.count += 1
	end
end

-- buy_bomb: spend coins server-side, add one smell bomb.
local function handleBuy(player: Player)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	if not EconomyService:TrySpendCoins(player, Mischief.bombCost) then
		tell(player, "mischief_blocked", "Not enough coins for a smell bomb.")
		return
	end
	data.smellBombs = math.max(0, math.floor(tonumber(data.smellBombs) or 0)) + 1
	DataService:Push(player)
	tell(player, "mischief_bought", "Smell bomb bought — you have " .. data.smellBombs .. ".")
	if AnalyticsService then
		AnalyticsService:Track(player, "smell_bomb_bought", { count = data.smellBombs })
	end
end

-- smell_bomb / recruit: the guarded pull. Mirrors SocialService.handleHelp's guard
-- ladder, then layers the mischief-specific guardrails.
local function handleLure(player: Player, p: any, method: string)
	if typeof(p.plotIndex) ~= "number" or p.plotIndex ~= math.floor(p.plotIndex) then
		return
	end
	local origin, ownerUserId = CafeService:GetPlotInfo(p.plotIndex)
	if not origin then
		return
	end
	if not ownerUserId then
		tell(player, "mischief_blocked", "That café is empty.")
		return
	end
	if ownerUserId == player.UserId then
		tell(player, "mischief_blocked", "You can't poach your own café.")
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner then
		tell(player, "mischief_blocked", "Your neighbour isn't around right now.")
		return
	end
	if not isNearPlot(player, origin, Mischief.proximityRadius) then
		tell(player, "mischief_blocked", "Get closer to their café first.")
		return
	end

	local secs = cooldownLeft(player.UserId)
	if secs > 0 then
		tell(player, "mischief_blocked", "Cooling off — wait " .. secs .. "s.")
		return
	end
	if victimAtCap(ownerUserId) then
		tell(player, "mischief_blocked", "Their café is protected right now.")
		return
	end

	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	if method == "smell_bomb" and (tonumber(data.smellBombs) or 0) < 1 then
		tell(player, "mischief_blocked", "No smell bombs — buy one first.")
		return
	end
	-- Only NOT-YET-SERVED, un-seated, non-VIP customers are eligible (peeked here so
	-- a recruit roll / bomb is never spent on an empty café).
	if not CustomerService:HasLureTarget(ownerUserId) then
		tell(player, "mischief_blocked", "No waiting customer to lure there.")
		return
	end

	-- Recruit is free but chancy — success scales with reputation; a miss still
	-- costs the cooldown (no spam-retry) and shows a small telegraph.
	if method == "recruit" then
		local rep = tonumber(data.reputation) or 0
		local chance = math.clamp(
			Mischief.recruitBaseChance + rep * Mischief.recruitRepScale,
			Mischief.recruitMinChance,
			Mischief.recruitMaxChance
		)
		if rng:NextNumber() > chance then
			lastAttemptAt[player.UserId] = os.clock()
			Fx.smellVapour(origin.Position, 2)
			tell(player, "mischief_blocked", "They weren't tempted this time…")
			if AnalyticsService then
				AnalyticsService:Track(player, "mischief_recruit_fail", { owner = ownerUserId })
			end
			return
		end
	end

	-- Do the pull FIRST; only charge (cooldown / bomb / victim cap) if it landed.
	local pulled = CustomerService:LureOne(owner, player, Mischief.immunitySeconds)
	if not pulled then
		tell(player, "mischief_blocked", "They slipped away — try again.")
		return
	end
	lastAttemptAt[player.UserId] = os.clock()
	noteStolen(ownerUserId)
	if method == "smell_bomb" then
		data.smellBombs = math.max(0, (tonumber(data.smellBombs) or 1) - 1)
		DataService:Push(player)
	end
	Fx.smellVapour(origin.Position, Mischief.vapourSeconds)

	local how = if method == "smell_bomb" then "smell bomb" else "charm"
	tell(player, "mischief_done", "You lured a customer over with a " .. how .. "! 😈")
	tell(owner, "mischief_hit", player.DisplayName .. " lured a customer away! 💨")
	if AnalyticsService then
		AnalyticsService:Track(player, "mischief_lure", { method = method, owner = ownerUserId })
	end
end

-- ————— Theft (P2a): take ONE ready item off a neighbour's wall shelf —————

-- Resolve + fully validate a steal attempt. Returns the pieces the caller needs
-- on success, or nil plus the reason to show the thief. Everything the client
-- could lie about (which plot, which recipe, where it is standing) is re-derived
-- here from server state.
local function resolveSteal(player: Player, plotIndex: number, recipeId: string): (any?, string?)
	local origin, ownerUserId = CafeService:GetPlotInfo(plotIndex)
	if not origin then
		return nil, nil -- not a real plot: stay silent, this is a malformed payload
	end
	if not ownerUserId then
		return nil, "That café is empty."
	end
	if ownerUserId == player.UserId then
		return nil, "You can't steal from your own café."
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner then
		return nil, "Your neighbour isn't around right now."
	end
	local recipe = Recipes[recipeId]
	if not recipe then
		return nil, nil
	end

	-- You must be AT the shelf. The shelf part is the authority on where that is,
	-- so a thief cannot stand at the door and claim a shelf across the room.
	local shelf = KitchenService:GetShelfPart(owner, recipeId)
	if not shelf then
		return nil, "They don't have a shelf for that."
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return nil, nil
	end
	if (hrp.Position - shelf.Position).Magnitude > Mischief.theftShelfRadius then
		return nil, "Get right up to the shelf."
	end

	local secs = theftCooldownLeft(player.UserId)
	if secs > 0 then
		return nil, "Lie low for " .. secs .. "s before your next steal."
	end
	if victimAtItemCap(ownerUserId) then
		return nil, "Their café is watching you — try later."
	end

	-- The victim must actually have one ready, and the thief must be able to
	-- HOLD it (unlocked + under the per-recipe cap). Checked before anything is
	-- removed, so a steal is all-or-nothing and can never destroy the item.
	local ownerData = DataService:GetProfile(owner)
	if not ownerData then
		return nil, nil
	end
	local _, available = KitchenService:GetStockCounts(ownerData, recipeId)
	if available <= 0 then
		return nil, "That shelf is empty now."
	end
	if not KitchenService:CanReceiveServing(player, recipeId) then
		return nil, "You can't carry any more " .. recipe.displayName .. "."
	end
	return { owner = owner, ownerUserId = ownerUserId, recipe = recipe, shelf = shelf }, nil
end

local function handleSteal(player: Player, p: any)
	if not Mischief.theftEnabled then
		return
	end
	if typeof(p.plotIndex) ~= "number" or p.plotIndex ~= math.floor(p.plotIndex) then
		return
	end
	if typeof(p.recipeId) ~= "string" then
		return
	end
	local hit, reason = resolveSteal(player, p.plotIndex, p.recipeId)
	if not hit then
		if reason then
			tell(player, "steal_blocked", reason)
		end
		return
	end

	-- Move the item: it LEAVES their café and arrives in yours. Take first, and
	-- hand back if the receive somehow fails, so a serving is never duplicated
	-- nor destroyed.
	if not KitchenService:TakeServing(hit.owner, p.recipeId) then
		tell(player, "steal_blocked", "That shelf is empty now.")
		return
	end
	if not KitchenService:AddStolenServing(player, p.recipeId) then
		KitchenService:AddStolenServing(hit.owner, p.recipeId)
		tell(player, "steal_blocked", "You couldn't carry it.")
		return
	end

	lastTheftAt[player.UserId] = os.clock()
	noteItemStolen(hit.ownerUserId)
	-- No silent theft: a visible puff at the shelf, same telegraph family as the
	-- lure vapour.
	Fx.smellVapour(hit.shelf.Position, Mischief.theftVapourSeconds)

	-- "1×" rather than "a"/"an": dish names are config-driven, so an article
	-- chosen here goes wrong the moment a vowel shows up ("a Espresso").
	local dish = "1× " .. hit.recipe.displayName
	tell(
		player,
		"steal_done",
		"You pocketed " .. dish .. " from " .. hit.owner.DisplayName .. "'s café! 🫳"
	)
	-- The victim is told WHO — naming the thief is the point of the mechanic.
	tell(
		hit.owner,
		"steal_hit",
		player.DisplayName .. " stole " .. dish .. " from your café! 😾"
	)
	if AnalyticsService then
		AnalyticsService:Track(
			player,
			"item_stolen",
			{ recipe = p.recipeId, owner = hit.ownerUserId }
		)
	end
end

-- The picker's data source: which of this neighbour's shelves you could actually
-- rob right now. Returns the shelf PART per row so the client never guesses a
-- path. Filtered to recipes the thief has unlocked, because those are the only
-- ones they can hold (see KitchenService.AddStolenServing).
local function handleStockQuery(player: Player, payload: unknown): any
	if not (Mischief.enabled and Mischief.theftEnabled) then
		return nil
	end
	if typeof(payload) ~= "table" then
		return nil
	end
	if not limiter:check(player.UserId, os.clock()) then
		return nil
	end
	local p = payload :: any
	if typeof(p.plotIndex) ~= "number" or p.plotIndex ~= math.floor(p.plotIndex) then
		return nil
	end
	local origin, ownerUserId = CafeService:GetPlotInfo(p.plotIndex)
	if not (origin and ownerUserId) or ownerUserId == player.UserId then
		return nil
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local ownerData = if owner then DataService:GetProfile(owner) else nil
	local thiefData = DataService:GetProfile(player)
	if not (owner and ownerData and thiefData) then
		return nil
	end

	local rows = {}
	for recipeId, recipe in Recipes do
		if thiefData.unlockedRecipes[recipeId] == true then
			local _, available = KitchenService:GetStockCounts(ownerData, recipeId)
			local shelf = if available > 0
				then KitchenService:GetShelfPart(owner, recipeId)
				else nil
			if shelf then
				table.insert(rows, {
					recipeId = recipeId,
					name = recipe.displayName,
					count = available,
					shelf = shelf,
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.count == b.count then
			return a.recipeId < b.recipeId
		end
		return a.count > b.count
	end)
	return { owner = owner.DisplayName, items = rows }
end

local function handleMischief(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	if not limiter:check(player.UserId, os.clock()) then
		return
	end
	local p = payload :: any
	if typeof(p.method) ~= "string" or not METHODS[p.method] then
		return
	end
	if p.method == "buy_bomb" then
		handleBuy(player)
	elseif p.method == "steal" then
		handleSteal(player, p)
	else
		handleLure(player, p, p.method)
	end
end

function MischiefService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	CustomerService = ServiceRegistry.get("CustomerService")
	KitchenService = ServiceRegistry.get("KitchenService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function MischiefService.Start(_self: any)
	if not Mischief.enabled then
		Log.info("MischiefService disabled (Config/Mischief.enabled = false)")
		return
	end
	Remotes.event("Mischief").OnServerEvent:Connect(handleMischief)
	Remotes.func("NeighbourStock").OnServerInvoke = handleStockQuery
	Players.PlayerRemoving:Connect(function(player)
		limiter:clear(player.UserId)
		lastAttemptAt[player.UserId] = nil
		stolen[player.UserId] = nil
		lastTheftAt[player.UserId] = nil
		itemsStolen[player.UserId] = nil
	end)
	Log.info("MischiefService ready (smell bomb + recruit + shelf theft, guardrailed)")
end

return MischiefService
