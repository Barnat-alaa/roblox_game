--!strict
-- Optional switch for Roblox's own chat, gated on `Config/Comms.hideRobloxChat`.
--
-- OWNER DECISION 2026-08-05: the flag is **false** — chat stays on. The original
-- plan (HANDOFF §1) called for no free-text chat between players; the owner
-- reviewed that and chose to keep Roblox chat, which carries Roblox's own text
-- filter, reporting and parental controls. This controller therefore does
-- nothing today. It is kept, wired and tested so the decision is one line to
-- reverse instead of a feature to rebuild.
--
-- ⚠️ EVEN WHEN ENABLED THIS IS NOT THE ENFORCEMENT POINT. Removing the UI stops
-- this client showing or sending chat; it does not stop Roblox routing messages
-- between players. The authoritative switch is the experience's Communication
-- setting on the Creator Dashboard.
--
-- Two layers are needed, which the pre-launch pass established by measurement:
-- `SetCoreGuiEnabled(Chat, false)` flipped the CoreGui flag but left the legacy
-- `Chat` ScreenGui in PlayerGui still rendering, so the ScreenGui itself has to
-- be disabled too. `ScreenGui.Enabled` is the real gate — a descendant's
-- `Visible` stays true underneath it and means nothing on its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Comms = require(ReplicatedStorage:WaitForChild("Shared").Config.Comms)

local CommsController = {}
CommsController.Name = "CommsController"

-- Roblox's own chat GUIs. Our NPC speech bubbles are built by NpcAnimator under
-- each Head, not by BubbleChat, so switching these off costs the game nothing.
local CHAT_GUIS = { Chat = true, BubbleChat = true }

local function silenceCoreGui()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)
end

-- Inert while ChatVersion is LegacyChatService, but free to set and it covers
-- the place being migrated to TextChatService later.
local function silenceTextChatService()
	pcall(function()
		for _, className in
			{ "ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration" }
		do
			local config = TextChatService:FindFirstChildOfClass(className)
			if config then
				(config :: any).Enabled = false
			end
		end
	end)
end

local function silenceGui(instance: Instance)
	if CHAT_GUIS[instance.Name] and instance:IsA("ScreenGui") then
		pcall(function()
			instance.Enabled = false
		end)
	end
end

function CommsController.Start(_self: any)
	-- Owner decision 2026-08-05: chat stays on, so this controller does nothing
	-- unless the flag is flipped. See Config/Comms for the reasoning.
	if not Comms.hideRobloxChat then
		return
	end
	silenceCoreGui()
	silenceTextChatService()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		silenceGui(child)
	end
	-- The legacy chat GUI is created after our controllers start, so catching it
	-- on arrival is what actually makes this stick on a cold join.
	playerGui.ChildAdded:Connect(silenceGui)

	-- Re-assert across the CoreGui boot window, then stop — a permanent loop
	-- would fight anything that legitimately wants the top bar later.
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.5)
			silenceCoreGui()
			silenceTextChatService()
			for _, child in playerGui:GetChildren() do
				silenceGui(child)
			end
		end
	end)
end

return CommsController
