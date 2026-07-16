--!strict
-- Build mode: a catalogue of owned items + a live grid preview (green = fits,
-- red = blocked). The server re-validates every placement — this is only UX.
-- Tap/click the floor to place; Rotate button or R key to rotate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Grid = require(Shared.Utilities.Grid)
local World = require(Shared.Config.World)
local Furniture = require(Shared.Config.Furniture)
local Remotes = require(Shared.Network.Remotes)

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(55, 42, 38)

local BuildController = {}
BuildController.Name = "BuildController"

local active = false
local selectedId: string? = nil
local rotation = 0
local previewPart: Part? = nil
local ui: { [string]: any } = {}

local function corner(radius: number, parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function getOrigin(): CFrame?
	local o = player:GetAttribute("PlotOrigin")
	return if typeof(o) == "CFrame" then o else nil
end

local function raycastCell(screenPos: Vector2): (number?, number?)
	local origin = getOrigin()
	local camera = workspace.CurrentCamera
	if not origin or not camera then
		return nil, nil
	end
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	if previewPart then
		table.insert(exclude, previewPart)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not result then
		return nil, nil
	end
	local gx, gy = Grid.worldToCell(origin, result.Position)
	return gx, gy
end

local function updatePreview()
	if not active or not selectedId then
		if previewPart then
			previewPart.Parent = nil
		end
		return
	end
	local def = Furniture[selectedId]
	local origin = getOrigin()
	if not def or not origin then
		return
	end
	local gx, gy = raycastCell(UserInputService:GetMouseLocation())
	if not gx or not gy then
		return
	end
	if not previewPart then
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.35
		part.Material = Enum.Material.SmoothPlastic
		previewPart = part
	end
	local pv = previewPart :: Part
	pv.Size =
		Vector3.new(def.width * Grid.CELL_SIZE - 0.2, def.height, def.depth * Grid.CELL_SIZE - 0.2)
	pv.CFrame = Grid.cellToWorld(origin, gx, gy, def.width, def.depth, rotation, def.height)
	-- Mirror the server's tier clamp (CafeService sets the ExpansionTier
	-- attribute): the unpurchased garden must preview red, not green.
	local tier = tonumber(player:GetAttribute("ExpansionTier")) or 0
	local depthCells = World.interiorDepthTiers[math.clamp(tier + 1, 1, #World.interiorDepthTiers)]
	local fits = Grid.inBounds(gx, gy, def.width, def.depth, rotation, nil, depthCells)
	pv.Color = if fits then Color3.fromRGB(90, 200, 110) else Color3.fromRGB(220, 80, 80)
	pv.Parent = workspace
end

local function tryPlace(screenPos: Vector2)
	if not active or not selectedId then
		return
	end
	local gx, gy = raycastCell(screenPos)
	if not gx or not gy then
		return
	end
	Remotes.event("PlaceFurniture"):FireServer({
		catalogId = selectedId,
		gridX = gx,
		gridY = gy,
		rotation = rotation,
	})
end

local function refreshCatalogue()
	if not ui.list then
		return
	end
	for _, child in ui.list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local profile = UIController.getProfile()
	if not profile then
		return
	end
	local order = 0
	for id, count in profile.inventory do
		if count > 0 then
			order += 1
			local def = Furniture[id]
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -6, 0, 38)
			btn.LayoutOrder = order
			btn.BackgroundColor3 = if selectedId == id
				then Color3.fromRGB(120, 190, 130)
				else Color3.fromRGB(255, 250, 240)
			btn.TextColor3 = DARK
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 15
			btn.Text = (if def then def.displayName else id) .. "  x" .. tostring(count)
			corner(8, btn)
			btn.Activated:Connect(function()
				selectedId = id
				refreshCatalogue()
			end)
			btn.Parent = ui.list
		end
	end
end

local function toggle()
	active = not active
	ui.panel.Visible = active
	if active then
		refreshCatalogue()
	else
		selectedId = nil
		if previewPart then
			previewPart.Parent = nil
		end
	end
end

local function buildPanel()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildUI"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(240, 340)
	panel.Position = UDim2.fromOffset(12, 64)
	panel.BackgroundColor3 = Color3.fromRGB(245, 235, 218)
	panel.Visible = false
	corner(16, panel)
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(10, 6)
	title.BackgroundTransparency = 1
	title.Text = "🔨 Build — tap the floor"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = DARK
	title.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -90)
	list.Position = UDim2.fromOffset(8, 38)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	ui.list = list

	local rotateBtn = Instance.new("TextButton")
	rotateBtn.Size = UDim2.new(0.5, -12, 0, 40)
	rotateBtn.Position = UDim2.new(0, 8, 1, -46)
	rotateBtn.BackgroundColor3 = Color3.fromRGB(120, 95, 160)
	rotateBtn.TextColor3 = Color3.fromRGB(255, 250, 242)
	rotateBtn.Font = Enum.Font.GothamBold
	rotateBtn.TextSize = 16
	rotateBtn.Text = "⟳ Rotate"
	corner(10, rotateBtn)
	rotateBtn.Activated:Connect(function()
		rotation = (rotation + 1) % 4
	end)
	rotateBtn.Parent = panel

	local doneBtn = Instance.new("TextButton")
	doneBtn.Size = UDim2.new(0.5, -12, 0, 40)
	doneBtn.Position = UDim2.new(0.5, 4, 1, -46)
	doneBtn.BackgroundColor3 = Color3.fromRGB(90, 165, 95)
	doneBtn.TextColor3 = Color3.fromRGB(255, 250, 242)
	doneBtn.Font = Enum.Font.GothamBold
	doneBtn.TextSize = 16
	doneBtn.Text = "✓ Done"
	corner(10, doneBtn)
	doneBtn.Activated:Connect(toggle)
	doneBtn.Parent = panel

	ui.panel = panel
end

function BuildController.Start(_self: any)
	buildPanel()

	UIController.onBuildToggle = toggle
	UIController.subscribeProfile(function()
		if active then
			refreshCatalogue()
		end
	end)

	RunService.RenderStepped:Connect(updatePreview)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tryPlace(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 1) % 4
		end
	end)
end

return BuildController
