--!strict
-- Session + playtime gifts (owner bug 1, 2026-07-26). A gift is granted the
-- moment a player connects, and another for every Config.intervalSeconds of
-- CONNECTED play. The server owns the clock and the grant; the client only shows
-- a live countdown pill (SessionRewardController) fed the next-gift server time.
--
-- Rails (HANDOFF §1): EARNED by playing, never bought, no fake urgency — the
-- countdown only ever ticks toward a free reward, and the odds never touch money
-- (RewardMath.rollReward over Config/SessionRewards). Server-authoritative: every
-- coin/rep grant goes through EconomyService, the client sends nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.SessionRewards)
local Remotes = require(Shared.Network.Remotes)
local RewardMath = require(Shared.Utilities.RewardMath)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)

local SessionRewardService = {}
SessionRewardService.Name = "SessionRewardService"

local DataService: any
local EconomyService: any
local AnalyticsService: any

local rng = Random.new()
-- userId → true while that player is connected; cleared on leave so the per-
-- player loop and grants stop promptly instead of firing at a gone player.
local active: { [number]: boolean } = {}

-- Tell the client where the next gift lands on the SYNCED server clock
-- (GetServerTimeNow reads the same on both sides), so the pill just ticks down.
local function sendTimer(player: Player, nextAt: number)
	Remotes.event("SessionReward"):FireClient(player, {
		kind = "timer",
		nextAt = nextAt,
		intervalSeconds = Config.intervalSeconds,
	})
end

-- Roll + grant one gift, server-side, and tell the client to celebrate.
local function grant(player: Player, reason: string)
	local reward = RewardMath.rollReward(Config.rewards, rng:NextNumber(), rng:NextNumber())
	if reward.kind == "reputation" then
		EconomyService:AddReputation(player, reward.amount)
	else
		EconomyService:AddCoins(player, reward.amount)
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		Fx.coinBurst(hrp.Position + Vector3.new(0, 3, 0), 10)
		Fx.floatText(
			hrp.Position + Vector3.new(0, 5, 0),
			"🎁 +" .. tostring(reward.amount) .. " " .. reward.label,
			Color3.fromRGB(255, 220, 120)
		)
	end

	Remotes.event("SessionReward"):FireClient(player, {
		kind = "granted",
		reason = reason,
		reward = { kind = reward.kind, amount = reward.amount, label = reward.label },
	})
	if AnalyticsService then
		AnalyticsService:Track(player, "session_reward", {
			reason = reason,
			kind = reward.kind,
			amount = reward.amount,
		})
	end
end

-- One player's session: the connect gift, then a gift per interval of connected
-- play, re-broadcasting the countdown target every few seconds so a late-loading
-- client still shows the pill quickly (and any client clock drift self-corrects).
local function runSession(player: Player)
	local userId = player.UserId
	for _ = 1, 150 do
		if not active[userId] then
			return
		end
		if DataService:IsLoaded(player) then
			break
		end
		task.wait(0.2)
	end
	if not active[userId] or not DataService:IsLoaded(player) then
		return
	end

	grant(player, "connect")

	while active[userId] do
		local nextAt = workspace:GetServerTimeNow() + Config.intervalSeconds
		while active[userId] and workspace:GetServerTimeNow() < nextAt do
			sendTimer(player, nextAt)
			task.wait(Config.broadcastSeconds)
		end
		if not active[userId] then
			return
		end
		if DataService:IsLoaded(player) then
			grant(player, "playtime")
		end
	end
end

local function onJoin(player: Player)
	active[player.UserId] = true
	task.spawn(runSession, player)
end

function SessionRewardService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function SessionRewardService.Start(_self: any)
	if not Config.enabled then
		Log.info("SessionRewardService disabled (Config/SessionRewards.enabled = false)")
		return
	end
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(player)
		active[player.UserId] = nil
	end)
	Log.info("SessionRewardService ready (connect + playtime gifts)")
end

return SessionRewardService
