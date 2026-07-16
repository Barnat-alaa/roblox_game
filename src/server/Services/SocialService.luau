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

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local SocialService = {}
SocialService.Name = "SocialService"

local CafeService: any
local EconomyService: any
local AnalyticsService: any
local GoalService: any

local COMPLIMENT_REPUTATION = 2

local COMPLIMENTS: { [string]: string } = {
	nice_cafe = "loves your café! 💖",
	great_coffee = "says the coffee is great! ☕",
	cozy_vibes = "loves the cosy vibes ✨",
}

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

function SocialService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	GoalService = ServiceRegistry.get("GoalService")
end

function SocialService.Start(_self: any)
	Remotes.event("VisitCafe").OnServerEvent:Connect(handleVisit)
	Players.PlayerRemoving:Connect(function(player)
		visitLimiter:clear(player.UserId)
		complimentGiven[player.UserId] = nil
	end)
end

return SocialService
