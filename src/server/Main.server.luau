--!strict
-- Server entry point. Loads every ModuleScript under Services/, registers them,
-- then runs a two-phase boot: Init (wire dependencies) → Start (do work).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Network.Remotes)
local ServiceRegistry = require(script.Parent.ServiceRegistry)

-- Create remote objects up front so no client races their creation.
Remotes.init()

local servicesFolder = script.Parent:WaitForChild("Services")

local ordered: { any } = {}
for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, service = pcall(require, module)
		if ok and typeof(service) == "table" then
			service.Name = service.Name or module.Name
			ServiceRegistry.set(service.Name, service)
			table.insert(ordered, service)
		else
			Log.warn("Failed to require service", module.Name, service)
		end
	end
end

-- Init phase: synchronous, resolves cross-service references.
for _, service in ordered do
	if typeof(service.Init) == "function" then
		local ok, err = pcall(service.Init, service)
		if not ok then
			Log.warn("Init failed:", service.Name, err)
		end
	end
end

-- Start phase: each service runs in its own thread so a slow Start can't block others.
for _, service in ordered do
	if typeof(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				Log.warn("Start failed:", service.Name, err)
			end
		end)
	end
end

Log.info("Server booted with", #ordered, "services")
