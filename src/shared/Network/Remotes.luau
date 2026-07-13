--!strict
-- Single source of truth for remote names. The server creates the objects
-- (Remotes.init); both sides fetch them by name. Every handler must still
-- validate its payload — see docs/SECURITY.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

-- client -> server, and server -> client, events
local EVENTS = {
	"PlaceFurniture", -- c->s: request a placement
	"RemoveFurniture", -- c->s: pick up a placed item
	"PurchaseItem", -- c->s: buy a catalogue item with coins
	"StartCooking", -- c->s: begin a manual brew for an order (server starts its clock)
	"FinishCooking", -- c->s: stop the brew bar (server judges the timing)
	"ClaimOrder", -- c->s: serve a completed order
	"CompleteTutorialStep", -- c->s: onboarding progress
	"VisitCafe", -- c->s: request to visit another plot
	"ProfileUpdated", -- s->c: full PlayerData snapshot
	"Notify", -- s->c: toast / error feedback
	"OrderCreated", -- s->c: a customer placed an order
}

local FUNCTIONS = {
	"RequestProfile", -- c->s: fetch current PlayerData once
}

local function ensureFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for _, name in EVENTS do
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
		for _, name in FUNCTIONS do
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server calls this once at boot so remotes exist before any client asks.
function Remotes.init()
	ensureFolder()
end

function Remotes.event(name: string): RemoteEvent
	return ensureFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return ensureFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
