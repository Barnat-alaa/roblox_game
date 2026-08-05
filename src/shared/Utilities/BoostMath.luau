--!strict
-- Timed boosts (economy fix #11, docs/ECONOMY_ANALYSIS.md §5.5).
--
-- `data.boosts` maps a boost key to its `os.time()` EXPIRY. Coins and reputation
-- read their own key inline in EconomyService because "is it running right now"
-- is the whole question there. The WORK boost (Double Shift) needs more than
-- that: the offline settlement pays for a span of hours at once, so a one-hour
-- boost that overlapped an eight-hour absence must be paid for one hour, not
-- eight. That pro-rating is the only real logic here, and it lives in a pure
-- module so tests/Boosts.spec.luau can exercise it without a DataModel.

local Products = require(script.Parent.Parent.Config.Products)

local BoostMath = {}

-- How many seconds of the window [windowStart, windowStart + windowSeconds] a
-- boost expiring at `expiry` still covers. Never negative, never longer than the
-- window itself.
function BoostMath.activeSeconds(
	expiry: number?,
	windowStart: number,
	windowSeconds: number
): number
	if windowSeconds <= 0 then
		return 0
	end
	local ends = math.min(tonumber(expiry) or 0, windowStart + windowSeconds)
	-- min is 0 and max is > 0 by the guard above, so this clamp can never be
	-- called with max < min (which errors — HANDOFF testing note).
	return math.clamp(ends - windowStart, 0, windowSeconds)
end

local function workExpiry(data: any): number?
	local boosts = if typeof(data) == "table" then (data :: any).boosts else nil
	if typeof(boosts) ~= "table" then
		return nil
	end
	return tonumber(boosts.work)
end

-- Multiplier on a producer role's hourly output right now: 2 while a Double
-- Shift is running, 1 otherwise. Applied ONLINE to both the work-minute budget
-- and the per-recipe hourly quota, because the plan is sized to spend the budget
-- exactly — doubling the budget alone would produce nothing extra, since every
-- recipe would still stop at its planned quota for the hour.
function BoostMath.workMultiplier(data: any, now: number): number
	if (workExpiry(data) or 0) > now then
		return Products.workBoostMultiplier
	end
	return 1
end

-- Offline settlement: the number of hours a role's work-minute budget should be
-- paid for across `earningSeconds` starting at `windowStart`, with any Double
-- Shift that overlapped counted only for the part of the window it covered.
function BoostMath.offlineWorkHours(data: any, windowStart: number, earningSeconds: number): number
	if earningSeconds <= 0 then
		return 0
	end
	local boosted = BoostMath.activeSeconds(workExpiry(data), windowStart, earningSeconds)
	local extra = boosted * (Products.workBoostMultiplier - 1)
	return (earningSeconds + extra) / 3600
end

return BoostMath
