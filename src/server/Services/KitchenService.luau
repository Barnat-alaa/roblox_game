--!strict
-- Cook-ahead kitchens + Buzz (Phase 1 loop pivot). Players start batches on
-- their own appliances (StartCook), timers run on os.time() WALL CLOCK so an
-- overnight roast finishes while you sleep, then COLLECT fills counter stock
-- that streaming customers eat from (CustomerService:TryConsume). Fed
-- customers raise Buzz; walkouts drop it; Buzz drives customer flow.
-- Everything is server-authoritative; the client only asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local Furniture = require(Shared.Config.Furniture)
local Kitchen = require(Shared.Config.Kitchen)
local EconomyConfig = require(Shared.Config.Economy)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Mastery = require(Shared.Utilities.Mastery)
local Remotes = require(Shared.Network.Remotes)
local Log = require(Shared.Utilities.Log)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local Fx = require(script.Parent.Parent.Fx)

local KitchenService = {}
KitchenService.Name = "KitchenService"

local DataService: any
local EconomyService: any
local CafeService: any
local AnalyticsService: any
local GoalService: any

local cookLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

-- ————— helpers —————

local function kitchenOf(data: Types.PlayerData): Types.KitchenState
	-- Reconcile only fills top-level keys; heal older saves' nested shape.
	if typeof(data.kitchen) ~= "table" then
		(data :: any).kitchen = { cooks = {}, stock = {} }
	end
	if typeof(data.kitchen.cooks) ~= "table" then
		data.kitchen.cooks = {}
	end
	if typeof(data.kitchen.stock) ~= "table" then
		data.kitchen.stock = {}
	end
	return data.kitchen
end

local function findPlacedAppliance(
	data: Types.PlayerData,
	instanceId: string
): Types.FurnitureDefinition?
	for _, placed in data.placedFurniture do
		if placed.instanceId == instanceId then
			local def = Furniture[placed.catalogId]
			if def and def.cookable == true then
				return def
			end
			return nil
		end
	end
	return nil
end

local function applianceModel(player: Player, instanceId: string): Model?
	local folder = CafeService:GetFurnitureFolder(player)
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("instanceId") == instanceId then
			return child
		end
	end
	return nil
end

-- Mastery entry for a recipe, healing older saves' missing shape.
local function masteryOf(data: Types.PlayerData, recipeId: string): Types.RecipeMasteryEntry
	if typeof(data.recipeMastery) ~= "table" then
		(data :: any).recipeMastery = {}
	end
	local entry = data.recipeMastery[recipeId]
	if typeof(entry) ~= "table" then
		entry = { timesCooked = 0, masteryLevel = 0 }
		data.recipeMastery[recipeId] = entry
	end
	return entry
end

function KitchenService.MasteryLevel(_self: any, data: Types.PlayerData, recipeId: string): number
	return masteryOf(data, recipeId).masteryLevel
end

function KitchenService.batchCost(_self: any, recipe: Types.RecipeDefinition): number
	return recipe.ingredientCost * Kitchen.batchCostMultiplier
end

-- Effective (mastery-adjusted) numbers for a player's recipe.
function KitchenService.effectiveFor(
	_self: any,
	data: Types.PlayerData,
	recipe: Types.RecipeDefinition
): (number, number, number) -- cookTime, batchCost, servings
	local level = masteryOf(data, recipe.id).masteryLevel
	return Mastery.cookTime(recipe.cookTime, level, Kitchen.masteryTimeReductionPerStar),
		Mastery.batchCost(
			recipe.ingredientCost * Kitchen.batchCostMultiplier,
			level,
			Kitchen.masteryCostReductionPerStar
		),
		Mastery.servings(recipe.servings, level, Kitchen.masteryBonusServingAt)
end

function KitchenService.servingPayout(_self: any, recipe: Types.RecipeDefinition): number
	return math.max(1, math.floor(recipe.basePrice * Kitchen.servingPayoutFraction))
end

-- ————— stove visuals (server-side; replicate to everyone) —————

