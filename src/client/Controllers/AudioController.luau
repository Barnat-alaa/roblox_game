--!strict
-- Client audio (§33): licensed SFX + a calm music loop, with volumes driven
-- by the profile's settings (musicVolume / sfxVolume). Other controllers can
-- call AudioController.play("name") for interaction sounds; common game
-- events (order arrives, serve) are wired here directly off the remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local Remotes = require(Shared.Network.Remotes)

local UIController = require(script.Parent.UIController)

local AudioController = {}
AudioController.Name = "AudioController"

local sfxVolume = 0.8
local sounds: { [string]: Sound } = {}
local music: Sound? = nil

function AudioController.play(name: string)
	local sound = sounds[name]
	local def = (Audio.sfx :: any)[name]
	if sound and def then
		sound.Volume = def.volume * sfxVolume
		sound:Play()
	end
end

function AudioController.Start(_self: any)
	for name, def in Audio.sfx :: { [string]: { id: number, volume: number } } do
		local sound = Instance.new("Sound")
		sound.Name = "SFX_" .. name
		sound.SoundId = "rbxassetid://" .. def.id
		sound.Volume = def.volume * sfxVolume
		sound.Parent = SoundService
		sounds[name] = sound
	end

	local track = Instance.new("Sound")
	track.Name = "Music"
	track.SoundId = "rbxassetid://" .. Audio.music.id
	track.Looped = true
	track.Volume = Audio.music.volume
	track.Parent = SoundService
	track:Play()
	music = track

	-- Volumes follow the profile settings (0..1 sliders, §33).
	UIController.subscribeProfile(function(profile)
		local settings = profile and profile.settings
		if typeof(settings) == "table" then
			sfxVolume = math.clamp(tonumber(settings.sfxVolume) or 0.8, 0, 1)
			if music then
				music.Volume = Audio.music.volume
					* math.clamp(tonumber(settings.musicVolume) or 0.6, 0, 1)
			end
		end
	end)

	Remotes.event("OrderCreated").OnClientEvent:Connect(function()
		AudioController.play("bell")
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(msg: any)
		if typeof(msg) == "table" and msg.kind == "served" then
			AudioController.play("serve")
		end
	end)
end

return AudioController
