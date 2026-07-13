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
		baseSpeed = 1.2,
		baseSalary = 20,
	},
	waiter_leo = {
		id = "waiter_leo",
		displayName = "Leo",
		role = "Waiter",
		baseSpeed = 0.9,
		baseSalary = 18,
	},
}

return Staff
