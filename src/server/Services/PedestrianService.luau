--!strict
-- Permanent ambient crowd on the boulevard. A fixed cast of NPCs walks the two
-- sidewalks for the whole life of the server, and some of them wander into any
-- OPEN café — every claimed plot, not just the local player's.
--
-- Two deliberate differences from CustomerService:
--
--   1. These are set dressing only. They never queue, order, tip, or touch
--      satisfaction/Buzz, and they live in their own workspace.Pedestrians
--      folder so nothing that scans Customers/Staff picks them up.
--   2. Street movement uses a DIRECT Humanoid:MoveTo along a lane from
--      Utilities/StreetMath — deliberately NOT PathfindingService. The navmesh
--      is happy to route an NPC diagonally across the road, which breaks the
--      "sidewalks only" requirement. Pathfinding is used only once a pedestrian
--      is inside a café, where it has to route around furniture.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Pedestrians = require(Shared.Config.Pedestrians)
local World = require(Shared.Config.World)
local Log = require(Shared.Utilities.Log)
local StreetMath = require(Shared.Utilities.StreetMath)

local ServiceRegistry = require(script.Parent.Parent.ServiceRegistry)
local NpcAnimator = require(script.Parent.Parent.NpcAnimator)
local NpcNav = require(script.Parent.Parent.NpcNav)

local PedestrianService = {}
PedestrianService.Name = "PedestrianService"

local CafeService: any
local AssetLibraryService: any

local rng = Random.new()

type Ped = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	side: number, -- 0 = sidewalk A (row 0), 1 = sidewalk B (row 1)
	laneZ: number,
	dir: number, -- +1 / -1 along X
	baseHip: number,
	anim: NpcAnimator.AnimHandle?,
	indoors: boolean, -- suspends the keep-on-the-pavement clamp
}

local folder: Folder
-- Ambient bodies currently inside each plot, so one café can't swallow the
-- whole crowd while real customers are trying to use it.
local visitors: { [number]: number } = {}

-- ————— models —————

-- Minimal walker used only when the rig library has nothing to clone. Real
-- Creator Store rigs are the normal path (AssetLibrary loads ~57 templates).
local function buildFallback(name: string): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Color = Color3.fromRGB(88, 104, 148)
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = Color3.fromRGB(233, 195, 162)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CFrame = root.CFrame * CFrame.new(0, 1.7, 0)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HipHeight = 1
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, humanoid, root
end

-- Always returns a usable walker: a real rig when the library has one, else the
-- fallback block figure.
local function buildPedestrian(index: number): (Model, Humanoid, BasePart)
	local rig: Model? = if AssetLibraryService then AssetLibraryService:GetCustomerRig() else nil
	if rig then
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root then
			rig.Name = "Pedestrian_" .. index
			humanoid.BreakJointsOnDeath = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			rig.PrimaryPart = root
			return rig, humanoid, root
		end
		rig:Destroy()
	end
	return buildFallback("Pedestrian_" .. index)
end

-- ————— movement —————

-- Walk straight to `point` with no navmesh. Returns true on arrival. Every tick
-- re-checks that physics (a player shove, a bumped decor prop) has not pushed
-- the NPC off its pavement, and snaps it back if so — this is the hard
-- guarantee behind "sidewalks only".
local function stepTo(ped: Ped, point: Vector3, timeout: number?): boolean
	local deadline = os.clock() + (timeout or Pedestrians.legTimeoutSeconds)
	while true do
		if ped.root.Parent == nil then
			return false
		end
		local pos = ped.root.Position
		if ((pos - point) * Vector3.new(1, 0, 1)).Magnitude < 3 then
			return true
		end
		if os.clock() > deadline then
			return false
		end
		if not ped.indoors and not StreetMath.onSidewalk(ped.side, pos.Z) then
			local fixed = StreetMath.clampToLane(ped.side, pos, ped.laneZ)
			ped.model:PivotTo(CFrame.new(fixed + Vector3.new(0, 2, 0)))
		end
		ped.humanoid:MoveTo(point)
		task.wait(0.15)
	end
end

local function lanePoint(ped: Ped, x: number): Vector3
	return Vector3.new(StreetMath.clampX(x), ped.root.Position.Y, ped.laneZ)
end

-- One stroll along the pavement. Reverses at the ends of the street.
local function walkLeg(ped: Ped)
	local loX, hiX = StreetMath.walkXBounds()
	local distance = rng:NextNumber(Pedestrians.legStudsMin, Pedestrians.legStudsMax)
	local targetX = ped.root.Position.X + ped.dir * distance
	if targetX <= loX or targetX >= hiX then
		ped.dir = -ped.dir
		targetX = ped.root.Position.X + ped.dir * distance
	end
	stepTo(ped, lanePoint(ped, targetX))
end

-- ————— café visits —————

