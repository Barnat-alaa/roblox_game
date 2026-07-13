--!strict
-- Level/star curves + server-authoritative tutorial progress (Day 5).
-- CompleteTutorialStep only ever advances one strictly-ordered step at a
-- time; the completion reward is granted exactly once per profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Config.Progression)
local Tutorial = require(Shared.Config.Tutorial)
local EconomyConfig = require(Shared.Config.Economy)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Remotes = require(Shared.Network.Remotes)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local ProgressionService = {}
ProgressionService.Name = "ProgressionService"

local DataService: any
local EconomyService: any
local AnalyticsService: any

local stepLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

function ProgressionService.LevelFor(_self: any, xp: number): number
	return Progression.levelForXp(xp)
end

function ProgressionService.StarsFor(_self: any, reputation: number): number
	return Progression.starsForReputation(reputation)
end

local function handleTutorialStep(player: Player, stepIndex: unknown)
	if typeof(stepIndex) ~= "number" or stepIndex ~= math.floor(stepIndex) then
		return
	end
	if not stepLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data or data.stats.tutorialCompleted then
		return
	end
	local current = data.stats.tutorialStep or 0
	if stepIndex ~= current + 1 or stepIndex > #Tutorial.steps then
		return
	end

	data.stats.tutorialStep = stepIndex
	if AnalyticsService then
		if stepIndex == 1 then
			AnalyticsService:TrackOnce(player, "tutorial_started", {})
		end
		AnalyticsService:Track(player, "tutorial_step_completed", {
			step = stepIndex,
			id = Tutorial.steps[stepIndex].id,
		})
	end

	if stepIndex == #Tutorial.steps then
		data.stats.tutorialCompleted = true
		EconomyService:AddCoins(player, Tutorial.completionRewardCoins)
		Remotes.event("Notify"):FireClient(player, {
			kind = "tutorial_done",
			reward = Tutorial.completionRewardCoins,
		})
		if AnalyticsService then
			AnalyticsService:TrackOnce(player, "tutorial_completed", {})
		end
	end
	DataService:Push(player)
end

function ProgressionService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function ProgressionService.Start(_self: any)
	Remotes.event("CompleteTutorialStep").OnServerEvent:Connect(handleTutorialStep)
	Players.PlayerRemoving:Connect(function(player)
		stepLimiter:clear(player.UserId)
	end)
end

return ProgressionService
