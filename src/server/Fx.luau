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
