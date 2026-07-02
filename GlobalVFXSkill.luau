local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFXEvent = ReplicatedStorage:WaitForChild("VFXSkillEvent")
local debris = game:GetService("Debris")

VFXEvent.OnServerEvent:Connect(function(player, vfxName, targetCFrame)
	print("1. Event received from:", player.Name, "| VFX Request:", vfxName)

	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX") 
		and ReplicatedStorage.VFX:FindFirstChild("Weapon") 
		and ReplicatedStorage.VFX.Weapon:FindFirstChild("Scythe")

	print("2. Folder located:", vfxFolder ~= nil)

	local vfxTemplate = vfxFolder and vfxFolder:FindFirstChild(vfxName)
	print("3. Template resolved:", vfxTemplate ~= nil)

	if vfxTemplate then
		local activeVFX = vfxTemplate:Clone()

		
	
		activeVFX.CFrame = targetCFrame
	

		activeVFX.Parent = workspace

		task.wait(0.05)
		for _, child in ipairs(activeVFX:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child:Emit(1)
			end
		end

		debris:AddItem(activeVFX, 2)
	end
end)