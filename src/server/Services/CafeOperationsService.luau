--!strict
-- Persistent active-shift pressure: satisfaction, visible dirt, finite staff
-- capacity, online recovery, and deliberately weak (20x) offline earnings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Utilities.Grid)
local Operations = require(Shared.Config.Operations)
local OperationsMath = require(Shared.Utilities.OperationsMath)
local IngredientMath = require(Shared.Utilities.IngredientMath)
local Recipes = require(Shared.Config.Recipes)
local StaffDefinitions = require(Shared.Config.Staff)
local Kitchen = require(Shared.Config.Kitchen)
local World = require(Shared.Config.World)
local Remotes = require(Shared.Network.Remotes)
local Log = require(Shared.Utilities.Log)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)

local CafeOperationsService = {}
CafeOperationsService.Name = "CafeOperationsService"

local DataService: any
local EconomyService: any
local CafeService: any
local StaffService: any
local AssetLibraryService: any

local resumed: { [number]: boolean } = {}
local dirtByUser: { [number]: { Model } } = {}
local lastRecoveryClock: { [number]: number } = {}
local rng = Random.new()

local function stateOf(data: Types.PlayerData): Types.OperationsState
	local state = (data :: any).operations
	if typeof(state) ~= "table" then
		state = {
			satisfaction = Operations.startingSatisfaction,
			cleanliness = Operations.startingCleanliness,
			staffCapacity = {},
			lastSeenAt = os.time(),
			lastDirtAt = os.time(),
			lastOffline = nil,
		}
		local mutableData: any = data
		mutableData.operations = state
	end
	if typeof(state.staffCapacity) ~= "table" then
		state.staffCapacity = {}
	end
	for _, role in { "Barista", "Cook", "Waiter", "Cleaner" } do
		state.staffCapacity[role] = math.clamp(
			tonumber(state.staffCapacity[role]) or Operations.startingStaffCapacity,
			0,
			Operations.staffCapacityMax
		)
	end
	state.satisfaction = math.clamp(
		tonumber(state.satisfaction) or Operations.startingSatisfaction,
		0,
		Operations.maxSatisfaction
	)
	state.cleanliness =
		math.clamp(tonumber(state.cleanliness) or Operations.startingCleanliness, 0, 100)
	state.lastSeenAt = tonumber(state.lastSeenAt) or os.time()
	state.lastDirtAt = tonumber(state.lastDirtAt) or os.time()
	return state
end

function CafeOperationsService.GetState(_self: any, data: Types.PlayerData): Types.OperationsState
	return stateOf(data)
end

function CafeOperationsService.GetCleanliness(_self: any, player: Player): number
	local data = DataService:GetProfile(player)
	return if data then stateOf(data).cleanliness else Operations.startingCleanliness
end

function CafeOperationsService.GetSatisfaction(_self: any, player: Player): number
	local data = DataService:GetProfile(player)
	return if data then stateOf(data).satisfaction else Operations.startingSatisfaction
end

function CafeOperationsService.AdjustSatisfaction(_self: any, player: Player, delta: number)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local state = stateOf(data)
	local before = state.satisfaction
	state.satisfaction = math.clamp(before + delta, 0, Operations.maxSatisfaction)
	if math.floor(before) ~= math.floor(state.satisfaction) then
		DataService:Push(player)
	end
end

function CafeOperationsService.CanUseCapacity(
	_self: any,
	player: Player,
	role: string,
	amount: number
): boolean
	local data = DataService:GetProfile(player)
	if not data then
		return false
	end
	return (stateOf(data).staffCapacity[role] or 0) + 0.001 >= math.max(0, amount)
end

function CafeOperationsService.TryUseCapacity(
	_self: any,
	player: Player,
	role: string,
	amount: number
): boolean
	local data = DataService:GetProfile(player)
	if not data then
		return false
	end
	local state = stateOf(data)
	local cost = math.max(0, amount)
	local available = state.staffCapacity[role] or 0
	if available + 0.001 < cost then
		return false
	end
	state.staffCapacity[role] = math.max(0, available - cost)
	DataService:Push(player)
	return true
end

function CafeOperationsService.RestoreFromManual(_self: any, player: Player, role: string)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local state = stateOf(data)
	state.staffCapacity[role] = math.min(
		Operations.staffCapacityMax,
		(state.staffCapacity[role] or 0) + Operations.manualCapacityRestore
	)
	DataService:Push(player)
end

function CafeOperationsService.OnServed(_self: any, player: Player, manual: boolean)
	CafeOperationsService:AdjustSatisfaction(
		player,
		if manual then Operations.satisfactionPerManualServe else Operations.satisfactionPerServe
	)
	if manual then
		CafeOperationsService:RestoreFromManual(player, "Waiter")
	end