local function setCookVisuals(player: Player, instanceId: string, state: string, text: string?)
	local model = applianceModel(player, instanceId)
	if not model then
		return
	end
	model:SetAttribute("cookState", state)

	local anchor = model:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end

	local gui = model:FindFirstChild("CookTimer", true) :: BillboardGui?
	if state == "idle" then
		if gui then
			gui:Destroy()
		end
		local steam = model:FindFirstChild("CookSteam", true)
		if steam then
			steam:Destroy()
		end
		return
	end

	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "CookTimer"
		gui.Size = UDim2.fromScale(5, 1.3)
		gui.StudsOffset = Vector3.new(0, 3.4, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 90
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Name = "TimerLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
		label.BackgroundTransparency = 0.25
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 248, 235)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label
		label.Parent = gui

		local steam = Instance.new("ParticleEmitter")
		steam.Name = "CookSteam"
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(Color3.fromRGB(240, 238, 235))
		steam.Size = NumberSequence.new(0.6, 1.8)
		steam.Transparency = NumberSequence.new(0.4, 1)
		steam.Lifetime = NumberRange.new(0.8, 1.4)
		steam.Rate = 6
		steam.Speed = NumberRange.new(1.5, 2.5)
		steam.SpreadAngle = Vector2.new(12, 12)
		steam.Parent = anchor
	end
	local label = gui:FindFirstChild("TimerLabel") :: TextLabel?
	if label and text then
		label.Text = text
		label.TextColor3 = if state == "ready"
			then Color3.fromRGB(150, 235, 140)
			else Color3.fromRGB(255, 248, 235)
	end
end

-- ————— counter food display: stock made visible —————

local FOOD_COLORS: { [string]: Color3 } = {
	Coffee = Color3.fromRGB(120, 82, 55),
	Tea = Color3.fromRGB(140, 180, 110),
	Pastry = Color3.fromRGB(230, 180, 100),
	Sandwich = Color3.fromRGB(215, 160, 90),
}

-- Rebuild the little food stacks on the player's first counter so counter
-- stock is something you can SEE filling up and emptying.
local function refreshCounterDisplay(player: Player)
	local data = DataService:GetProfile(player)
	local folder = CafeService:GetFurnitureFolder(player)
	if not data or not folder then
		return
	end
	local counter: Model? = nil
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.Name == "counter" then
			counter = child
			break
		end
	end
	if not counter then
		return
	end
	local top = counter:FindFirstChild("Top") :: BasePart?
	if not top then
		return
	end

	local display = counter:FindFirstChild("StockDisplay")
	if display then
		display:Destroy()
	end
	display = Instance.new("Folder")
	display.Name = "StockDisplay"
	display.Parent = counter

	local kitchen = kitchenOf(data)
	local slot = 0
	for recipeId, count in kitchen.stock do
		local recipe = Recipes[recipeId]
		if recipe and count > 0 then
			local stacks = math.clamp(math.ceil(count / 6), 1, 3)
			for _ = 1, stacks do
				slot += 1
				if slot > 6 then
					break
				end
				local x = -4.2 + ((slot - 1) % 6) * 1.7
				local food = Instance.new("Part")
				food.Name = "Food_" .. recipeId
				food.Shape = Enum.PartType.Cylinder
				food.Size = Vector3.new(0.55, 1.1, 1.1)
				food.Color = FOOD_COLORS[recipe.category] or Color3.fromRGB(200, 160, 110)
				food.Material = Enum.Material.SmoothPlastic
				food.Anchored = true
				food.CanCollide = false
				food.CanQuery = false
				food.CFrame = top.CFrame
					* CFrame.new(x, 0.5, 0.6)
					* CFrame.Angles(0, 0, math.rad(90))
				food.Parent = display
			end
		end
	end
end

-- ————— Buzz —————

function KitchenService.AddBuzz(_self: any, player: Player, delta: number)
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local before = tonumber(data.buzz) or Kitchen.buzzStart
	data.buzz = math.clamp(before + delta, 0, Kitchen.buzzMax)
	if data.buzz ~= before then
		DataService:Push(player)
		CafeService:SetSignBuzz(player, data.buzz)
	end
end

function KitchenService.GetBuzz(_self: any, player: Player): number
	local data = DataService:GetProfile(player)
	return if data then (tonumber(data.buzz) or Kitchen.buzzStart) else Kitchen.buzzStart
end

-- ————— consumption (CustomerService calls this at the window) —————

-- Shared grant path for one consumed serving (both consume flavours).
local function grantConsumption(
	player: Player,
	data: Types.PlayerData,
	kitchen: Types.KitchenState,
	recipeId: string
): number
	local recipe = Recipes[recipeId]
	kitchen.stock[recipeId] = (kitchen.stock[recipeId] or 1) - 1
	local payout = KitchenService:servingPayout(recipe)
	EconomyService:AddCoins(player, payout)
	EconomyService:AddReputation(player, EconomyConfig.reputationPerServe)
	data.stats.customersServed += 1
	KitchenService:AddBuzz(player, Kitchen.buzzPerFedCustomer)
	DataService:Push(player)
	if AnalyticsService then
		AnalyticsService:Track(player, "stock_consumed", { recipe = recipeId, paid = payout })
	end
	if GoalService then
		GoalService:Bump(player, "serve_customers", 1)
	end
	refreshCounterDisplay(player)
	return payout
