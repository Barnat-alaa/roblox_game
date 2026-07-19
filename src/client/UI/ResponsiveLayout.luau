--!strict

local ResponsiveLayout = {}

export type Mode = "Phone" | "Compact" | "Desktop"

function ResponsiveLayout.mode(viewport: Vector2?): Mode
	local size = viewport
		or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)
		or Vector2.new(1280, 720)
	-- Social Cafe is landscape-first. A short landscape viewport is compact, not a
	-- portrait phone: treating height alone as "Phone" made every drawer full width.
	if size.X < 600 or (size.X < 700 and size.X < size.Y) then
		return "Phone"
	elseif size.X < 1100 or size.Y < 620 then
		return "Compact"
	end
	return "Desktop"
end

function ResponsiveLayout.isPhone(viewport: Vector2?): boolean
	return ResponsiveLayout.mode(viewport) == "Phone"
end

function ResponsiveLayout.isCompact(viewport: Vector2?): boolean
	return ResponsiveLayout.mode(viewport) ~= "Desktop"
end

function ResponsiveLayout.panelSize(desktopWidth: number, desktopHeight: number): UDim2
	if ResponsiveLayout.isPhone() then
		return UDim2.new(1, -20, 0.76, 0)
	end
	return UDim2.fromOffset(desktopWidth, desktopHeight)
end

function ResponsiveLayout.panelPosition(desktopX: number?): UDim2
	if ResponsiveLayout.isPhone() then
		return UDim2.new(0.5, 0, 1, -10)
	end
	return UDim2.new(0.5, desktopX or 0, 0.5, 0)
end

function ResponsiveLayout.watch(callback: (Mode, Vector2) -> ()): RBXScriptConnection?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local function fire()
		callback(ResponsiveLayout.mode(camera.ViewportSize), camera.ViewportSize)
	end
	fire()
	return camera:GetPropertyChangedSignal("ViewportSize"):Connect(fire)
end

return ResponsiveLayout
