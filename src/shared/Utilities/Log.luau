--!strict
-- Tiny prefixed logger so every message is greppable in Output.

local Log = {}
local PREFIX = "[SocialCafe]"

function Log.info(...: any)
	print(PREFIX, ...)
end

function Log.warn(...: any)
	warn(PREFIX, ...)
end

return Log
