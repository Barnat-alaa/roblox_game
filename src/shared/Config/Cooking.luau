--!strict
-- Shared constants for the manual-brew timing minigame. The client renders the
-- oscillating bar from these values and the server re-derives the indicator
-- position from its own clock, so both sides MUST read this module — never
-- hard-code these numbers on one side.
local Cooking = {
	barPeriod = 1.6, -- seconds for one full left→right→left sweep
	targetCenter = 0.5, -- centre of the success zone (0..1 along the bar)
	targetHalfWidth = 0.12, -- half-width of the success zone the client SHOWS
	serverTolerance = 0.06, -- extra slack the server accepts for network latency
	sessionTtl = 25, -- seconds before an unfinished brew session expires
}

return Cooking
