-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Player Stuffs
local Plr = game.Players.LocalPlayer
local Char = Plr.Character
local Hum = Char:FindFirstChildOfClass("Humanoid")

-- Variables
local EquipAnim
local IdleAnim
local CurrentWeapon

Char.ChildAdded:Connect(function(Tool)
	if Tool:IsA("Tool") and Tool:GetAttribute("Weapon") then
		CurrentWeapon = Tool:GetAttribute("Weapon")
		local AnimPath = ReplicatedStorage.Animations.Weapons:FindFirstChild(CurrentWeapon)
		IdleAnim = Hum.Animator:LoadAnimation(AnimPath.Idle)
		if Tool.Parent == Char then
			IdleAnim:Play()
		end
	end
end)

Char.ChildRemoved:Connect(function(Tool)
	if Tool:IsA("Tool") and Tool:GetAttribute("Weapon") then
		
	end
end)