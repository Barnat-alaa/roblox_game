--!strict
-- Tuning for the permanent ambient crowd on the boulevard. These NPCs are pure
-- set dressing: they never order, never touch satisfaction/Buzz, and never
-- count as customers. They exist so the street reads as a living neighbourhood
-- instead of an empty film set.

local Pedestrians = {
	-- Total ambient walkers, split evenly across the two sidewalks. Each one is
	-- a lightweight loop, but they are permanent, so keep this modest.
	count = 16,

	walkSpeed = 8.5,

	-- How far along the sidewalk a pedestrian commits to walking before it
	-- re-decides (turn around, pause, or duck into a café).
	legStudsMin = 45,
	legStudsMax = 170,

	-- Idle beats: standing still for a moment reads far more natural than a
	-- crowd of NPCs all permanently in motion.
	pauseChance = 0.2,
	pauseSecondsMin = 1.5,
	pauseSecondsMax = 4.5,

	-- Chance, after finishing a leg, that this pedestrian looks for an OPEN café
	-- on its own side of the street and goes in.
	visitChance = 0.22,
	-- Only consider cafés roughly this near along X, so they don't march the
	-- whole boulevard to reach one.
	visitSearchStuds = 320,
	-- Keep a café from filling up with ambient bodies (real customers need the
	-- room, and the door tick gets noisy).
	maxVisitorsPerCafe = 3,
	lingerSecondsMin = 9,
	lingerSecondsMax = 22,
	-- How far past the door NPCs step before they mill about inside.
	insideDepthStuds = 12,

	-- Per-leg walk deadline before we give up and re-plan. Generous: a pedestrian
	-- that stalls is invisible, one that teleports is not.
	legTimeoutSeconds = 14,
	-- Stagger spawns so the crowd doesn't appear in one frame.
	spawnStaggerSeconds = 0.55,
}

return Pedestrians
