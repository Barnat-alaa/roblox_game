--!strict
-- Neighbourhood layout constants. plotCount is THE lobby-capacity knob:
-- Roblox fills servers to Max Players (set on the dashboard) and every player
-- gets one plot, so keep Max Players <= plotCount. Launch tuning: 24 plots /
-- 30 max players is wrong — keep Max Players at or below plotCount (30 → 24
-- means 6 players could go plotless; dashboard is set to 30, so plotCount 30).
local World = {
	plotCount = 30, -- total cafés per server (two facing rows)
	plotsPerRow = 15, -- cafés per street side
	boulevardWidth = 60, -- studs between the two facing rows
}

return World
