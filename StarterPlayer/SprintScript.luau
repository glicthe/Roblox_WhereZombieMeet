	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local player = game.Players.LocalPlayer

	local normalSpeed = 16
	local sprintSpeed = 36
	local isSprinting = false
	local loadedTracks = {}

	local function getRunTrack(animator, scriptName)
		if loadedTracks[scriptName] then return loadedTracks[scriptName] end

		local character = player.Character
		local animScript = character:FindFirstChild(scriptName)

		if animScript and animScript:FindFirstChild("run") then
			local animObj = animScript.run:FindFirstChildOfClass("Animation")
			if animObj and animObj.AnimationId ~= "" then
				local sprintAnim = Instance.new("Animation")
				sprintAnim.AnimationId = animObj.AnimationId
				local track = animator:LoadAnimation(sprintAnim)
				track.Priority = Enum.AnimationPriority.Action2
				loadedTracks[scriptName] = track
				return track
			end
		end
		return nil
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isSprinting = true
			local character = player.Character
			if character and character:FindFirstChild("Humanoid") then
				character.Humanoid.WalkSpeed = sprintSpeed
				character:SetAttribute("IsSprinting", true)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isSprinting = false
			local character = player.Character
			if character and character:FindFirstChild("Humanoid") then
				character.Humanoid.WalkSpeed = normalSpeed
				character:SetAttribute("IsSprinting", false)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		local animator = humanoid and humanoid:FindFirstChild("Animator")
		if not animator then return end

		local currentTool = character:FindFirstChildOfClass("Tool")
		local targetScriptName = "Animate" 

		if currentTool then
			if currentTool.Name == "Hell Scythe" then targetScriptName = "HellScytheAnims"
			elseif currentTool.Name == "Voidthorn Axe" then targetScriptName = "AxeAnims" end
		end

		local activeTrack = getRunTrack(animator, targetScriptName)

		for name, track in pairs(loadedTracks) do
			if name ~= targetScriptName and track.IsPlaying then track:Stop() end
		end

		if not activeTrack then return end

		if humanoid.MoveDirection.Magnitude > 0.1 and isSprinting then
			if not activeTrack.IsPlaying then activeTrack:Play() end
		else
			if activeTrack.IsPlaying then activeTrack:Stop() end
		end
	end)