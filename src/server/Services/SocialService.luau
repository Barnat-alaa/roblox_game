--!strict
-- Café visits + helping a neighbour by WORKING (P2c).
-- VisitCafe payloads (all validated here):
--   { plotIndex }   → teleport the visitor to that café's door
--   { home = true } → return the visitor to their own café
--
-- 2026-07-30 (P2c): the abstract help card is GONE. There is no longer a
-- `NeighbourHelp` remote, a HELP_ACTIONS table ("water plants", "stir a pot" —
-- none of which were real things happening in the world), or a compliment
-- whitelist. Helping is now a REAL action: walk inside a neighbour's café and do
-- the jobs the owner does — scrub the floor, clear a plate, run an order to a
-- table. Those prompts ask `SocialService:TryWork` whether the presser is
-- allowed, and it pays a visiting helper per action.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)
local Neighbour = require(Shared.Config.Neighbour)
local Grid = require(Shared.Utilities.Grid)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local SocialService = {}
SocialService.Name = "SocialService"

local CafeService: any
local DataService: any
local EconomyService: any
local AnalyticsService: any
local GoalService: any

-- Human-readable labels for the real jobs a visitor can do, used only in the
-- toast both sides see. The pay and the cap live in Config/Neighbour.
local WORK_LABELS: { [string]: string } = {
	clean_floor = "scrubbed the floor 🧽",
	clean_plate = "cleared a plate 🍽️",
	serve = "served a customer ☕",
}

local visitLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

local function teleportTo(player: Player, origin: CFrame)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
		hrp.CFrame = origin * CFrame.new(width / 2, 4, -6)
	end
end

local function isNearPlot(player: Player, origin: CFrame, maxDistance: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return false
	end
	-- Rect distance (S2 deep plots): 0 while inside the café, grows outside.
	return Grid.distanceToPlotRect(origin, hrp.Position) <= maxDistance
end

local function handleVisit(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	if not visitLimiter:check(player.UserId, os.clock()) then
		return
	end
	local p = payload :: any

	-- "Take me home" — always allowed.
	if p.home == true then
		local ownOrigin = CafeService:GetPlotOrigin(player)
		if ownOrigin then
			teleportTo(player, ownOrigin)
		end
		return
	end

	local plotIndex = p.plotIndex
	if typeof(plotIndex) ~= "number" or plotIndex ~= math.floor(plotIndex) then
		return
	end
	local origin, ownerUserId = CafeService:GetPlotInfo(plotIndex)
	if not origin then
		return
	end
	if not ownerUserId then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "plot_empty" })
		return
	end
	if ownerUserId == player.UserId then
		teleportTo(player, origin) -- visiting yourself = walking home
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "plot_empty" })
		return
	end

	-- Visit: teleport to the door and tell both sides. What you DO once you are
	-- inside is the real interaction now (TryWork below) — there is nothing left
	-- to send from a card.
	teleportTo(player, origin)
	Remotes.event("Notify"):FireClient(player, {
		kind = "visited",
		plotIndex = plotIndex,
		owner = owner.DisplayName,
	})
	Remotes.event("Notify"):FireClient(owner, {
		kind = "visitor",
		name = player.DisplayName,
	})
	if AnalyticsService then
		AnalyticsService:TrackOnce(player, "first_cafe_visit", {})
		AnalyticsService:Track(player, "cafe_visit", { plotIndex = plotIndex })
	end
	if GoalService then
		GoalService:Bump(player, "visit_neighbour", 1)
	end
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function socialOf(data: Types.PlayerData): Types.SocialState
	if typeof(data.social) ~= "table" then
		(data :: any).social = { friendship = {}, helpLog = {}, lastGoodNeighbourDay = 0 }
	end
	local s = data.social
	if typeof(s.friendship) ~= "table" then
		s.friendship = {}
	end
	if typeof(s.helpLog) ~= "table" then
		s.helpLog = {}
	end
	s.lastGoodNeighbourDay = tonumber(s.lastGoodNeighbourDay) or 0
	return s
end

local function blocked(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, { kind = "help_blocked", text = text })
end