local function doorApproach(origin: CFrame): Vector3
	local doorX = StreetMath.plotWidth() * World.doorCenterFrac
	-- Local Z -8 is the street point directly outside the door. For BOTH rows
	-- this lands inside that side's pedestrian lane, so walking to it never
	-- leaves the pavement. Y 2 matches the height CustomerService feeds the
	-- navmesh with.
	return (origin * CFrame.new(doorX, 2, -8)).Position
end

-- An OPEN café is a claimed plot (unowned plots are shuttered and read CLOSED).
-- Only cafés fronting this pedestrian's own sidewalk are eligible — anything
-- else would mean crossing the road.
local function pickOpenCafe(ped: Ped): (number?, CFrame?)
	local candidates: { { index: number, origin: CFrame } } = {}
	local myX = ped.root.Position.X
	for index = 1, World.plotCount do
		if StreetMath.sideForPlotIndex(index) == ped.side then
			local origin, ownerUserId = CafeService:GetPlotInfo(index)
			local busy = visitors[index] or 0
			if origin and ownerUserId and busy < Pedestrians.maxVisitorsPerCafe then
				local approach = doorApproach(origin)
				if math.abs(approach.X - myX) <= Pedestrians.visitSearchStuds then
					table.insert(candidates, { index = index, origin = origin })
				end
			end
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	return pick.index, pick.origin
end

local function visitCafe(ped: Ped, index: number, origin: CFrame)
	visitors[index] = (visitors[index] or 0) + 1

	local approach = doorApproach(origin)
	local inside = (origin * CFrame.new(
		StreetMath.plotWidth() * World.doorCenterFrac,
		2,
		Pedestrians.insideDepthStuds
	)).Position

	-- Along the lane to the door's X, then square up to the doorway. Both legs
	-- stay on the pavement.
	stepTo(ped, lanePoint(ped, approach.X))
	stepTo(ped, Vector3.new(approach.X, ped.root.Position.Y, approach.Z))

	-- Inside, hand over to the shared navmesh walk so furniture is routed around.
	ped.indoors = true
	local opts = { baseHip = ped.baseHip, straightTimeout = 10 }
	NpcNav.walkTo(ped.model, ped.humanoid, ped.root, inside, opts)
	task.wait(rng:NextNumber(Pedestrians.lingerSecondsMin, Pedestrians.lingerSecondsMax))
	NpcNav.walkTo(ped.model, ped.humanoid, ped.root, approach, opts)
	ped.indoors = false

	-- Rejoin the walking lane before resuming the stroll.
	stepTo(ped, lanePoint(ped, ped.root.Position.X))

	visitors[index] = math.max(0, (visitors[index] or 1) - 1)
end

-- ————— lifecycle —————

local function run(ped: Ped)
	while ped.root.Parent ~= nil do
		if rng:NextNumber() < Pedestrians.pauseChance then
			ped.humanoid:MoveTo(ped.root.Position)
			task.wait(rng:NextNumber(Pedestrians.pauseSecondsMin, Pedestrians.pauseSecondsMax))
		end

		if rng:NextNumber() < Pedestrians.visitChance then
			local index, origin = pickOpenCafe(ped)
			if index and origin then
				visitCafe(ped, index, origin)
				continue
			end
		end

		walkLeg(ped)
	end
end

local function spawnPedestrian(index: number)
	local model, humanoid, root = buildPedestrian(index)

	local side = index % 2
	local laneZ = StreetMath.laneZ(side, rng:NextNumber(0.15, 0.85))
	local loX, hiX = StreetMath.walkXBounds()

	humanoid.WalkSpeed = Pedestrians.walkSpeed
	model:PivotTo(CFrame.new(Vector3.new(rng:NextNumber(loX, hiX), 3, laneZ)))
	model.Parent = folder
	NpcNav.assignNpcGroup(model)

	local ped: Ped = {
		model = model,
		humanoid = humanoid,
		root = root,
		side = side,
		laneZ = laneZ,
		dir = if rng:NextNumber() < 0.5 then -1 else 1,
		baseHip = humanoid.HipHeight,
		anim = NpcAnimator.setup(humanoid),
		indoors = false,
	}
	task.spawn(run, ped)
end

function PedestrianService.Init(_self: any)
	CafeService = ServiceRegistry.get("CafeService")
	AssetLibraryService = ServiceRegistry.get("AssetLibraryService")
end

function PedestrianService.Start(_self: any)
	folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = workspace

	-- Wait for the rig templates so the crowd spawns as real clothed NPCs
	-- rather than a street full of the fallback blocks.
	local function populate()
		for index = 1, Pedestrians.count do
			spawnPedestrian(index)
			task.wait(Pedestrians.spawnStaggerSeconds)
		end
		Log.info("PedestrianService: ambient crowd of", Pedestrians.count, "walking the boulevard")
	end

	if AssetLibraryService then
		AssetLibraryService:OnReady(populate)
	else
		task.spawn(populate)
	end
end

return PedestrianService
