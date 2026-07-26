--!strict
-- Lobby Buzz leaderboard on the plaza board (owner request 2026-07-26). Ranks
-- every OPEN café on the server by its Buzz ("boost") so players can see who is
-- #1 — the café the VIP walks to (VipService picks the highest-Buzz café). This
-- is a read-only DISPLAY: it never changes gameplay, so it stays rails-clean.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Log = require(Shared.Utilities.Log)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local LeaderboardService = {}
LeaderboardService.Name = "LeaderboardService"

local CafeService: any
local KitchenService: any

local REFRESH_SECONDS = 5
local MAX_ROWS = 10 -- one per plot; the street holds World.plotCount

-- The plaza board's label (CafeService builds it as workspace.Plaza.<board>.<gui>).
local function boardLabel(): TextLabel?
	local plaza = workspace:FindFirstChild("Plaza")
	local board = plaza and plaza:FindFirstChild("NeighbourhoodBoard")
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("LeaderboardText")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function ranking(): string
	local rows: { { name: string, buzz: number } } = {}
	for index = 1, World.plotCount do
		local _, ownerUserId = CafeService:GetPlotInfo(index)
		if ownerUserId then
			local owner = Players:GetPlayerByUserId(ownerUserId)
			if owner then
				rows[#rows + 1] = {
					name = owner.DisplayName,
					buzz = math.floor(KitchenService:GetBuzz(owner) or 0),
				}
			end
		end
	end
	if #rows == 0 then
		return "🏆 CAFÉ LEADERBOARD\n\nNo cafés open yet — claim a plot!"
	end
	table.sort(rows, function(a, b)
		return a.buzz > b.buzz
	end)

	local medals = { "🥇", "🥈", "🥉" }
	local lines = { "🏆 CAFÉ LEADERBOARD — by Buzz" }
	for i, r in rows do
		if i > MAX_ROWS then
			break
		end
		lines[#lines + 1] =
			string.format("%s  %s — Buzz %d", medals[i] or ("#" .. i), r.name, r.buzz)
	end
	return table.concat(lines, "\n")
end

function LeaderboardService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	KitchenService = ServiceRegistry.get("KitchenService")
end

function LeaderboardService.Start(_self: any)
	task.spawn(function()
		while true do
			local label = boardLabel()
			if label then
				local ok, text = pcall(ranking)
				if ok then
					label.Text = text
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
	Log.info("LeaderboardService ready (plaza Buzz leaderboard)")
end

return LeaderboardService