-- ————— P2c: helping by WORKING —————
--
-- THE authorisation gate for every action that used to be owner-only. Each of
-- those prompts now asks this instead of comparing `who == owner`:
--
--     if SocialService:TryWork(who, owner, "clean_plate") then ... end
--
-- • The owner working their own café: always yes, nothing is paid, no state moves.
-- • A visitor: yes if they are INSIDE the café and the owner is online — and the
--   action pays them a fee, up to a per-neighbour daily cap. Past the cap the
--   action still succeeds (you can keep helping a friend); it just stops paying,
--   so there is no reason to camp one café.
-- • Anyone else (standing outside, café empty, owner offline): no.
--
-- The fee is minted for the helper, never taken from the owner: the café keeps
-- its whole sale, its Buzz and its satisfaction, so being helped is pure upside
-- and can't be farmed against you.
-- Authorisation ONLY — no payment, no state change, no toast. Used for the half
-- of a job that shouldn't pay on its own (picking an order off the shelf is only
-- worth something once it reaches the table).
function SocialService.CanWork(_self: any, worker: Player, owner: Player): boolean
	if worker == owner then
		return true
	end
	if not Neighbour.enabled then
		return false
	end
	local origin = CafeService:GetPlotOrigin(owner)
	if not origin then
		return false
	end
	-- Must actually be in the room. distanceToPlotRect is 0 anywhere inside the
	-- plot, so this is a small tolerance around the footprint, not a radius.
	return isNearPlot(worker, origin, Neighbour.insideTolerance)
end

function SocialService.TryWork(
	_self: any,
	worker: Player,
	owner: Player,
	actionKey: string
): boolean
	if worker == owner then
		return true -- the owner, in their own café: unchanged behaviour
	end
	if not SocialService:CanWork(worker, owner) then
		if Neighbour.enabled then
			blocked(worker, "Stand inside their café to help.")
		end
		return false
	end
	local data = DataService:GetProfile(worker)
	if not data then
		return false
	end

	-- Anti-farm: a per-neighbour daily count, persisted so it survives a rejoin.
	local s = socialOf(data)
	local ownerKey = tostring(owner.UserId)
	local d = today()
	local log = s.helpLog[ownerKey]
	if typeof(log) ~= "table" or (tonumber(log.day) or 0) ~= d then
		log = { day = d, count = 0 }
		s.helpLog[ownerKey] = log
	end
	local paidCount = math.max(0, math.floor(tonumber(log.count) or 0))

	local label = WORK_LABELS[actionKey] or "lent a hand 🤝"
	if paidCount >= Neighbour.maxPaidActionsPerNeighbourPerDay then
		-- Still allowed — just unpaid. Say so once the cap is hit, so the silence
		-- reads as a rule rather than a bug.
		Remotes.event("Notify"):FireClient(worker, {
			kind = "helped",
			text = "You " .. label .. " (daily pay cap reached — thanks anyway!)",
		})
		return true
	end
	log.count = paidCount + 1

	local pay = tonumber(Neighbour.payPerAction[actionKey]) or Neighbour.defaultPay
	s.friendship[ownerKey] = (tonumber(s.friendship[ownerKey]) or 0) + Neighbour.friendshipPerAction
	EconomyService:AddCoins(worker, pay)

	-- "Good Neighbour": first paid help of the day at ANY neighbour, once daily.
	local bonus = 0
	if s.lastGoodNeighbourDay ~= d then
		s.lastGoodNeighbourDay = d
		bonus = Neighbour.goodNeighbourBonus
		EconomyService:AddCoins(worker, bonus)
	end
	DataService:Push(worker)

	local bits = { "+" .. pay .. " 🪙", "+" .. Neighbour.friendshipPerAction .. " 💚" }
	if bonus > 0 then
		table.insert(bits, "+" .. bonus .. " 🪙 Good Neighbour!")
	end
	Remotes.event("Notify"):FireClient(worker, {
		kind = "helped",
		text = "You " .. label .. "  " .. table.concat(bits, "  "),
	})
	Remotes.event("Notify"):FireClient(owner, {
		kind = "neighbour_helped",
		text = worker.DisplayName .. " " .. label .. " in your café!",
	})
	if AnalyticsService then
		AnalyticsService:Track(
			worker,
			"neighbour_help",
			{ action = actionKey, owner = owner.UserId }
		)
	end
	return true
end

function SocialService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	GoalService = ServiceRegistry.get("GoalService")
end

function SocialService.Start(_self: any)
	Remotes.event("VisitCafe").OnServerEvent:Connect(handleVisit)
	Players.PlayerRemoving:Connect(function(player)
		visitLimiter:clear(player.UserId)
	end)
end

return SocialService
