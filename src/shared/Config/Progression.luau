--!strict
-- Player level & café star thresholds, plus the pure functions that read them.
-- These functions are covered by tests/Progression.spec.luau.

local Progression = {}

-- Total XP required to REACH each level. Index == level. Level 1 needs 0 XP.
Progression.xpForLevel = { 0, 60, 150, 300, 520, 820, 1220, 1750, 2400, 3200 }
Progression.maxLevel = #Progression.xpForLevel

-- Total reputation required for each café star (index == star count, 1..5).
Progression.reputationForStar = { 50, 200, 600, 1500, 4000 }

function Progression.levelForXp(totalXp: number): number
	local level = 1
	for lvl = 1, #Progression.xpForLevel do
		if totalXp >= Progression.xpForLevel[lvl] then
			level = lvl
		else
			break
		end
	end
	return level
end

function Progression.starsForReputation(reputation: number): number
	local stars = 0
	for star = 1, #Progression.reputationForStar do
		if reputation >= Progression.reputationForStar[star] then
			stars = star
		else
			break
		end
	end
	return stars
end

return Progression
