local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local sound = script:WaitForChild("WindSfx")

-- Set the speed threshold
local speedThreshold = 30  -- Adjust as needed

-- Reference the player's camera
local camera = game.Lighting
local blurEffect = camera.VelocityBlur

-- Create a function to check speed, play wind sound, and apply blur
local function checkSpeedAndPlaySound()
	-- Get the actual velocity using AssemblyLinearVelocity
	local velocity = rootPart.AssemblyLinearVelocity
	local speed = velocity.Magnitude

	if speed > speedThreshold then
		local targetVolume = math.min((speed - speedThreshold) / 50, 1)
		local targetBlurSize = math.min((speed - speedThreshold) / 50, 15)

		game.TweenService:Create(sound, TweenInfo.new(0.3), { Volume = targetVolume }):Play()
		game.TweenService:Create(blurEffect, TweenInfo.new(0.1), { Size = targetBlurSize * 4 }):Play()

		sound:Resume()
	else
		game.TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
		game.TweenService:Create(blurEffect, TweenInfo.new(0.1), { Size = 0 }):Play()
	end
end

-- Connect the function to RenderStepped
game:GetService("RunService").RenderStepped:Connect(checkSpeedAndPlaySound)