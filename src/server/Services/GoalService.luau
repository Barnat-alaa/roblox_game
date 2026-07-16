--!strict
-- Daily goals + streak trophies (Phase 3b). Three goals roll each UTC day;
-- sibling services report progress through GoalService:Bump. Completing a
-- goal pays instantly; completing all three advances the streak, and streak
-- milestones mint PERMANENT trophies rendered on a shelf in your café.
-- Missing a day restarts the counter only — the shelf never empties (§35).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Goals = require(Shared.Config.Goals)
local Types = require(Shared.Types)
local Remotes = require(Shared.Network.Remotes)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)

local GoalService = {}
GoalService.Name = "GoalService"

local DataService: any
local EconomyService: any
local CafeService: any
local AnalyticsService: any

local rng = Random.new()
-- Guard so goal-reward coins don't recursively feed the earn_coins goal.
local granting: { [number]: boolean } = {}

local function todayKey(): string
	return os.date("!%Y-%m-%d") :: string
end

local function yesterdayKey(): string
	return os.date("!%Y-%m-%d", os.time() - 86400) :: string
end

local function dailyOf(data: Types.PlayerData): Types.DailyState
	if typeof(data.daily) ~= "table" then
		(data :: any).daily = { dateKey = "", goals = {}, streak = 0 }
	end
	if typeof(data.daily.goals) ~= "table" then
		data.daily.goals = {}
	end
	if typeof(data.trophies) ~= "table" then
		(data :: any).trophies = {}
	end
	return data.daily
end

