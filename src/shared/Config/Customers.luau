--!strict
local Types = require(script.Parent.Parent.Types)

-- Three MVP customer variants: same behaviour, different look + tipping.
local Customers: { [string]: Types.CustomerDefinition } = {
	regular = {
		id = "regular",
		displayName = "Regular",
		patiencePenaltyPerSecond = 0.5,
		tipMultiplier = 1.0,
		color = Color3.fromRGB(120, 160, 200),
	},
	student = {
		id = "student",
		displayName = "Student",
		patiencePenaltyPerSecond = 0.8,
		tipMultiplier = 0.7,
		color = Color3.fromRGB(160, 200, 120),
	},
	tourist = {
		id = "tourist",
		displayName = "Tourist",
		patiencePenaltyPerSecond = 0.3,
		tipMultiplier = 1.5,
		color = Color3.fromRGB(225, 175, 120),
	},
}

return Customers
