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
	liftY: number?, -- extra studs above the floor (e.g. an appliance ON a counter)
}

export type RecipeMasteryEntry = {
	timesCooked: number,
	masteryLevel: number,
}

-- A returning customer this café has served before (S2 feelings pass).
export type RegularEntry = {
	favourite: string, -- recipeId they'll ask for on return visits
	visits: number,
}

export type StaffMember = {
	id: string,
	typeId: string,
	level: number,
	experience: number,
	hired: boolean, -- false = a locked role shown in the hire UI but not working yet
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
	tutorialStep: number, -- index of the last completed onboarding step (0 = none)
}

-- One in-progress stove batch. startedAt is os.time() (wall clock) so
-- overnight cooking survives leaving the game — the appointment mechanic.
export type ActiveCook = {
	recipeId: string,
	startedAt: number,
	duration: number?, -- effective cook seconds (mastery applied at start)
}

export type StockLot = {
	lotId: string,
	quantity: number,
	reserved: number,
	producedAt: number,
	expiresAt: number,
}

export type StockAllocation = {
	lotId: string,
	quantity: number,
}

export type StockReservation = {
	reservationId: string,
	recipeId: string,
	allocations: { StockAllocation },
	createdAt: number,
	expiresAt: number,
}

export type ProductionJob = {
	jobId: string,
	recipeId: string,
	applianceInstanceId: string,
	startedAt: number,
	completesAt: number,
	duration: number,
	yield: number,
	staffRole: string,
}

export type KitchenStats = {
	produced: number,
	served: number,
	spoiled: number,
}

export type KitchenState = {
	cooks: { [string]: ActiveCook }, -- keyed by appliance instanceId
	stock: { [string]: number }, -- derived available servings per recipeId (UI compatibility)
	lots: { [string]: { StockLot } }, -- FIFO perishable lots keyed by recipeId
	reservations: { [string]: StockReservation },
	jobs: { [string]: ProductionJob }, -- continuous jobs keyed by appliance instanceId
	menu: { [string]: boolean },
	targetStock: { [string]: number },
	priorities: { [string]: number },
	stats: KitchenStats,
	lastActiveAt: number,
	nextLotId: number,
	nextReservationId: number,
	nextJobId: number,
}

export type OfflineSummary = {
	seconds: number,
	earnings: number,
	satisfactionLost: number,
	at: number,
}

export type OperationsState = {
	satisfaction: number,
	cleanliness: number,
	staffCapacity: { [string]: number },
	lastSeenAt: number,
	lastDirtAt: number,
	lastOffline: OfflineSummary?,
}

export type GoalState = {
	id: string,
	text: string,
	target: number,
	progress: number,
	done: boolean,
}

-- Rotating daily goals + the streak counter. Missing a day restarts the
-- streak COUNTER but earned trophies are permanent (§35: the shelf waits).
export type DailyState = {
	dateKey: string, -- UTC yyyy-mm-dd these goals belong to
	goals: { GoalState },
	streak: number,
	lastAllDoneDate: string?,
}

-- The full persisted player document. Bump `schemaVersion` and add a migration
-- (see DataService.migrate) whenever this shape changes.
-- Painted floor tiles and wall panels (B3). Keys are compact strings so a fully
-- tiled café is a flat map rather than a nested grid:
--   floor["<gridX>,<gridY>"] = "<colourId>:<motifId>"
--   wall["<wallId>:<index>"] = "<colourId>:<motifId>"   (wallId = left|right|back)
export type SurfaceState = {
	floor: { [string]: string },
	wall: { [string]: string },
}

export type SocialState = {
	friendship: { [string]: number }, -- other userId (string) → accumulated friendship points
	-- other userId → { day = floor(os.time()/86400), count = paid helps done that day }.
	-- P2c replaced the old { [actionId] = day } shape; SocialService.TryWork heals
	-- an old row by simply not finding `day`, which reads as "a new day".
	helpLog: { [string]: { day: number, count: number } },
	lastGoodNeighbourDay: number, -- floor(os.time()/86400) of the last "Good Neighbour" bonus
}

