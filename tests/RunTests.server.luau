--!strict
-- TestEZ bootstrap. Only present in the TEST place:
--   rojo build test.project.json --output test-build.rbxlx
-- Open that place in Studio (or run it via MCP) and the run prints a full
-- TestEZ report to the Output; it errors loudly if anything fails so smoke
-- pipelines can grep for the failure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

local results = TestEZ.TestBootstrap:run({ ReplicatedStorage.Tests })

if results.failureCount > 0 then
	error(("TestEZ: %d failed / %d passed"):format(results.failureCount, results.successCount))
end
print(("TestEZ: all %d tests passed ✅"):format(results.successCount))
