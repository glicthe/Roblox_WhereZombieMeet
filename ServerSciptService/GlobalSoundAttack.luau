local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local soundEvent = ReplicatedStorage:WaitForChild("GlobalSoundEvent")

soundEvent.OnServerEvent:Connect(function(player, soundId, targetPart, volume, playbackSpeed)
	if not targetPart then return end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1
	sound.PlaybackSpeed = playbackSpeed or 1

	-- Spatial audio requires attachment to a physical BasePart
	sound.Parent = targetPart
	sound:Play()

	-- Automatic memory cleanup factoring dynamic track lengths
	Debris:AddItem(sound, sound.TimeLength + 1)
end)