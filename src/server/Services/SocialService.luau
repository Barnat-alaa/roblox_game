--!strict
-- Café visits + safe predefined compliments (Day 5 — the social MVP).
-- VisitCafe payloads (all validated here):
--   { plotIndex }                → teleport the visitor to that café's door
--   { plotIndex, compliment }   → leave ONE predefined compliment per owner
--                                  per session (+2 reputation for the owner)
--   { home = true }              → return the visitor to their own café
-- No free text anywhere — compliments come from a fixed whitelist (§19).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Network.Remotes)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local EconomyConfig = require(Shared.Config.Economy)
local Grid = require(Shared.Utilities.Grid)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local SocialService = {}
SocialService.Name = "SocialService"

local CafeService: any
local DataService: any
local EconomyService: any
local KitchenService: any
local AnalyticsService: any
local GoalService: any

local COMPLIMENT_REPUTATION = 2

local COMPLIMENTS: { [string]: string } = {
	nice_cafe = "loves your café! 💖",
	great_coffee = "says the coffee is great! ☕",
	cozy_vibes = "loves the cosy vibes ✨",
}

-- Co-op neighbour help (Phase C §4a). Each action is once per neighbour per day
-- (anti-farm, persisted so it survives a rejoin). Data-driven: a new helpful
-- action is a new row. The helper earns coins/xp/rep + friendship points; the
-- (online) owner gets reputation and/or a small Buzz bump.
type HelpAction = {
	label: string,
	helperCoins: number,
	helperXp: number,
	helperRep: number,
	friendship: number,
	ownerRep: number,
	ownerBuzz: number,
}
local HELP_ACTIONS: { [string]: HelpAction } = {
	water_plants = {
		label = "watered the plants 🌱",
		helperCoins = 15,
		helperXp = 8,
		helperRep = 0,
		friendship = 2,
		ownerRep = 1,
		ownerBuzz = 0,
	},
	bus_table = {
		label = "bussed a table 🧽",
		helperCoins = 0,
		helperXp = 6,
		helperRep = 3,
		friendship = 2,
		ownerRep = 0,
		ownerBuzz = 1,
	},
	stir_pot = {
		label = "stirred a pot 🥄",
		helperCoins = 12,
		helperXp = 6,
		helperRep = 1,
		friendship = 2,
		ownerRep = 0,
		ownerBuzz = 1,
	},
	hand_flyers = {
		label = "handed out flyers 📣",
		helperCoins = 0,
		helperXp = 6,
		helperRep = 4,
		friendship = 3,
		ownerRep = 0,
		ownerBuzz = 2,
	},
}
local GOOD_NEIGHBOUR_BONUS = 25 -- first help of the day (any neighbour), once daily

local visitLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)
-- One compliment per (visitor → owner) pair per session; no farming.
local complimentGiven: { [number]: { [number]: boolean } } = {}

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

	local compliment = p.compliment
	if compliment == nil then
		-- Plain visit: teleport to the door and tell both sides.
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
		return
	end

	-- Compliment: whitelist only, must be standing at that café, once per owner.
	if typeof(compliment) ~= "string" or COMPLIMENTS[compliment] == nil then
		return
	end
	if not isNearPlot(player, origin, 50) then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "too_far" })
		return
	end
	local given = complimentGiven[player.UserId]
	if not given then
		given = {}
		complimentGiven[player.UserId] = given
	end
	if given[ownerUserId] then
		return
	end
	given[ownerUserId] = true

	EconomyService:AddReputation(owner, COMPLIMENT_REPUTATION)
	Remotes.event("Notify"):FireClient(owner, {
		kind = "compliment",
		from = player.DisplayName,
		text = COMPLIMENTS[compliment],
	})
	Remotes.event("Notify"):FireClient(player, { kind = "complimented" })
	if AnalyticsService then
		AnalyticsService:Track(player, "compliment_sent", { compliment = compliment })
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

