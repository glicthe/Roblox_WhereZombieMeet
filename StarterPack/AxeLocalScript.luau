local tool = script.Parent
local player = game.Players.LocalPlayer

tool.Equipped:Connect(function()
	local character = player.Character or player.CharacterAdded:Wait()
	local defaultAnimate = character:WaitForChild("Animate")
	local axeAnims = character:WaitForChild("AxeAnims")
	local humanoid = character:WaitForChild("Humanoid")

	-- Switch controllers
	defaultAnimate.Enabled = false
	axeAnims.Enabled = true

	-- Kickstart the new script
	humanoid:ChangeState(Enum.HumanoidStateType.Landed)
end)

tool.Unequipped:Connect(function()
	local character = player.Character
	if not character then return end

	local defaultAnimate = character:FindFirstChild("Animate")
	local axeAnims = character:FindFirstChild("AxeAnims")
	local humanoid = character:FindFirstChild("Humanoid")

	-- Switch controllers back
	if axeAnims then axeAnims.Enabled = false end
	if defaultAnimate then defaultAnimate.Enabled = true end

	-- Kickstart the default script
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	end
end)
