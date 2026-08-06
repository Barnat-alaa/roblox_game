--!strict
-- Player-to-player communication.
--
-- OWNER DECISION 2026-08-05: Roblox chat stays **ON**. The original plan
-- (HANDOFF §1) called for no free-text chat between players, whitelisted
-- compliments only. The owner reviewed that and chose to keep Roblox's own chat,
-- which is a legitimate call — Roblox's text filter, reporting tools and
-- parental controls apply to it, and it is the communication channel players
-- already expect.
--
-- Keeping the switch here (rather than deleting CommsController) means the
-- decision is one line to reverse, and it is written down instead of implied by
-- absent code.
--
-- ⚠️ This flag only controls the in-experience UI. The AUTHORITATIVE control is
-- the experience's Communication setting on the Creator Dashboard. If chat is
-- disabled there, it is off regardless of what this says.
local Comms = {
	-- true → CommsController hides Roblox's chat window and bubble chat.
	-- false → leave Roblox chat exactly as it ships (current owner choice).
	hideRobloxChat = false,
}

return Comms