end

local function removeDirtReference(userId: number, mess: Model)
	local list = dirtByUser[userId]
	local index = list and table.find(list, mess)
	if list and index then
		table.remove(list, index)
	end
end

function CafeOperationsService.CleanMess(
	_self: any,
	player: Player,
	mess: Model,
	manual: boolean
): boolean
	if mess.Parent == nil or mess:GetAttribute("CafeDirt") ~= true then
		return false
	end
	local ownerId = tonumber(mess:GetAttribute("OwnerUserId"))
	if ownerId ~= player.UserId then
		return false
	end
	local data = DataService:GetProfile(player)
	if not data then
		return false
	end
	removeDirtReference(player.UserId, mess)
	local state = stateOf(data)
	state.cleanliness = math.min(100, state.cleanliness + Operations.cleanlinessGainPerClean)
	if manual then
		state.satisfaction = math.min(
			Operations.maxSatisfaction,
			state.satisfaction + Operations.satisfactionPerClean
		)
		CafeOperationsService:RestoreFromManual(player, "Cleaner")
	end
	local position = mess:GetPivot().Position
	mess:Destroy()
	if manual then
		-- Show the broom scrubbing when the OWNER cleans, too.
		Fx.scrub(position, 1)
	end
	Fx.floatText(
		position + Vector3.new(0, 2.5, 0),
		if manual then "SPARKLING!  +SAT" else "CLEAN",
		Color3.fromRGB(115, 225, 185)
	)
	DataService:Push(player)
	return true
end

local function makeDirt(player: Player, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "VisibleDirt"
	model:SetAttribute("CafeDirt", true)
	model:SetAttribute("OwnerUserId", player.UserId)

	-- Prefer the real spill/dirt mesh (owner pick, 2026-07-19); fall back to a
	-- procedural brown splat + blobs. Either way the mesh IS the signal — no
	-- floating "clean me" label (owner request); the prompt shows on approach.
	local anchor: BasePart
	local dirtMesh: Model? = if AssetLibraryService
		then AssetLibraryService:GetDecor("dirt")
		else nil
	if dirtMesh then
		for _, d in dirtMesh:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		dirtMesh:PivotTo(CFrame.new(position + Vector3.new(0, 0.06, 0)))
		dirtMesh.Parent = model
		anchor = dirtMesh.PrimaryPart
			or dirtMesh:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		model.PrimaryPart = anchor
	else
		local splat = Instance.new("Part")
		splat.Name = "Splat"
		splat.Shape = Enum.PartType.Cylinder
		splat.Size = Vector3.new(0.12, 3.6, 3.6)
		splat.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		splat.Color = Color3.fromRGB(119, 70, 45)
		splat.Material = Enum.Material.SmoothPlastic
		splat.Anchored = true
		splat.CanCollide = false
		splat.CanQuery = false
		splat.CanTouch = false
		splat.Parent = model
		model.PrimaryPart = splat
		anchor = splat

		for index = 1, 4 do
			local blob = Instance.new("Part")
			blob.Name = "Blob"
			blob.Shape = Enum.PartType.Ball
			blob.Size = Vector3.new(0.16, 0.7, 0.7) * rng:NextNumber(0.7, 1.25)
			local angle = index * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
			blob.CFrame = CFrame.new(
				position
					+ Vector3.new(math.cos(angle), 0.1, math.sin(angle))
						* rng:NextNumber(1.3, 2.1)
			)
			blob.Color = splat.Color
			blob.Material = Enum.Material.SmoothPlastic
			blob.Anchored = true
			blob.CanCollide = false
			blob.CanQuery = false
			blob.CanTouch = false
			blob.Parent = model
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleanDirt"
	prompt.ActionText = "Scrub clean"
	prompt.ObjectText = "Dirty floor"
	prompt.HoldDuration = 0.65
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(who)
		if who == player then
			CafeOperationsService:CleanMess(player, model, true)
		end
	end)
	return model
end