export type PlayerData = {
	schemaVersion: number,
	coins: number,
	level: number,
	experience: number,
	reputation: number,
	cafeStars: number,
	buzz: number, -- 0..105 café hype: fed customers raise it, walkouts drop it
	cafeName: string?, -- player-chosen café name (filtered); nil → "<DisplayName>'s Café"
	expansionTier: number, -- 0-based index into World.interiorDepthTiers (buy land → deeper café)
	regulars: { [string]: RegularEntry }, -- name-keyed returning customers (max 8)
	inventory: { [string]: number },
	pantry: { [string]: number }, -- ingredient id → units on hand (see Config/Ingredients)
	grantedReceipts: { [string]: boolean }, -- Robux PurchaseId → granted (ProcessReceipt idempotency)
	boosts: { [string]: number }, -- boost key → os.time() expiry (2× coins/reputation)
	smellBombs: number, -- Phase C-4b mischief consumable count (top-level → reconcile heals)
	-- P4 permanent production-yield ladder: 0 = ×1, 1 = ×5, 2 = ×10, 3 = ×20.
	-- Buyable with coins OR Robux (rails: never power you can't earn).
	yieldTier: number,
	-- B3 painted floor tiles + wall panels (top-level → reconcile heals old saves).
	surfaces: SurfaceState,
	-- B4 exterior personalisation: one chosen id per axis (architecture, color,
	-- motif, doorStyle, doorWood, windowShape, glass). Config/Facade.resolve fills
	-- any missing or retired axis from the defaults, so this is safe to leave sparse.
	facade: { [string]: string },
	ownedPasses: { [string]: boolean }, -- pass key → owned (VIP, Auto-Collect), cached on join
	social: SocialState, -- neighbour friendships + per-day help anti-farm (Phase C §4a)
	placedFurniture: { PlacedFurniture },
	unlockedRecipes: { [string]: boolean },
	recipeMastery: { [string]: RecipeMasteryEntry },
	staff: { StaffMember },
	-- Auto-production plan: staff role → recipeId → how many to make per hour.
	-- The player allocates each staffer's work-minutes across their products.
	productionPlan: { [string]: { [string]: number } },
	kitchen: KitchenState,
	operations: OperationsState,
	daily: DailyState,
	trophies: { [string]: boolean }, -- permanent streak-milestone trophies
	settings: PlayerSettings,
	stats: PlayerStats,
}

export type RecipeDefinition = {
	id: string,
	displayName: string,
	category: string,
	ingredientCost: number,
	ingredients: { [string]: number }?, -- ingredient id → units PER SERVING (Config/Ingredients); nil = coins-only. slow_roast is per-batch (8h appointment)
	basePrice: number,
	preparationTime: number,
	applianceId: string,
	requiredLevel: number,
	requiredReputation: number,
	baseQuality: number,
	masteryThresholds: { number },
	cookTime: number, -- seconds on the stove (cook-ahead loop)
	servings: number, -- counter stock added per collected batch
	productionTime: number, -- seconds per automatic staff batch at level 1
	productionYield: number, -- servings created by one automatic batch
	productionMinutes: number?, -- work-minutes one batch costs a staffer (new plan model; nil = appointment recipe, outside the per-hour budget)
	spoilTime: number, -- shelf life in seconds while the cafe is online
	serveTime: number, -- waiter service cycle in seconds at level 1
	staffRole: string, -- Barista for drinks, Cook for food
	icon: string?, -- emoji shown in order/prep bubbles (assigned in Config/Recipes)
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
	cookable: boolean?, -- true = this appliance runs stove batches
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
	seatId: string?,
	tableLabel: string?,
}

-- Generic result envelope for server request handlers.
export type Result<T> = {
	ok: boolean,
	value: T?,
	reason: string?,
}

return {}
