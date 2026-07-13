--!strict
-- Central type definitions for Social Café City.
-- This is a types-only module: it requires nothing and returns an empty table,
-- so it is safe to require from anywhere (server, client, shared) with no side effects.

export type GridCell = { x: number, y: number }

export type PlacedFurniture = {
	instanceId: string,
	catalogId: string,
	gridX: number,
	gridY: number,
	floor: number,
	rotation: number, -- 0..3 (multiples of 90 degrees)
	variant: string?,
}

export type RecipeMasteryEntry = {
	timesCooked: number,
	masteryLevel: number,
}

export type StaffMember = {
	id: string,
	typeId: string,
	level: number,
	experience: number,
}

export type PlayerSettings = {
	musicVolume: number,
	sfxVolume: number,
	reducedEffects: boolean,
}

export type PlayerStats = {
	customersServed: number,
	totalCoinsEarned: number,
	recipesCooked: number,
	tutorialCompleted: boolean,
}

-- The full persisted player document. Bump `schemaVersion` and add a migration
-- (see DataService.migrate) whenever this shape changes.
export type PlayerData = {
	schemaVersion: number,
	coins: number,
	level: number,
	experience: number,
	reputation: number,
	cafeStars: number,
	inventory: { [string]: number },
	placedFurniture: { PlacedFurniture },
	unlockedRecipes: { [string]: boolean },
	recipeMastery: { [string]: RecipeMasteryEntry },
	staff: { StaffMember },
	settings: PlayerSettings,
	stats: PlayerStats,
}

export type RecipeDefinition = {
	id: string,
	displayName: string,
	category: string,
	ingredientCost: number,
	basePrice: number,
	preparationTime: number,
	applianceId: string,
	requiredLevel: number,
	requiredReputation: number,
	baseQuality: number,
	masteryThresholds: { number },
}

export type FurnitureDefinition = {
	id: string,
	displayName: string,
	category: string,
	price: number,
	requiredLevel: number,
	width: number, -- footprint cells along the plot's local X
	depth: number, -- footprint cells along the plot's local Z
	rotatable: boolean,
	blocksWalk: boolean,
	seatCount: number,
	color: Color3,
	height: number, -- studs, used for the greybox render part
}

export type CustomerDefinition = {
	id: string,
	displayName: string,
	patiencePenaltyPerSecond: number,
	tipMultiplier: number,
	color: Color3,
}

export type OrderStatus = "pending" | "cooking" | "ready" | "served" | "expired"

export type Order = {
	orderId: string,
	ownerUserId: number,
	recipeId: string,
	customerId: string,
	status: OrderStatus,
	createdAtClock: number,
	claimed: boolean,
}

-- Generic result envelope for server request handlers.
export type Result<T> = {
	ok: boolean,
	value: T?,
	reason: string?,
}

return {}
