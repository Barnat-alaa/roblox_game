--!strict
-- Pure payout math shared by the server (OrderService) and the tests
-- (tests/Economy.spec.luau). No player/instance references here on purpose.

local EconomyConfig = require(script.Parent.Parent.Config.Economy)
local Gifts = require(script.Parent.Parent.Config.Gifts)
local Types = require(script.Parent.Parent.Types)

local RewardMath = {}

-- Coins for completing an order, before any tip.
function RewardMath.orderPayout(recipe: Types.RecipeDefinition, manualCook: boolean): number
	local profit = recipe.basePrice - recipe.ingredientCost
	if manualCook then
		profit += math.floor(recipe.basePrice * EconomyConfig.manualCookQualityBonus)
	end
	return math.max(0, profit)
end

-- Tip coins. `roll` is a 1..100 value supplied by the caller (Random on the server,
-- a fixed value in tests) so this stays deterministic and testable.
function RewardMath.tipAmount(
	recipe: Types.RecipeDefinition,
	roll: number,
	tipMultiplier: number
): number
	if roll <= EconomyConfig.tipChancePercent then
		return math.floor(recipe.basePrice * EconomyConfig.tipFraction * tipMultiplier)
	end
	return 0
end

-- Roll one VIP gift-box reward from the weighted table (Config/Gifts). `pickRoll`
-- and `amountRoll` are 0..1 values (Random on the server, fixed in tests) so this
-- stays deterministic and testable. Returns the reward kind, integer amount, and
-- display label. A GIFT, not a loot box: opened for free, odds never touch money.
function RewardMath.rollGift(
	pickRoll: number,
	amountRoll: number
): { kind: string, amount: number, label: string }
	local total = 0
	for _, g in Gifts do
		total += g.weight
	end
	local pick = math.clamp(pickRoll, 0, 1) * total
	local acc = 0
	local chosen = Gifts[#Gifts]
	for _, g in Gifts do
		acc += g.weight
		if pick <= acc then
			chosen = g
			break
		end
	end
	local amount =
		math.floor(chosen.min + math.clamp(amountRoll, 0, 1) * (chosen.max - chosen.min) + 0.5)
	return { kind = chosen.kind, amount = amount, label = chosen.label }
end

return RewardMath