local function spawnDirt(player: Player)
	local origin = CafeService:GetPlotOrigin(player)
	local folder = CafeService:GetFurnitureFolder(player)
	local data = DataService:GetProfile(player)
	if not origin or not folder or not data then
		return
	end
	local list = dirtByUser[player.UserId]
	if not list then
		list = {}
		dirtByUser[player.UserId] = list
	end
	for index = #list, 1, -1 do
		if list[index].Parent == nil then
			table.remove(list, index)
		end
	end
	if #list >= Operations.maxDirt then
		return
	end
	local depthCells = World.interiorDepthTiers[math.clamp(
		math.floor(tonumber(data.expansionTier) or 0) + 1,
		1,
		#World.interiorDepthTiers
	)]
	local width = Grid.PLOT_WIDTH * Grid.CELL_SIZE
	local kitchenWidth = World.kitchenWidthCells * Grid.CELL_SIZE
	local position = (origin * CFrame.new(
		rng:NextNumber(kitchenWidth + 5, width - 5),
		0,
		rng:NextNumber(
			World.kitchenDepthCells * Grid.CELL_SIZE + 5,
			depthCells * Grid.CELL_SIZE - 6
		)
	)).Position
	local mess = makeDirt(player, position)
	mess.Parent = folder.Parent
	table.insert(list, mess)
	local state = stateOf(data)
	state.cleanliness = math.max(0, state.cleanliness - Operations.cleanlinessLossPerDirt)
	state.lastDirtAt = os.time()
	DataService:Push(player)
	if StaffService then
		-- Give the owner a satisfying manual-clean window before Pia takes it.
		task.delay(12, function()
			if mess.Parent ~= nil then
				StaffService:NotifyMess(player, mess)
			end
		end)
	end
end

-- Plan-model offline earnings (CORE_LOOP_SPEC §4d): each producer role gets its
-- per-hour work-minutes × hours-away ÷ 20, split across the plan in proportion to
-- each recipe's share of the planned minutes, capped by pantry ingredients (which
-- it consumes). Returns coins earned; mutates data.pantry.
local function settlePlanOffline(data: Types.PlayerData, offlineSeconds: number): number
	local earningSeconds = math.min(offlineSeconds, Operations.maxOfflineEarningHours * 3600)
	local hours = earningSeconds / 3600
	local divisor = math.max(1, Operations.offlineTimeMultiplier)
	local total = 0
	local plan = (data :: any).productionPlan
	if typeof(plan) ~= "table" then
		return 0
	end
	for role, recipes in plan do
		if typeof(recipes) == "table" and StaffService:HasRole(data, role) then
			local budget = StaffService:GetWorkMinutesPerHour(data, role) * hours / divisor
			local totalWeight = 0
			for recipeId, count in recipes do
				local recipe = Recipes[recipeId]
				local minutes = recipe and tonumber(recipe.productionMinutes)
				if
					minutes
					and (tonumber(count) or 0) > 0
					and data.unlockedRecipes[recipeId] == true
				then
					totalWeight += (tonumber(count) or 0) * minutes
				end
			end
			if totalWeight > 0 then
				for recipeId, count in recipes do
					local recipe = Recipes[recipeId]
					local minutes = recipe and tonumber(recipe.productionMinutes)
					if
						minutes
						and (tonumber(count) or 0) > 0
						and data.unlockedRecipes[recipeId] == true
					then
						local weight = (tonumber(count) or 0) * minutes
						local servings = math.floor((budget * weight / totalWeight) / minutes)
						for _ = 1, servings do
							if IngredientMath.has(recipe, data.pantry) then
								IngredientMath.consume(recipe, data.pantry)
								total += math.max(
									1,
									math.floor(recipe.basePrice * Kitchen.servingPayoutFraction)
								)
							else
								break
							end
						end
					end
				end
			end
		end
	end
	return math.floor(total)
end

