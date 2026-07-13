--!strict
-- Analytics sink. For now it logs structured events to Output; wiring these into
-- Roblox AnalyticsService (LogCustomEvent / funnel steps) is a Day-6 task. The
-- TrackOnce helper backs the "first_*" funnel events in docs/ANALYTICS_EVENTS.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Log = require(ReplicatedStorage.Shared.Utilities.Log)

local AnalyticsService = {}
AnalyticsService.Name = "AnalyticsService"

local firedOnce: { [number]: { [string]: boolean } } = {}

function AnalyticsService.Track(
	_self: any,
	player: Player,
	eventName: string,
	params: { [string]: any }?
)
	local encoded = if params then HttpService:JSONEncode(params) else "{}"
	Log.info("[analytics]", player.Name, eventName, encoded)
	-- TODO(Day 6): AnalyticsService:LogCustomEvent(player, eventName, value) + funnels.
end

function AnalyticsService.TrackOnce(
	self: any,
	player: Player,
	eventName: string,
	params: { [string]: any }?
)
	local set = firedOnce[player.UserId]
	if not set then
		set = {}
		firedOnce[player.UserId] = set
	end
	if set[eventName] then
		return
	end
	set[eventName] = true
	AnalyticsService.Track(self, player, eventName, params)
end

function AnalyticsService.Start(_self: any)
	Players.PlayerRemoving:Connect(function(player)
		firedOnce[player.UserId] = nil
	end)
end

return AnalyticsService
