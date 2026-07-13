--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Config.Progression)

local ProgressionService = {}
ProgressionService.Name = "ProgressionService"

function ProgressionService.LevelFor(_self: any, xp: number): number
	return Progression.levelForXp(xp)
end

function ProgressionService.StarsFor(_self: any, reputation: number): number
	return Progression.starsForReputation(reputation)
end

return ProgressionService