-- Co-op help (§4a): walk into an online neighbour's café and do something useful.
-- Mirrors the handleVisit guard ladder. Each action is once per neighbour per day
-- (persisted anti-farm). The helper earns coins/xp/rep + friendship; the owner
-- gets reputation and/or a Buzz bump.
local function handleHelp(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	if not visitLimiter:check(player.UserId, os.clock()) then
		return
	end
	local p = payload :: any
	if typeof(p.plotIndex) ~= "number" or p.plotIndex ~= math.floor(p.plotIndex) then
		return
	end
	if typeof(p.actionId) ~= "string" then
		return
	end
	local action = HELP_ACTIONS[p.actionId]
	if not action then
		return
	end
	local origin, ownerUserId = CafeService:GetPlotInfo(p.plotIndex)
	if not origin then
		return
	end
	if not ownerUserId then
		blocked(player, "That café is empty.")
		return
	end
	if ownerUserId == player.UserId then
		blocked(player, "You can't help your own café.")
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner then
		blocked(player, "Your neighbour isn't around right now.")
		return
	end
	if not isNearPlot(player, origin, 50) then
		blocked(player, "Get closer to their café to help.")
		return
	end

	-- Anti-farm: each action once per neighbour per day (persisted, survives rejoin).
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local s = socialOf(data)
	local ownerKey = tostring(ownerUserId)
	local log = s.helpLog[ownerKey]
	if typeof(log) ~= "table" then
		log = {}
		s.helpLog[ownerKey] = log
	end
	local d = today()
	if log[p.actionId] == d then
		blocked(player, "You already did that for them today.")
		return
	end
	log[p.actionId] = d

	-- Friendship (stored on the helper's side, per neighbour).
	s.friendship[ownerKey] = (tonumber(s.friendship[ownerKey]) or 0) + action.friendship

	-- Helper rewards.
	if action.helperCoins > 0 then
		EconomyService:AddCoins(player, action.helperCoins)
	end
	if action.helperRep > 0 then
		EconomyService:AddReputation(player, action.helperRep)
	end
	if action.helperXp > 0 then
		EconomyService:AddExperience(player, action.helperXp)
	end

	-- "Good Neighbour" first-help-of-the-day bonus (any neighbour, once daily).
	local bonus = 0
	if s.lastGoodNeighbourDay ~= d then
		s.lastGoodNeighbourDay = d
		bonus = GOOD_NEIGHBOUR_BONUS
		EconomyService:AddCoins(player, bonus)
	end
	DataService:Push(player)

	-- Owner benefit (they're online — checked above).
	if action.ownerRep > 0 then
		EconomyService:AddReputation(owner, action.ownerRep)
	end
	if action.ownerBuzz > 0 then
		KitchenService:AddBuzz(owner, action.ownerBuzz)
	end

	-- Feedback to both sides.
	local bits = {}
	if action.helperCoins > 0 then
		table.insert(bits, "+" .. action.helperCoins .. " 🪙")
	end
	if action.helperRep > 0 then
		table.insert(bits, "+" .. action.helperRep .. " ⭐")
	end
	table.insert(bits, "+" .. action.friendship .. " 💚")
	if bonus > 0 then
		table.insert(bits, "+" .. bonus .. " 🪙 Good Neighbour!")
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "helped",
		text = "You " .. action.label .. "  " .. table.concat(bits, "  "),
	})
	Remotes.event("Notify"):FireClient(owner, {
		kind = "neighbour_helped",
		text = player.DisplayName .. " " .. action.label,
	})
	if AnalyticsService then
		AnalyticsService:Track(
			player,
			"neighbour_help",
			{ action = p.actionId, owner = ownerUserId }
		)
	end
end

function SocialService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	KitchenService = ServiceRegistry.get("KitchenService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	GoalService = ServiceRegistry.get("GoalService")
end

function SocialService.Start(_self: any)
	Remotes.event("VisitCafe").OnServerEvent:Connect(handleVisit)
	Remotes.event("NeighbourHelp").OnServerEvent:Connect(handleHelp)
	Players.PlayerRemoving:Connect(function(player)
		visitLimiter:clear(player.UserId)
		complimentGiven[player.UserId] = nil
	end)
end

return SocialService
