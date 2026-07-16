--!strict
-- Shared NPC ground navigation (customers + staff): PathfindingService route
-- around collidable furniture/walls, straight-line MoveTo fallback when no
-- path exists, per-leg deadlines with a teleport-to-goal last resort so nobody
-- blocks a queue forever. The classic chibi waddle (HipHeight bob) rides along;
-- real rigs are animated by NpcAnimator instead (the bob is invisible on them
-- at 0.14 studs but keeps the code path identical).

local PathfindingService = game:GetService("PathfindingService")

local NpcNav = {}

export type WalkOptions = {
	baseHip: number,
	-- Return true to abort the walk (e.g. the customer started leaving).
	cancelled: (() -> boolean)?,
	legTimeout: number?, -- seconds allowed per waypoint leg
	straightTimeout: number?, -- seconds allowed for the no-path fallback
}

local function isGone(root: BasePart): boolean
	return root.Parent == nil
end

-- Drive toward one point; returns "arrived" | "timeout" | "cancelled" | "gone".
local function moveToward(
	humanoid: Humanoid,
	root: BasePart,
	point: Vector3,
	deadline: number,
	t0: number,
	opts: WalkOptions
): string
	while true do
		if isGone(root) then
			return "gone"
		end
		if opts.cancelled and opts.cancelled() then
			return "cancelled"
		end
		local flat = (root.Position - point) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 2 then
			return "arrived"
		end
		if os.clock() > deadline then
			return "timeout"
		end
		humanoid:MoveTo(point)
		humanoid.HipHeight = opts.baseHip + 0.14 * math.abs(math.sin((os.clock() - t0) * 9))
		task.wait(0.1)
	end
end

-- Walk a model to `target`. Returns true when it got there on its own legs;
-- false when it was teleported, cancelled, or destroyed. Always restores
-- HipHeight when the model still exists.
function NpcNav.walkTo(
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Vector3,
	opts: WalkOptions
): boolean
	local t0 = os.clock()
	local outcome = "timeout"

	local path = PathfindingService:CreatePath({
		AgentRadius = 1.8,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		outcome = "arrived"
		for i = 2, #waypoints do -- [1] is the current position
			outcome = moveToward(
				humanoid,
				root,
				waypoints[i].Position,
				os.clock() + (opts.legTimeout or 4),
				t0,
				opts
			)
			if outcome ~= "arrived" then
				break
			end
		end
	else
		outcome =
			moveToward(humanoid, root, target, os.clock() + (opts.straightTimeout or 12), t0, opts)
	end

	if outcome == "timeout" and not isGone(root) then
		model:PivotTo(CFrame.new(target + Vector3.new(0, 2, 0)))
	end
	if not isGone(root) then
		humanoid.HipHeight = opts.baseHip
	end
	return outcome == "arrived"
end

return NpcNav
