--!strict
-- Client entry point. Mirrors the server: load Controllers/, Init then Start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)

local controllersFolder = script.Parent:WaitForChild("Controllers")

local controllers: { any } = {}
for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, controller = pcall(require, module)
		if ok and typeof(controller) == "table" then
			controller.Name = controller.Name or module.Name
			table.insert(controllers, controller)
		else
			Log.warn("Failed to require controller", module.Name, controller)
		end
	end
end

for _, controller in controllers do
	if typeof(controller.Init) == "function" then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			Log.warn("Controller Init failed:", controller.Name, err)
		end
	end
end

for _, controller in controllers do
	if typeof(controller.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				Log.warn("Controller Start failed:", controller.Name, err)
			end
		end)
	end
end

Log.info("Client booted with", #controllers, "controllers")
