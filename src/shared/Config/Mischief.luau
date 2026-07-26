--!strict
-- Phase C-4b mischief tuning (docs/GAMEPLAY_DIRECTION.md §4b / IMPLEMENTATION_MAP
-- "Feature 4 / 4b"). The ONE rails-BRUSHING mechanic — owner-approved, but ONLY
-- with the FULL guardrails below (docs/SESSION_HANDOFF.md §4). Two ways to pull a
-- waiting customer from a neighbour to your café, both server-authoritative and
-- routed through MischiefService which enforces every guardrail here:
--   • Smell Bomb — a bought consumable; GUARANTEED if an eligible customer exists;
--     big green vapour telegraph.
--   • Recruit — free; success scales with your REPUTATION; smaller telegraph.
--
-- MANDATORY guardrails (all enforced, none optional — this is a griefing vector):
--   • bought/earned consumable (smell bomb) + a per-caster COOLDOWN
--   • a VISIBLE telegraph (the green vapour everyone sees)
--   • ONE-AT-A-TIME, and only NOT-YET-SERVED, NON-VIP, un-seated customers
--   • per-customer IMMUNITY after a pull + a per-victim MAX-STOLEN cap per window
--   • VIP RESISTANCE (VIPs are never lured)
--   • NO PERMANENT LOSS — the victim just misses one walk-in (capped); no Buzz /
--     coin / satisfaction penalty, and the customer re-appears at the caster's café
--   • server-authoritative; ships behind `enabled`.
local Mischief = {
	enabled = true,

	-- Smell bomb consumable (bought with coins — every SKU is coin-earnable, rails).
	bombCost = 150, -- coins per smell bomb
	startingBombs = 2, -- new players get a couple to try the mechanic

	-- Fairness spacing.
	cooldownSeconds = 45, -- per-caster gap between mischief attempts (either kind)
	proximityRadius = 55, -- must be within this of the target café (matches visits/help)
	vapourSeconds = 5, -- green vapour telegraph duration

	-- Victim protection: a café loses at most `maxStolenPerWindow` customers per
	-- `windowSeconds`, and every lured/recruited customer is immune for
	-- `immunitySeconds` so they can't be ping-ponged.
	maxStolenPerWindow = 3,
	windowSeconds = 300,
	immunitySeconds = 150,

	-- Recruit (free) success = clamp(base + reputation * repScale, min, max). The
	-- smell bomb always succeeds when an eligible customer exists (that's what the
	-- consumable buys); VIPs resist both by never being eligible.
	recruitBaseChance = 0.25,
	recruitRepScale = 0.0015, -- +0.15 per 100 reputation
	recruitMinChance = 0.15,
	recruitMaxChance = 0.8,
}

return Mischief
