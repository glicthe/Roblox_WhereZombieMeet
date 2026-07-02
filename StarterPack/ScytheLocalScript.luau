local tool = script.Parent
local player = game.Players.LocalPlayer

tool.Equipped:Connect(function()
	local character = player.Character or player.CharacterAdded:Wait()
	local defaultAnimate = character:WaitForChild("Animate")
	local scytheAnims = character:WaitForChild("HellScytheAnims")
	local humanoid = character:WaitForChild("Humanoid")

	-- Switch controllers
	defaultAnimate.Enabled = false
	scytheAnims.Enabled = true

	-- Kickstart the new script
	humanoid:ChangeState(Enum.HumanoidStateType.Landed)
end)

tool.Unequipped:Connect(function()
	local character = player.Character
	if not character then return end

	local defaultAnimate = character:FindFirstChild("Animate")
	local scytheAnims = character:FindFirstChild("HellScytheAnims")
	local humanoid = character:FindFirstChild("Humanoid")

	-- Switch controllers back
	if scytheAnims then scytheAnims.Enabled = false end
	if defaultAnimate then defaultAnimate.Enabled = true end

	-- Kickstart the default script
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	end
end)