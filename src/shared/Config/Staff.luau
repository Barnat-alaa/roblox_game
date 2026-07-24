--!strict
-- Staff roster (docs/GAMEPLAY_DIRECTION.md §1). The café opens with only a
-- Barista and a Waiter; the rest are hired for coins (or accelerated with Robux,
-- A8) and each staffer is upgraded level-by-level to raise their per-hour output.
-- Data-driven: adding a role is a new row here.

export type StaffDefinition = {
	id: string,
	displayName: string,
	role: string,
	baseSpeed: number,
	baseSalary: number,
	blurb: string, -- one line shown on the staff card
	hireCost: number, -- coins to hire (0 = starts on the crew)
	startsHired: boolean, -- seeded onto the crew for a brand-new café
	maxLevel: number, -- upgrade ceiling
}

local Staff: { [string]: StaffDefinition } = {
	barista_mia = {
		id = "barista_mia",
		displayName = "Mia",
		role = "Barista",
		baseSpeed = 1,
		baseSalary = 20,
		blurb = "Brews coffee & tea at the machine",
		hireCost = 0,
		startsHired = true,
		maxLevel = 10,
	},
	waiter_noah = {
		id = "waiter_noah",
		displayName = "Noah",
		role = "Waiter",
		baseSpeed = 1,
		baseSalary = 18,
		blurb = "Carries orders to the tables",
		hireCost = 0,
		startsHired = true,
		maxLevel = 10,
	},
	cook_sam = {
		id = "cook_sam",
		displayName = "Sam",
		role = "Cook",
		baseSpeed = 1,
		baseSalary = 22,
		blurb = "Bakes pastries & preps food",
		hireCost = 600,
		startsHired = false,
		maxLevel = 10,
	},
	cleaner_pia = {
		id = "cleaner_pia",
		displayName = "Pia",
		role = "Cleaner",
		baseSpeed = 1,
		baseSalary = 16,
		blurb = "Clears dirt & dirty plates",
		hireCost = 400,
		startsHired = false,
		maxLevel = 10,
	},
}

return Staff
