--!strict
-- MVP customer generator (prototype). Keeps at most one pending order per café
-- and creates a new one on an interval. Visible walking NPCs + seat routing come
-- on Day 3 — this drives the serve loop end-to-end today via OrderCreated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Customers = require(Shared.Config.Customers)
local Types = require(Shared.Types)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)

local CustomerService = {}
CustomerService.Name = "CustomerService"

local DataService: any
local OrderService: any

local SPAWN_INTERVAL = 8
local pendingByUser: { [number]: boolean } = {}
local rng = Random.new()

local function pickUnlockedRecipe(data: Types.PlayerData): string?
	local pool: { string } = {}
	for recipeId, unlocked in data.unlockedRecipes do
		if unlocked then
			table.insert(pool, recipeId)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function pickCustomer(): string
	local ids: { string } = {}
	for id in Customers do
		table.insert(ids, id)
	end
	return ids[rng:NextInteger(1, #ids)]
end

-- Called by OrderService once an order is served, freeing the café for the next.
function CustomerService.OnOrderResolved(_self: any, userId: number)
	pendingByUser[userId] = nil
end

function CustomerService.Init(_self: any)
	DataService = ServiceRegistry.get("DataService")
	OrderService = ServiceRegistry.get("OrderService")
end

function CustomerService.Start(_self: any)
	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)
			for _, player in Players:GetPlayers() do
				if DataService:IsLoaded(player) and not pendingByUser[player.UserId] then
					local data = DataService:GetProfile(player)
					if data then
						local recipeId = pickUnlockedRecipe(data)
						if recipeId then
							local orderId =
								OrderService:CreateOrder(player, recipeId, pickCustomer())
							if orderId then
								pendingByUser[player.UserId] = true
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingByUser[player.UserId] = nil
	end)
end

return CustomerService
