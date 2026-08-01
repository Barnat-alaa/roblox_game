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

-- Camera controls, rebuilt mobile-first (owner 2026-08-01: "don't show Q, E etc
-- icon, just add a small arrow right and left transparent to direct the camera",
-- and "be sure every item is in the extreme top, bottom and left so they are not
-- in the center of the screen").
--
-- Was: an opaque 100x100 pad of four chunky lettered buttons (Q / E / + / -).
-- The letters meant nothing on a phone, which has no keyboard, and the slab ate
-- a corner of the view.
--
-- Now: two TRANSPARENT chevrons pinned to the extreme left and right edges at
-- thumb height. Zoom buttons are gone entirely -- pinch-to-zoom already exists
-- (see the pinch handler below), and it is the gesture a phone player reaches
-- for anyway, so two buttons beat four.
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

	-- Touch only: a mouse has Q/E and the scroll wheel already.
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

	-- A chevron drawn from two bars rather than a glyph, so it can never land on
	-- a font without the character (the coin-emoji lesson).
	local function arrow(name: string, onLeft: boolean, onTap: () -> ())
		local button = Instance.new("TextButton")
		button.Name = name
		button.Text = ""
		button.AutoButtonColor = false
		button.Visible = touchOnly
		button.AnchorPoint = Vector2.new(if onLeft then 0 else 1, 0.5)
		button.BackgroundColor3 = Theme.Colors.Espresso
		button.BackgroundTransparency = 0.55 -- transparent, as asked
		button.Size = UDim2.fromOffset(Theme.Hud.TouchTarget, Theme.Hud.TouchTarget)
		Components.Corner(button, Theme.Radius.Pill)
		Components.Stroke(button, Theme.Colors.Cream, 1, 0.75)
		button.Parent = gui

		for index, tilt in { 38, -38 } do
			local bar = Instance.new("Frame")
			bar.Size = UDim2.fromOffset(4, 15)
			bar.AnchorPoint = Vector2.new(0.5, if index == 1 then 1 else 0)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.BackgroundColor3 = Theme.Colors.Cream
			bar.BackgroundTransparency = 0.15
			bar.BorderSizePixel = 0
			bar.Rotation = if onLeft then tilt else -tilt
			Components.Corner(bar, 2)
			bar.Parent = button
		end

		button.Activated:Connect(onTap)
		return button
	end

	local left = arrow("CameraLeft", true, function()
		rotate(1)
	end)
	local right = arrow("CameraRight", false, function()
		rotate(-1)
	end)

	ResponsiveLayout.watch(function(_mode, viewport)
		-- Extreme edges, at thumb height: a touch below centre, where a hand
		-- holding a phone actually rests.
		local y = math.floor(viewport.Y * 0.62)
		left.Position = UDim2.new(0, Theme.Hud.EdgeMargin, 0, y)
		right.Position = UDim2.new(1, -Theme.Hud.EdgeMargin, 0, y)
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
