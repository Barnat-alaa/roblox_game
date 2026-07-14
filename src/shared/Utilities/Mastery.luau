--!strict
-- Pure recipe-mastery math (Phase 3). Cook a dish repeatedly to earn stars;
-- each star makes it a little faster, cheaper, or richer. Pure functions so
-- tests/Mastery.spec.luau can pin the curve.

local Mastery = {}

-- Stars earned for a lifetime cook count, given the recipe's thresholds
-- (e.g. {5, 15, 40, 100} → 4 possible stars).
function Mastery.levelFor(thresholds: { number }, timesCooked: number): number
	local level = 0
	for _, t in thresholds do
		if timesCooked >= t then
			level += 1
		end
	end
	return level
end

function Mastery.cookTime(base: number, level: number, reductionPerStar: number): number
	return math.max(5, math.floor(base * (1 - reductionPerStar * level)))
end

function Mastery.batchCost(base: number, level: number, reductionPerStar: number): number
	return math.max(1, math.floor(base * (1 - reductionPerStar * level)))
end

function Mastery.servings(base: number, level: number, bonusAt: number): number
	return base + (if level >= bonusAt then 1 else 0)
end

function Mastery.freshMult(level: number, boostAt: number, mult: number): number
	return if level >= boostAt then mult else 1
end

return Mastery
