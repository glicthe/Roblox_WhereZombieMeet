local ReplicatedStorage = game:GetService('ReplicatedStorage')

local vfxEvent = ReplicatedStorage.VFX:WaitForChild('VFXEvent')

vfxEvent.OnServerEvent:Connect(function(player, name, spawnType, char, extra)
	if spawnType == 'All' then
		vfxEvent:FireAllClients(name, char, extra)
	elseif spawnType == 'Single' then
		vfxEvent:FireClient(player, name, char, extra)
	end
	
	if spawnType == 'Respawn' then
		extra:LoadCharacter()
	end
end)

