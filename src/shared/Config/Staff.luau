--!strict
-- Staff is a Week-3 system. This seed data exists so the architecture is complete
-- and StaffService has something to read when we build automation.

export type StaffDefinition = {
	id: string,
	displayName: string,
	role: string,
	baseSpeed: number,
	baseSalary: number,
}

local Staff: { [string]: StaffDefinition } = {
	barista_mia = {
		id = "barista_mia",
		displayName = "Mia",
		role = "Barista",
		baseSpeed = 1,
		baseSalary = 20,
	},
	cook_sam = {
		id = "cook_sam",
		displayName = "Sam",
		role = "Cook",
		baseSpeed = 1,
		baseSalary = 22,
	},
	waiter_noah = {
		id = "waiter_noah",
		displayName = "Noah",
		role = "Waiter",
		baseSpeed = 1,
		baseSalary = 18,
	},
	cleaner_pia = {
		id = "cleaner_pia",
		displayName = "Pia",
		role = "Cleaner",
		baseSpeed = 1,
		baseSalary = 16,
	},
}

return Staff