function CafeOperationsService.ResumeAfterOffline(_self: any, player: Player, now: number): any
	if resumed[player.UserId] then
		local data = DataService:GetProfile(player)
		return if data then stateOf(data).lastOffline else nil
	end
	local data = DataService:GetProfile(player)
	if not data then
		return nil
	end
	resumed[player.UserId] = true
	local state = stateOf(data)
	local offlineSeconds = math.max(0, now - state.lastSeenAt)
	local satisfactionLost = math.min(
		Operations.maxOfflineSatisfactionLoss,
		offlineSeconds / 3600 * Operations.offlineSatisfactionLossPerHour
	)
	state.satisfaction = math.max(0, state.satisfaction - satisfactionLost)

	-- Existing automatic jobs advance at 1/20 real speed while disconnected.
	local slowExtra = offlineSeconds
		* (Operations.offlineTimeMultiplier - 1)
		/ Operations.offlineTimeMultiplier
	for _, job in data.kitchen.jobs do
		job.completesAt += slowExtra
	end

	local earnings = 0
	if Kitchen.useProductionPlan then
		earnings = settlePlanOffline(data, offlineSeconds)
	else
		local rates = OperationsMath.calculate(
			data,
			Recipes,
			StaffDefinitions,
			Kitchen.staffLevelSpeedPerLevel,
			Kitchen.batchCostMultiplier,
			Kitchen.servingPayoutFraction,
			Operations.offlineEarningsDivisor
		)
		local earningSeconds = math.min(offlineSeconds, Operations.maxOfflineEarningHours * 3600)
		local effectiveMinutes = earningSeconds / 60 / Operations.offlineTimeMultiplier
		local requiredWaiter = effectiveMinutes
			* rates.waiterUtilization
			* Operations.serviceCapacityPerWorkMinute
		local waiterAvailable = state.staffCapacity.Waiter or 0
		local capacityScale = if requiredWaiter > 0
			then math.min(1, waiterAvailable / requiredWaiter)
			else 0
		earnings = math.max(0, math.floor(rates.netPerMinute * effectiveMinutes * capacityScale))
		if requiredWaiter > 0 then
			state.staffCapacity.Waiter =
				math.max(0, waiterAvailable - requiredWaiter * capacityScale)
		end
		local activeRoles: { [string]: boolean } = {}
		for recipeId, product in rates.products do
			if product.productionPerMinute > 0 then
				activeRoles[Recipes[recipeId].staffRole] = true
			end
		end
		for role in activeRoles do
			local cost = effectiveMinutes
				* Operations.productionCapacityPerWorkMinute
				* capacityScale
			state.staffCapacity[role] = math.max(0, (state.staffCapacity[role] or 0) - cost)
		end
	end
	if earnings > 0 then
		EconomyService:AddCoins(player, earnings)
	end
	state.lastSeenAt = now
	state.lastOffline = {
		seconds = offlineSeconds,
		earnings = earnings,
		satisfactionLost = satisfactionLost,
		at = now,
	}
	DataService:Push(player)
	if offlineSeconds >= 60 then
		Remotes.event("Notify"):FireClient(player, {
			kind = "offline_summary",
			earnings = earnings,
			seconds = offlineSeconds,
			satisfactionLost = math.floor(satisfactionLost),
			multiplier = Operations.offlineTimeMultiplier,
		})
	end
	return state.lastOffline
end

local function recoverOnline(player: Player, elapsed: number)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local state = stateOf(data)
	local changed = false
	for role, rate in Operations.onlineRecoveryPerMinute do
		local before = state.staffCapacity[role] or 0
		local after = math.min(Operations.staffCapacityMax, before + rate * elapsed / 60)
		state.staffCapacity[role] = after
		changed = changed or math.floor(before) ~= math.floor(after)
	end
	state.lastSeenAt = os.time()
	if state.cleanliness < Operations.dirtyPatienceThreshold then
		local before = state.satisfaction
		state.satisfaction = math.max(0, before - elapsed / 600)
		changed = changed or math.floor(before) ~= math.floor(state.satisfaction)
	end
	if changed then
		DataService:Push(player)
	end
end

function CafeOperationsService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	CafeService = ServiceRegistry.get("CafeService")
	StaffService = ServiceRegistry.get("StaffService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
end

function CafeOperationsService.Start(_self: any)
	-- This loop owns offline settlement, staff-capacity recovery, satisfaction
	-- decay, dirt spawning and lastSeenAt freshness. Unprotected, a single error
	-- from any one player's tick would kill the thread and silently disable all
	-- of that for EVERY player on the server for the rest of its life. Every
	-- comparable loop in the codebase is pcall'd (ProductionService, CafeService,
	-- KitchenService); this one was not.
	local function tickOperations(player: Player)
		if not DataService:IsLoaded(player) then
			return
		end
		CafeOperationsService:ResumeAfterOffline(player, os.time())
		local nowClock = os.clock()
		local elapsed = math.max(0, nowClock - (lastRecoveryClock[player.UserId] or nowClock))
		lastRecoveryClock[player.UserId] = nowClock
		recoverOnline(player, elapsed)
		local data = DataService:GetProfile(player)
		if data then
			local state = stateOf(data)
			local jitter = rng:NextInteger(0, 8)
			if os.time() - state.lastDirtAt >= Operations.dirtSpawnSeconds + jitter then
				spawnDirt(player)
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tickOperations, player)
				if not ok then
					Log.warn("Operations tick failed for", player.Name, err)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local list = dirtByUser[player.UserId]
		if list then
			for _, mess in list do
				if mess.Parent ~= nil then
					mess:Destroy()
				end
			end
		end
		dirtByUser[player.UserId] = nil
		lastRecoveryClock[player.UserId] = nil
		resumed[player.UserId] = nil
	end)
end

return CafeOperationsService
