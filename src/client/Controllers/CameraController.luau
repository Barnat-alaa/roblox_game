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

local zoom = 55
local targetZoom = zoom
local ZOOM_MIN, ZOOM_MAX = 26, 95

local focus = Vector3.new(24, 2, 24)

local WALL_NORMALS: { [string]: Vector3 } = {
	WallLeft = Vector3.new(-1, 0, 0),
	WallRight = Vector3.new(1, 0, 0),
	WallBack = Vector3.new(0, 0, 1),
}

-- Fade any wall whose outward face points at the camera (you see through it).
local function updateWallFades(cameraPos: Vector3)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		for _, child in plot:GetChildren() do
			local normal = WALL_NORMALS[child.Name]
			if normal and child:IsA("BasePart") then
				local toCam = cameraPos - child.Position
				toCam = Vector3.new(toCam.X, 0, toCam.Z)
				local facing = toCam.Magnitude > 0.01 and toCam.Unit:Dot(normal) > 0.35
				child.LocalTransparencyModifier = if facing then 0.92 else 0
			end
		end
	end
end

local function shortestAngle(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

function CameraController.Start(_self: any)
	local camera = workspace.CurrentCamera

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