-- Roll three distinct goals for a new day.
local function rollGoals(daily: Types.DailyState)
	daily.dateKey = todayKey()
	daily.goals = {}
	local pool = table.clone(Goals.pool)
	for _ = 1, math.min(3, #pool) do
		local pick = table.remove(pool, rng:NextInteger(1, #pool))
		if pick then
			table.insert(daily.goals, {
				id = pick.id,
				text = string.format(pick.text, pick.target),
				target = pick.target,
				progress = 0,
				done = false,
			})
		end
	end
end

-- ————— trophy shelf: streak milestones rendered in the café —————

local TROPHY_COLORS = {
	Color3.fromRGB(196, 124, 84), -- bronze (3 days)
	Color3.fromRGB(200, 205, 212), -- silver (7)
	Color3.fromRGB(240, 195, 80), -- gold (14)
	Color3.fromRGB(170, 220, 235), -- diamond (30)
}

local function renderShelf(player: Player)
	local data = DataService:GetProfile(player)
	local folder = CafeService:GetFurnitureFolder(player)
	local origin = CafeService:GetPlotOrigin(player)
	local plotModel = folder and folder.Parent
	if not data or not plotModel or not origin then
		return
	end

	local old = plotModel:FindFirstChild("TrophyShelf")
	if old then
		old:Destroy()
	end

	local shelf = Instance.new("Model")
	shelf.Name = "TrophyShelf"

	local board = Instance.new("Part")
	board.Name = "ShelfBoard"
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(7, 0.4, 1.4)
	board.Color = Color3.fromRGB(120, 90, 70)
	board.Material = Enum.Material.Wood
	-- On the LEFT wall near the entrance: the front of the room never moves
	-- when the interior expands (the back wall does — S2 tier system).
	board.CFrame = origin * CFrame.new(1.35, 5.4, 9) * CFrame.Angles(0, math.rad(90), 0)
	board.Parent = shelf

	local slot = 0
	for i, milestone in Goals.trophyMilestones do
		if data.trophies[tostring(milestone)] == true then
			slot += 1
			local cup = Instance.new("Part")
			cup.Name = "Trophy_" .. milestone
			cup.Anchored = true
			cup.CanCollide = false
			cup.Shape = Enum.PartType.Cylinder
			cup.Size = Vector3.new(0.9, 0.8, 0.8)
			cup.Color = TROPHY_COLORS[i] or TROPHY_COLORS[#TROPHY_COLORS]
			cup.Material = Enum.Material.Metal
			cup.CFrame = board.CFrame
				* CFrame.new(-2.8 + (slot - 1) * 1.7, 0.7, 0)
				* CFrame.Angles(0, 0, math.rad(90))
			cup.Parent = shelf
		end
	end
	shelf.Parent = plotModel
end

-- Make sure today's goals exist (rolls on the first touch of a new day).
local function ensureDaily(player: Player): Types.DailyState?
	local data = DataService:GetProfile(player)
	if not data then
		return nil
	end
	local daily = dailyOf(data)
	if daily.dateKey ~= todayKey() then
		rollGoals(daily)
		DataService:Push(player)
	end
	return daily
end

-- Report progress toward a goal id. Safe to call for ids not rolled today.
function GoalService.Bump(_self: any, player: Player, goalId: string, amount: number)
	if granting[player.UserId] then
		return
	end
	local data = DataService:GetProfile(player)
	local daily = ensureDaily(player)
	if not data or not daily then
		return
	end

	local changed = false
	for index, goal in daily.goals do
		if goal.id == goalId and not goal.done then
			goal.progress = math.min(goal.target, goal.progress + amount)
			changed = true
			if goal.progress >= goal.target then
				goal.done = true
				local reward = Goals.rewardCoins[index] or 30
				granting[player.UserId] = true
				EconomyService:AddCoins(player, reward)
				granting[player.UserId] = nil
				Remotes.event("Notify"):FireClient(player, {
					kind = "goal_done",
					text = goal.text,
					reward = reward,
				})
				if AnalyticsService then
					AnalyticsService:Track(player, "daily_goal_completed", { goal = goalId })
				end

				-- All three done → streak day.
				local allDone = true
				for _, g in daily.goals do
					if not g.done then
						allDone = false
					end
				end
				if allDone and daily.lastAllDoneDate ~= daily.dateKey then
					daily.streak = if daily.lastAllDoneDate == yesterdayKey()
						then daily.streak + 1
						else 1
					daily.lastAllDoneDate = daily.dateKey
					granting[player.UserId] = true
					EconomyService:AddCoins(player, Goals.allDoneBonus)
					granting[player.UserId] = nil
					Remotes.event("Notify"):FireClient(player, {
						kind = "streak_day",
						streak = daily.streak,
						bonus = Goals.allDoneBonus,
					})

					-- Permanent trophies at milestones.
					for _, milestone in Goals.trophyMilestones do
						if
							daily.streak >= milestone
							and data.trophies[tostring(milestone)] ~= true
						then
							data.trophies[tostring(milestone)] = true
							granting[player.UserId] = true
							EconomyService:AddCoins(player, Goals.trophyBonusCoins)
							granting[player.UserId] = nil
							Remotes.event("Notify"):FireClient(player, {
								kind = "trophy_earned",
								days = milestone,
								bonus = Goals.trophyBonusCoins,
							})
							renderShelf(player)
							local char = player.Character
							local hrp = char and char:FindFirstChild("HumanoidRootPart")
							if hrp and hrp:IsA("BasePart") then
								Fx.coinBurst(hrp.Position + Vector3.new(0, 4, 0), 10)
							end
							if AnalyticsService then
								AnalyticsService:Track(
									player,
									"trophy_earned",
									{ days = milestone }
								)
							end
						end
					end
				end
			end
		end
	end
	if changed then
		DataService:Push(player)
	end
end

function GoalService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	CafeService = ServiceRegistry.get("CafeService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function GoalService.Start(_self: any)
	local function onJoin(player: Player)
		task.spawn(function()
			for _ = 1, 100 do
				if DataService:IsLoaded(player) then
					ensureDaily(player)
					renderShelf(player)
					return
				end
				task.wait(0.2)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerAdded:Connect(onJoin)

	-- Midnight rollover for players who stay online across the day boundary.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) then
					ensureDaily(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		granting[player.UserId] = nil
	end)
end

return GoalService
