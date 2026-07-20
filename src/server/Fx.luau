--!strict
-- Tiny server-side juice helpers (Phase 2): coin bursts and floating text.
-- Server-spawned so every player sees the café hum; volumes are small
-- (a handful of parts per event, self-destroying) so replication stays cheap.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Fx = {}

local rng = Random.new()

-- Floating "+6 🪙" style text that drifts up and fades.
function Fx.floatText(position: Vector3, text: string, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 1.1)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.fromRGB(255, 215, 120)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui

	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.2)
end

-- A broom sweeping a spill in place + a burst of clean sparkles. Used by both
-- the cleaner and the owner so cleaning READS as scrubbing (owner request:
-- show a broom, don't carry the dirt away). Self-destroys after ~`seconds`.
function Fx.scrub(position: Vector3, seconds: number?)
	local duration = seconds or 1.4

	local broom = Instance.new("Model")
	broom.Name = "ScrubBroom"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.16, 3, 0.16)
	handle.Color = Color3.fromRGB(155, 112, 70)
	handle.Material = Enum.Material.Wood
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Parent = broom
	local bristles = Instance.new("Part")
	bristles.Name = "Bristles"
	bristles.Size = Vector3.new(1.2, 0.75, 0.35)
	bristles.Color = Color3.fromRGB(214, 182, 120)
	bristles.Material = Enum.Material.SmoothPlastic
	bristles.Anchored = true
	bristles.CanCollide = false
	bristles.CanQuery = false
	bristles.Parent = broom
	broom.PrimaryPart = handle

	local sparkleAnchor = Instance.new("Part")
	sparkleAnchor.Anchored = true
	sparkleAnchor.CanCollide = false
	sparkleAnchor.CanQuery = false
	sparkleAnchor.Transparency = 1
	sparkleAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	sparkleAnchor.Position = position + Vector3.new(0, 0.3, 0)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(180, 245, 210))
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.Lifetime = NumberRange.new(0.5, 0.9)
	sparkles.Rate = 24
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = sparkleAnchor
	sparkleAnchor.Parent = workspace

	broom.Parent = workspace
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local phase = (os.clock() - t0) * 10
			local sweep = math.sin(phase) * 1.1
			local head = position + Vector3.new(sweep, 0.25, 0)
			bristles.CFrame = CFrame.new(head)
			handle.CFrame = CFrame.new(head + Vector3.new(0.5, 1.6, 0.4))
				* CFrame.Angles(math.rad(35), 0, math.rad(-18))
			task.wait(0.04)
		end
		broom:Destroy()
		sparkles.Enabled = false
		Debris:AddItem(sparkleAnchor, 1)
	end)
end

-- A quick shower of little gold coins.
function Fx.coinBurst(position: Vector3, count: number?)
	for _ = 1, math.clamp(count or 6, 1, 10) do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.12, 0.7, 0.7)
		coin.Color = Color3.fromRGB(240, 195, 80)
		coin.Material = Enum.Material.Metal
		coin.CanCollide = false
		coin.CanQuery = false
		coin.Massless = true
		coin.CFrame = CFrame.new(position)
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
		coin.AssemblyLinearVelocity =
			Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(12, 20), rng:NextNumber(-8, 8))
		coin.Parent = workspace
		Debris:AddItem(coin, 1.1)
	end
end

return Fx
