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

-- EVERY label on the plaza board (CafeService builds it as
-- workspace.Plaza.NeighbourhoodBoard.<gui>.LeaderboardText). The board is
-- double-sided since 2026-08-01, so there is one label per face and both are
-- rewritten together — a blank back would defeat the point of turning it to face
-- along the street.
local function boardLabels(): { TextLabel }
	local labels: { TextLabel } = {}
	local plaza = workspace:FindFirstChild("Plaza")
	local board = plaza and plaza:FindFirstChild("NeighbourhoodBoard")
	if not board then
		return labels
	end
	for _, gui in board:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local label = gui:FindFirstChild("LeaderboardText")
			if label and label:IsA("TextLabel") then
				table.insert(labels, label)
			end
		end
	end
	return labels
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

	local medals = { "1st", "2nd", "3rd" }
	local lines = { "CAFÉ LEADERBOARD — by Buzz" }
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
			local labels = boardLabels()
			if #labels > 0 then
				local ok, text = pcall(ranking)
				if ok then
					for _, label in labels do
						label.Text = text
					end
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
	Log.info("LeaderboardService ready (plaza Buzz leaderboard)")
end

return LeaderboardService
