--!strict
-- Builds the visual "plate with food" used by the service theater (S2):
-- the cook/barista finishes it, the waiter carries it, it lands in front of
-- the customer, and after the meal the emptied plate stays behind as the
-- dirty dish the cleaner collects and washes.

local PlateFactory = {}

-- Returns (plateModel, foodInstance). The plate model's pivot is the dish
-- part, so callers position it with plateModel:PivotTo(...). `assetLibrary`
-- is AssetLibraryService (or nil) — without a loaded food prop the food is
-- the classic coloured ball.
function PlateFactory.make(assetLibrary: any, recipe: any): (Model, Instance)
	local plateModel = Instance.new("Model")
	plateModel.Name = "MealPlate"

	local dish = Instance.new("Part")
	dish.Name = "Plate"
	dish.Shape = Enum.PartType.Cylinder
	dish.Size = Vector3.new(0.18, 1.8, 1.8)
	dish.Color = Color3.fromRGB(245, 242, 235)
	dish.Material = Enum.Material.SmoothPlastic
	dish.Anchored = true
	dish.CanCollide = false
	dish.CanQuery = false
	dish.CFrame = CFrame.Angles(0, 0, math.rad(90))
	-- Cancel the cylinder's 90° roll in the pivot so PivotTo(CFrame.new(pos))
	-- keeps the plate flat instead of tipping it on its rim.
	dish.PivotOffset = CFrame.Angles(0, 0, math.rad(-90))
	dish.Parent = plateModel
	plateModel.PrimaryPart = dish

	local food: Instance
	local prop: Model? = if assetLibrary and recipe
		then assetLibrary:GetProp(recipe.category, recipe.id)
		else nil
	if prop then
		for _, d in prop:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		-- Position only (the dish CFrame carries a 90° roll the food must not inherit).
		prop:PivotTo(CFrame.new((dish.CFrame * CFrame.new(0.35, 0, 0)).Position))
		prop.Parent = plateModel
		food = prop
	else
		local ball = Instance.new("Part")
		ball.Name = "Food"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(0.9, 0.7, 0.9)
		ball.Color = if recipe and recipe.category == "Coffee"
			then Color3.fromRGB(120, 82, 55)
			elseif recipe and recipe.category == "Tea" then Color3.fromRGB(140, 180, 110)
			elseif recipe and recipe.category == "Pastry" then Color3.fromRGB(230, 180, 100)
			else Color3.fromRGB(215, 160, 90)
		ball.Material = Enum.Material.SmoothPlastic
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CFrame = dish.CFrame * CFrame.new(0.4, 0, 0)
		ball.Parent = plateModel
		food = ball
	end

	return plateModel, food
end

return PlateFactory
