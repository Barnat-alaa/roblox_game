--!strict
-- Plays Roblox's default walk/idle animations on server-driven NPC Humanoids so
-- real rigs stop sliding. The animation assets are Roblox-owned (free to use on
-- platform) and chosen by rig type. Procedural part-rigs (no standard Torso/
-- LowerTorso, so no matching Motor6D joints) are skipped — they keep the
-- HipHeight waddle. Tracks self-clean when the Humanoid is destroyed.

local NpcAnimator = {}

export type AnimHandle = {
	-- Seated NPCs must stop the walk cycle (anchoring the root mid-walk left
	-- the legs pedalling in place — owner bug report 2026-07-16).
	setSeated: (seated: boolean) -> (),
}

local ANIMS = {
	R6 = { idle = "rbxassetid://180435571", walk = "rbxassetid://180426354" },
	R15 = { idle = "rbxassetid://507766388", walk = "rbxassetid://507777826" },
}

function NpcAnimator.setup(humanoid: Humanoid): AnimHandle?
	local char = humanoid.Parent
	if not char then
		return nil
	end
	-- Only real avatar rigs have these; procedural part-rigs would no-op.
	if not (char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) then
		return nil
	end

	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local ids = if isR15 then ANIMS.R15 else ANIMS.R6

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local function track(id: string): AnimationTrack?
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, t = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if ok and t then
			t.Looped = true
			return t
		end
		return nil
	end

	local idle = track(ids.idle)
	local walk = track(ids.walk)

	local seated = false
	local current: boolean? = nil
	local function setMoving(moving: boolean)
		if moving == current then
			return
		end
		current = moving
		if moving then
			if idle then
				idle:Stop(0.15)
			end
			if walk then
				walk:Play(0.15)
			end
		else
			if walk then
				walk:Stop(0.15)
			end
			if idle then
				idle:Play(0.15)
			end
		end
	end

	setMoving(false)
	humanoid.Running:Connect(function(speed)
		if not seated then
			setMoving(speed > 0.5)
		end
	end)

	return {
		setSeated = function(isSeated: boolean)
			seated = isSeated
			if isSeated then
				-- Force the calm pose regardless of the last Running event —
				-- an anchored root never fires Running(0).
				current = nil
				setMoving(false)
			end
		end,
	}
end

return NpcAnimator
