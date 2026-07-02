-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

-- Objects
local Motor6D = {}
local Char = script.Parent.Parent

function PlaySound(Audio, Target)
	local Sound = Audio:Clone()
	Sound.Parent = Target
	Sound:Play()
	Debris:AddItem(Sound,Sound.TimeLength+1)
end

Char.ChildAdded:Connect(function(Tool)
	if Tool:IsA("Tool") and Tool:GetAttribute("Weapon") then
		print(ReplicatedStorage.Weapons[Tool.Name])
		PlaySound(SoundService.Weapons[Tool.Name].Equip,Char:FindFirstChild("HumanoidRootPart"))
		local HandleL = ReplicatedStorage.Weapons[Tool.Name]:FindFirstChild("HandleL")
		if HandleL then
			local HandleL = HandleL:Clone()
			HandleL.Parent = Char

			local LArm = Char:FindFirstChild("Left Arm")
			local Grip = Instance.new("Motor6D")
			Grip.Parent = LArm
			Grip.Part0 = LArm
			Grip.Part1 = HandleL
			Grip.C0 = HandleL.Grip.C0
			Grip.C1 = HandleL.Grip.C1
			Grip.Name = "LeftGrip"
			Motor6D["L"] = Grip
		end
		local HandleR = ReplicatedStorage.Weapons[Tool.Name]:FindFirstChild("HandleR")
		if HandleR then
			local HandleR = HandleR:Clone()
			HandleR.Parent = Char

			local RArm = Char:FindFirstChild("Right Arm")
			local Grip = Instance.new("Motor6D")
			Grip.Parent = RArm
			Grip.Part0 = RArm
			Grip.Part1 = HandleR
			Grip.C0 = HandleR.Grip.C0
			Grip.C1 = HandleR.Grip.C1
			Grip.Name = "RightGrip"
			Motor6D["R"] = Grip
		end
	end
end)

Char.ChildRemoved:Connect(function(Tool)
	if Tool:IsA("Tool") and Tool:GetAttribute("Weapon") then
		PlaySound(SoundService.Weapons[Tool.Name].Unequip,Char:FindFirstChild("HumanoidRootPart"))
		for _,v in pairs(Motor6D) do
			v:Destroy()
		end
		for _,v in pairs(Char:GetChildren()) do
			if v.Name == "HandleR" or v.Name == "HandleL" then
				v:Destroy()
			end
		end
	end
end)