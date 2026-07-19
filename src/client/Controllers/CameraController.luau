--!strict
-- Fixed three-quarter cafe camera with compact touch controls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Grid = require(ReplicatedStorage:WaitForChild("Shared").Utilities.Grid)
local Components = require(script.Parent.Parent.UI.Components)
local ResponsiveLayout = require(script.Parent.Parent.UI.ResponsiveLayout)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local CameraController = {}
CameraController.Name = "CameraController"

local ELEVATION = math.rad(38)
local YAWS = { 225, 315, 45, 135 }
local yawIndex = 1
local currentYaw = math.rad(YAWS[yawIndex])
local targetYaw = currentYaw
local zoom = 40
local targetZoom = zoom
local ZOOM_MIN, ZOOM_MAX = 24, 120
local focus = Vector3.new(24, 2, 24)

local WALL_NORMALS: { [string]: Vector3 } = {
	WallFront = Vector3.new(0, 0, -1),
	WallLeft = Vector3.new(-1, 0, 0),
	WallRight = Vector3.new(1, 0, 0),
	WallBack = Vector3.new(0, 0, 1),
}

local function fadeWallsIn(container: Instance, cameraPosition: Vector3, enabled: boolean)
	for _, child in container:GetChildren() do
		local localNormal = WALL_NORMALS[child.Name]
		if localNormal and child:IsA("BasePart") then
			local normal = child.CFrame:VectorToWorldSpace(localNormal)
			local toCamera = cameraPosition - child.Position
			toCamera = Vector3.new(toCamera.X, 0, toCamera.Z)
			local facing = toCamera.Magnitude > 0.01 and toCamera.Unit:Dot(normal) > 0.35
			child.LocalTransparencyModifier = if enabled and facing then 0.98 else 0
		end
	end
end

local function updateWallFades(cameraPosition: Vector3)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local characterPosition = if root and root:IsA("BasePart") then root.Position else nil
	for _, plot in plots:GetChildren() do
		local inside = false
		local origin = plot:GetAttribute("origin")
		if characterPosition and typeof(origin) == "CFrame" then
			inside = Grid.distanceToPlotRect(origin, characterPosition) < 0.5
		end
		fadeWallsIn(plot, cameraPosition, inside)
		local shell = plot:FindFirstChild("Shell")
		if shell then
			fadeWallsIn(shell, cameraPosition, inside)
		end
	end
end

local function shortestAngle(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

local function rotate(step: number)
	yawIndex = ((yawIndex - 1 + step) % #YAWS) + 1
	targetYaw = math.rad(YAWS[yawIndex])
end

local function zoomBy(delta: number)
	targetZoom = math.clamp(targetZoom + delta, ZOOM_MIN, ZOOM_MAX)
end

local function buildTouchControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = true
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 10, 0.5, 0)
	holder.Size = UDim2.fromOffset(100, 100)
	holder.BackgroundColor3 = Theme.Colors.Espresso
	holder.BackgroundTransparency = 0.12
	Components.Corner(holder, Theme.Radius.Large)
	Components.Stroke(holder, Theme.Colors.Cream, 1, 0.7)
	holder.Parent = gui
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(42, 42)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	ResponsiveLayout.watch(function(mode)
		holder.Position = if mode == "Compact"
			then UDim2.fromOffset(10, 112)
			else UDim2.new(0, 10, 0.5, 0)
	end)

	local function button(text: string, order: number, onTap: () -> ())
		local value = Instance.new("TextButton")
		value.Size = UDim2.fromOffset(42, 42)
		value.BackgroundColor3 = if order <= 2 then Theme.Colors.Coral else Theme.Colors.Roast
		value.BackgroundTransparency = 0.02
		value.Font = Theme.Font.Bold
		value.TextSize = 14
		value.TextColor3 = Theme.Colors.Cream
		value.Text = text
		value.LayoutOrder = order
		Components.Corner(value, Theme.Radius.Medium)
		value.Activated:Connect(onTap)
		value.Parent = holder
	end
	button("Q", 1, function()
		rotate(1)
	end)
	button("E", 2, function()
		rotate(-1)
	end)
	button("+", 3, function()
		zoomBy(-10)
	end)
	button("-", 4, function()
		zoomBy(10)
	end)
end

function CameraController.Start(_self: any)
	local camera = workspace.CurrentCamera
	buildTouchControls()
	task.spawn(function()
		for _ = 1, 60 do
			local origin = player:GetAttribute("PlotOrigin")
			if typeof(origin) == "CFrame" then
				if origin.LookVector.Z > 0.5 then
					yawIndex = 3
					targetYaw = math.rad(YAWS[yawIndex])
					currentYaw = targetYaw
				end
				return
			end
			task.wait(0.5)
		end
	end)

	local pinchStartZoom = zoom
	UserInputService.TouchPinch:Connect(function(_, scale, _, state)
		if state == Enum.UserInputState.Begin then
			pinchStartZoom = targetZoom
		elseif state == Enum.UserInputState.Change then
			targetZoom = math.clamp(pinchStartZoom / math.max(scale, 0.2), ZOOM_MIN, ZOOM_MAX)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			rotate(1)
		elseif input.KeyCode == Enum.KeyCode.E then
			rotate(-1)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseWheel then
			targetZoom = math.clamp(targetZoom - input.Position.Z * 7, ZOOM_MIN, ZOOM_MAX)
		end
	end)
	RunService.RenderStepped:Connect(function(deltaTime)
		camera.CameraType = Enum.CameraType.Scriptable
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			focus = focus:Lerp(root.Position + Vector3.new(0, 1, 0), math.min(deltaTime * 8, 1))
		end
		currentYaw += shortestAngle(currentYaw, targetYaw) * math.min(deltaTime * 7, 1)
		zoom += (targetZoom - zoom) * math.min(deltaTime * 8, 1)
		local direction = Vector3.new(
			math.sin(currentYaw) * math.cos(ELEVATION),
			math.sin(ELEVATION),
			math.cos(currentYaw) * math.cos(ELEVATION)
		)
		local cameraPosition = focus + direction * zoom
		camera.CFrame = CFrame.lookAt(cameraPosition, focus)
		updateWallFades(cameraPosition)
	end)
end

return CameraController
