--!strict
-- Free-text chat is OFF (HANDOFF §1 — an ABSOLUTE rail: "no free-text between
-- players (whitelisted compliments only)"). Found live on 2026-08-05 during the
-- pre-launch pass: the Roblox chat window and bubble chat were both present in
-- PlayerGui, rendering, and nothing in the codebase had ever turned them off.
--
-- ⚠️ THIS IS DEFENCE IN DEPTH, NOT THE ENFORCEMENT POINT. Removing the UI stops
-- this client showing or sending chat; it does not stop Roblox routing messages
-- between players. The authoritative switch is the experience's Communication
-- setting on the Creator Dashboard, which must ALSO be off. This controller
-- exists so a dashboard setting that is missed, reset, or overridden by a future
-- Roblox default cannot silently re-open free text inside the game.
--
-- Two layers are needed, which the pre-launch pass established by measurement:
-- `SetCoreGuiEnabled(Chat, false)` flipped the CoreGui flag but left the legacy
-- `Chat` ScreenGui in PlayerGui still rendering, so the ScreenGui itself has to
-- be disabled too. `ScreenGui.Enabled` is the real gate — a descendant's
-- `Visible` stays true underneath it and means nothing on its own.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

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
