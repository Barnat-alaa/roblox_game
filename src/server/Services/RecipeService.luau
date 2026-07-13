--!strict
-- Recipe lookups + the manual-brew minigame (Day 3). The client only reports
-- WHEN it stopped the brew bar; the server derives the indicator position from
-- its own clock using the shared Cooking config, so a "perfect brew" cannot be
-- forged. A successful brew arms a ONE-SHOT manual flag for that order which
-- OrderService consumes at claim time — the client's opinion is never trusted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local Cooking = require(Shared.Config.Cooking)
local EconomyConfig = require(Shared.Config.Economy)
local RewardMath = require(Shared.Utilities.RewardMath)
local RateLimiter = require(Shared.Utilities.RateLimiter)
local Remotes = require(Shared.Network.Remotes)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local RecipeService = {}
RecipeService.Name = "RecipeService"

local DataService: any
local OrderService: any
local CafeService: any
local AnalyticsService: any

type CookSession = { orderId: string, startClock: number }

local sessions: { [number]: CookSession } = {}
local manualReady: { [number]: string } = {}
local cookLimiter =
	RateLimiter.new(EconomyConfig.maxRequestsPerWindow, EconomyConfig.rateWindowSeconds)

function RecipeService.GetRecipe(_self: any, recipeId: string): Types.RecipeDefinition?
	return Recipes[recipeId]
end

function RecipeService.IsUnlocked(_self: any, data: Types.PlayerData, recipeId: string): boolean
	return data.unlockedRecipes[recipeId] == true
end

function RecipeService.Payout(_self: any, recipeId: string, manualCook: boolean): number
	local recipe = Recipes[recipeId]
	if not recipe then
		return 0
	end
	return RewardMath.orderPayout(recipe, manualCook)
end

-- Deterministic 0..1 indicator position after `elapsed` seconds. The client
-- renders the exact same function, so honest timing lands in the zone.
function RecipeService.BarPosition(_self: any, elapsed: number): number
	local phase = (elapsed % Cooking.barPeriod) / Cooking.barPeriod
	return 0.5 + 0.5 * math.sin(2 * math.pi * phase - math.pi / 2)
end

local function handleStart(player: Player, orderId: unknown)
	if typeof(orderId) ~= "string" then
		return
	end
	if not cookLimiter:check(player.UserId, os.clock()) then
		return
	end
	local order = OrderService:GetActiveOrder(orderId)
	if not order or order.ownerUserId ~= player.UserId or order.claimed then
		return
	end
	local data = DataService:GetProfile(player)
	if not data or data.unlockedRecipes[order.recipeId] ~= true then
		return
	end
	if not CafeService:IsNearOwnPlot(player, 60) then
		Remotes.event("Notify"):FireClient(player, { kind = "error", reason = "too_far" })
		return
	end

	sessions[player.UserId] = { orderId = orderId :: string, startClock = os.clock() }
	if AnalyticsService then
		AnalyticsService:TrackOnce(player, "first_recipe_started", { recipe = order.recipeId })
	end
end

local function handleFinish(player: Player, orderId: unknown)
	if typeof(orderId) ~= "string" then
		return
	end
	if not cookLimiter:check(player.UserId, os.clock()) then
		return
	end
	local session = sessions[player.UserId]
	if not session or session.orderId ~= orderId then
		return
	end
	sessions[player.UserId] = nil

	local elapsed = os.clock() - session.startClock
	local success = false
	if elapsed <= Cooking.sessionTtl then
		local pos = RecipeService:BarPosition(elapsed)
		success = math.abs(pos - Cooking.targetCenter)
			<= (Cooking.targetHalfWidth + Cooking.serverTolerance)
	end

	if success then
		manualReady[player.UserId] = orderId :: string
	end
	Remotes.event("Notify"):FireClient(player, {
		kind = "cook_result",
		success = success,
		orderId = orderId,
	})
	if AnalyticsService then
		AnalyticsService:Track(player, "manual_cook", { success = success })
		if success then
			AnalyticsService:TrackOnce(player, "first_recipe_completed", {})
		end
	end
end

-- One-shot: OrderService calls this at claim time. Returns true at most once
-- per armed brew, and only for the exact order that was brewed.
function RecipeService.ConsumeManualCook(_self: any, player: Player, orderId: string): boolean
	if manualReady[player.UserId] == orderId then
		manualReady[player.UserId] = nil
		return true
	end
	return false
end

function RecipeService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	OrderService = ServiceRegistry.get("OrderService")
	CafeService = ServiceRegistry.get("CafeService")
	AnalyticsService = ServiceRegistry.get("AnalyticsService")
end

function RecipeService.Start(_self: any)
	Remotes.event("StartCooking").OnServerEvent:Connect(handleStart)
	Remotes.event("FinishCooking").OnServerEvent:Connect(handleFinish)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player.UserId] = nil
		manualReady[player.UserId] = nil
		cookLimiter:clear(player.UserId)
	end)
end

return RecipeService
