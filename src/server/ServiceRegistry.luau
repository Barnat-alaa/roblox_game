--!strict
-- Minimal service locator. Main registers every service here during boot so
-- services can resolve each other in :Init() without circular require chains.

local ServiceRegistry = {}

local services: { [string]: any } = {}

function ServiceRegistry.set(name: string, service: any)
	services[name] = service
end

function ServiceRegistry.get(name: string): any
	local service = services[name]
	assert(service, "ServiceRegistry: unknown service '" .. name .. "'")
	return service
end

return ServiceRegistry
