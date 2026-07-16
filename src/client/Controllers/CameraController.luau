--!strict
-- Fixed three-quarter "café sim" camera (art direction pass): elevated
-- dimetric angle locked to 90° steps — Q/E rotates, mouse wheel zooms —
-- always following the character. Walls facing the camera fade client-side
-- so you look INTO rooms, the way the classic café sims framed them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local CameraController = {}
CameraController.Name = "CameraController"

local ELEVATION = math.rad(38)
-- 225° = camera in front-left of a plot (plots open toward -Z).
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

local function fadeWallsIn(container: Instance, cameraPos: Vector3)
	for _, child in container:GetChildren() do
		local localNormal = WALL_NORMALS[child.Name]
		if localNormal and child:IsA("BasePart") then
			-- Row-1 plots are rotated 180°, so resolve the outward normal
			-- in the wall's own space instead of assuming world axes.
			local normal = child.CFrame:VectorToWorldSpace(localNormal)
			local toCam = cameraPos - child.Position
			toCam = Vector3.new(toCam.X, 0, toCam.Z)
			local facing = toCam.Magnitude > 0.01 and toCam.Unit:Dot(normal) > 0.35
			child.LocalTransparencyModifier = if facing then 0.98 else 0
		end
	end
end

-- Fade any wall whose outward face points at the camera (you see through it).
-- Facade walls sit on the plot model; side/back walls live in the tier-built
-- "Shell" submodel (S2), so scan both levels.
local function updateWallFades(cameraPos: Vector3)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		fadeWallsIn(plot, cameraPos)
		local shell = plot:FindFirstChild("Shell")
		if shell then
			fadeWallsIn(shell, cameraPos)
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

-- On-screen camera buttons: required on touch, harmless on PC (they also
-- advertise that the camera rotates/zooms at all).
local function buildTouchControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 10, 0.5, 0)
	holder.Size = UDim2.fromOffset(48, 224)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	local function button(text: string, order: number, onTap: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(48, 48)
		btn.BackgroundColor3 = Color3.fromRGB(55, 42, 38)
		btn.BackgroundTransparency = 0.25
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 22
		btn.TextColor3 = Color3.fromRGB(255, 246, 232)
		btn.Text = text
		btn.LayoutOrder = order
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn
		btn.Activated:Connect(onTap)
		btn.Parent = holder
		return btn
	end

	button("⟲", 1, function()
		rotate(1)
	end)
	button("⟳", 2, function()
		rotate(-1)
	end)
	button("＋", 3, function()
		zoomBy(-10)
	end)
	button("－", 4, function()
		zoomBy(10)
	end)
end

function CameraController.Start(_self: any)
	local camera = workspace.CurrentCamera
	buildTouchControls()

	-- Start the camera on the FRONT side of your own café (row-1 plots face +Z).
	task.spawn(function()
		for _ = 1, 60 do
			local origin = player:GetAttribute("PlotOrigin")
			if typeof(origin) == "CFrame" then
				if origin.LookVector.Z > 0.5 then
					yawIndex = 3 -- 45°: the front-left view for rotated plots
					targetYaw = math.rad(YAWS[yawIndex])
					currentYaw = targetYaw
				end
				return
			end
			task.wait(0.5)
		end
	end)

	-- Two-finger pinch zoom on touch devices.
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
			yawIndex = (yawIndex % #YAWS) + 1
			targetYaw = math.rad(YAWS[yawIndex])
		elseif input.KeyCode == Enum.KeyCode.E then
			yawIndex = ((yawIndex - 2) % #YAWS) + 1
			targetYaw = math.rad(YAWS[yawIndex])
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			targetZoom = math.clamp(targetZoom - input.Position.Z * 7, ZOOM_MIN, ZOOM_MAX)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		camera.CameraType = Enum.CameraType.Scriptable

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			focus = focus:Lerp(hrp.Position + Vector3.new(0, 1, 0), math.min(dt * 8, 1))
		end

		currentYaw += shortestAngle(currentYaw, targetYaw) * math.min(dt * 7, 1)
		zoom += (targetZoom - zoom) * math.min(dt * 8, 1)

		local dir = Vector3.new(
			math.sin(currentYaw) * math.cos(ELEVATION),
			math.sin(ELEVATION),
			math.cos(currentYaw) * math.cos(ELEVATION)
		)
		local cameraPos = focus + dir * zoom
		camera.CFrame = CFrame.lookAt(cameraPos, focus)

		updateWallFades(cameraPos)
	end)
end

return CameraController