end

-- Try to feed one customer from counter stock. Returns recipeId + payout,
-- or nil when nothing is stocked (caller falls back to a manual order).
function KitchenService.TryConsume(_self: any, player: Player): (string?, number?)
	local data = DataService:GetProfile(player)
	if not data then
		return nil, nil
	end
	local kitchen = kitchenOf(data)

	local bestId: string? = nil
	local bestCount = 0
	for recipeId, count in kitchen.stock do
		if count > 0 and Recipes[recipeId] and count > bestCount then
			bestId = recipeId
			bestCount = count
		end
	end
	if bestId == nil then
		return nil, nil
	end
	return bestId, grantConsumption(player, data, kitchen, bestId)
end

-- Feed a specific dish (a waiting customer's order) if it's in stock.
function KitchenService.ConsumeSpecific(
	_self: any,
	player: Player,
	recipeId: string
): (boolean, number?)
	local data = DataService:GetProfile(player)
	if not data or not Recipes[recipeId] then
		return false, nil
	end
	local kitchen = kitchenOf(data)
	if (kitchen.stock[recipeId] or 0) <= 0 then
		return false, nil
	end
	return true, grantConsumption(player, data, kitchen, recipeId)
end

function KitchenService.IsCooking(_self: any, player: Player, instanceId: string): boolean
	local data = DataService:GetProfile(player)
	if not data then
		return false
	end
	return kitchenOf(data).cooks[instanceId] ~= nil
end

-- ————— remote handlers —————

local function handleStartCook(player: Player, instanceId: unknown, recipeId: unknown)
	if typeof(instanceId) ~= "string" or typeof(recipeId) ~= "string" then
		return
	end
	if not cookLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local recipe = Recipes[recipeId]
	if not recipe or data.unlockedRecipes[recipeId] ~= true then
		return
	end
	local applianceDef = findPlacedAppliance(data, instanceId :: string)
	if not applianceDef or applianceDef.id ~= recipe.applianceId then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "wrong_appliance" })
		return
	end
	local kitchen = kitchenOf(data)
	if kitchen.cooks[instanceId] ~= nil then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "stove_busy" })
		return
	end
	if not CafeService:IsNearOwnPlot(player, 60) then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "too_far" })
		return
	end
	local effTime, effCost, _ = KitchenService:effectiveFor(data, recipe)
	if not EconomyService:TrySpendCoins(player, effCost) then
		Remotes.event("Notify"):FireClient(player, {
			kind = "error",
			reason = "cant_afford_ingredients",
		})
		return
	end

	kitchen.cooks[instanceId] = {
		recipeId = recipeId :: string,
		startedAt = os.time(),
		duration = effTime,
	}
	DataService:Push(player)
	setCookVisuals(player, instanceId :: string, "cooking", recipe.displayName .. " …")
	Remotes.event("Notify"):FireClient(player, {
		kind = "cook_started",
		recipe = recipe.displayName,
		cookTime = recipe.cookTime,
	})
	if AnalyticsService then
		AnalyticsService:Track(player, "batch_started", { recipe = recipeId, cost = cost })
	end
end

