--!strict
-- Sliding-window rate limiter. `now` is passed in (not read from os.clock inside)
-- so callers control the clock and the logic stays testable.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: { max: number, window: number, hits: { [any]: { number } } },
	RateLimiter
))

function RateLimiter.new(max: number, window: number): RateLimiter
	return setmetatable({ max = max, window = window, hits = {} }, RateLimiter)
end

-- Returns true if this hit is allowed, false if the key is over its budget.
function RateLimiter.check(self: RateLimiter, key: any, now: number): boolean
	local bucket = self.hits[key]
	if not bucket then
		bucket = {}
		self.hits[key] = bucket
	end

	local cutoff = now - self.window
	local kept = {}
	for _, t in bucket do
		if t > cutoff then
			table.insert(kept, t)
		end
	end
	self.hits[key] = kept

	if #kept >= self.max then
		return false
	end
	table.insert(kept, now)
	return true
end

function RateLimiter.clear(self: RateLimiter, key: any)
	self.hits[key] = nil
end

return RateLimiter