local function handleCollectCook(player: Player, instanceId: unknown)
	if typeof(instanceId) ~= "string" then
		return
	end
	if not cookLimiter:check(player.UserId, os.clock()) then
		return
	end
	local data = DataService:GetProfile(player)
	if not data then
		return
	end
	local kitchen = kitchenOf(data)
	local cook = kitchen.cooks[instanceId]
	if not cook then
		return
	end
	local recipe = Recipes[cook.recipeId]
	if not recipe then -- config drift: refund nothing, just clear
		kitchen.cooks[instanceId] = nil
		DataService:Push(player)
		return
	end
	local duration = tonumber(cook.duration) or recipe.cookTime
	local elapsed = os.time() - cook.startedAt
	if elapsed < duration then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "not_ready" })
		return
	end

	-- Grant BEFORE clearing so nothing else pays this batch.
	kitchen.cooks[instanceId] = nil
	local entry = masteryOf(data, cook.recipeId)
	local servings =
		Mastery.servings(recipe.servings, entry.masteryLevel, Kitchen.masteryBonusServingAt)
	local newStock =
		math.min(Kitchen.maxStockPerRecipe, (kitchen.stock[cook.recipeId] or 0) + servings)
	kitchen.stock[cook.recipeId] = newStock

	local fresh = elapsed <= duration * Kitchen.freshWindowMultiplier
	local bonus = 0
	if fresh then
		local batchValue = servings * KitchenService:servingPayout(recipe)
		bonus = math.floor(
			batchValue
				* Kitchen.freshBonusFraction
				* Mastery.freshMult(
					entry.masteryLevel,
					Kitchen.masteryFreshBoostAt,
					Kitchen.masteryFreshMult
				)
		)
		if bonus > 0 then
			EconomyService:AddCoins(player, bonus)
		end
	end

	-- Mastery: every collected batch teaches the recipe.
	entry.timesCooked += 1
	local newLevel = Mastery.levelFor(recipe.masteryThresholds, entry.timesCooked)
	if newLevel > entry.masteryLevel then
		entry.masteryLevel = newLevel
		Remotes.event("Notify"):FireClient(player, {
			kind = "mastery_up",
			recipe = recipe.displayName,
			stars = newLevel,
		})
		local starModel = applianceModel(player, instanceId :: string)
		if starModel then
			Fx.floatText(
				starModel:GetPivot().Position + Vector3.new(0, 5.5, 0),
				"⭐ " .. recipe.displayName .. " " .. string.rep("★", newLevel),
				Color3.fromRGB(255, 215, 120)
			)
		end
		if AnalyticsService then
			AnalyticsService:Track(
				player,
				"mastery_up",
				{ recipe = cook.recipeId, stars = newLevel }
			)
		end
	end
	EconomyService:AddExperience(player, Kitchen.xpPerCollect)
	data.stats.recipesCooked += 1
	DataService:Push(player)
	setCookVisuals(player, instanceId :: string, "idle", nil)
	refreshCounterDisplay(player)
	if GoalService then
		GoalService:Bump(player, "collect_batches", 1)
	end

	-- Juice: the collect moment should feel like a small payday.
	local model = applianceModel(player, instanceId :: string)
	if model then
		local pivot = model:GetPivot()
		Fx.coinBurst(pivot.Position + Vector3.new(0, 3, 0), if bonus > 0 then 8 else 5)
		Fx.floatText(
			pivot.Position + Vector3.new(0, 4, 0),
			"+"
				.. tostring(recipe.servings)
				.. " 🍽️"
				.. (if bonus > 0 then "  ✨+" .. tostring(bonus) else ""),
			Color3.fromRGB(170, 235, 150)
		)
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "cook_collected",
		recipe = recipe.displayName,
		servings = recipe.servings,
		fresh = fresh,
		bonus = bonus,
	})
	if AnalyticsService then
		AnalyticsService:Track(player, "batch_collected", {
			recipe = cook.recipeId,
			fresh = fresh,
			bonus = bonus,
		})
		AnalyticsService:TrackOnce(player, "first_batch_collected", {})
	end
end

-- ————— timers loop: keep stove billboards fresh, restore after rejoin —————

local function tickTimers()
	for _, player in Players:GetPlayers() do
		local data = DataService:GetProfile(player)
		if data then
			local kitchen = kitchenOf(data)
			for instanceId, cook in kitchen.cooks do
				local recipe = Recipes[cook.recipeId]
				if recipe then
					local duration = tonumber(cook.duration) or recipe.cookTime
					local remaining = duration - (os.time() - cook.startedAt)
					if remaining > 0 then
						local mins = math.floor(remaining / 60)
						local secs = remaining % 60
						local text = if mins > 0
							then string.format("%s %d:%02d", recipe.displayName, mins, secs)
							else string.format("%s %ds", recipe.displayName, secs)
						setCookVisuals(player, instanceId, "cooking", text)
					else
						setCookVisuals(player, instanceId, "ready", recipe.displayName .. " READY!")
					end
				end
			end
		end
	end
end

function KitchenService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	EconomyService = ServiceRegistry.get("EconomyService")
	CafeService = ServiceRegistry.get("CafeService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
	GoalService = ServiceRegistry.get("GoalService")
end

function KitchenService.Start(_self: any)
	Remotes.event("StartCook").OnServerEvent:Connect(handleStartCook)
	Remotes.event("CollectCook").OnServerEvent:Connect(handleCollectCook)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tickTimers)
			if not ok then
				Log.warn("Kitchen timer tick failed:", err)
			end
		end
	end)

	-- On join: paint the sign with the persisted Buzz (stove billboards
	-- self-restore via the 1s timer loop).
	local function onJoin(player: Player)
		task.spawn(function()
			for _ = 1, 100 do
				if DataService:IsLoaded(player) then
					local data = DataService:GetProfile(player)
					if data then
						CafeService:SetSignBuzz(player, tonumber(data.buzz) or Kitchen.buzzStart)
					end
					return
				end
				task.wait(0.2)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerAdded:Connect(onJoin)

	Players.PlayerRemoving:Connect(function(player)
		cookLimiter:clear(player.UserId)
	end)

	Log.info("KitchenService ready (cook-ahead loop)")
end

return KitchenService
