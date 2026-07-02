-------------------------------
-- SCYTHE ATTACK
-------------------------------

local tool = script.Parent
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local RunService = game:GetService("RunService")
local debris = game:GetService("Debris")
local uis = game:GetService("UserInputService")

-----------------------------------
-- BASIC ATTACK (M1) SETUP
-----------------------------------
local comboAnimations = {
	"rbxassetid://113324919553812", 
	"rbxassetid://138027304354688", 
	"rbxassetid://126202743973572"  
}

local loadedTracks = {}
for i, id in ipairs(comboAnimations) do
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	table.insert(loadedTracks, track)
end

-- 1. Define the "Whoosh" sounds
local swingSoundIDs = {
	"rbxassetid://101266427032050", 
	"rbxassetid://125914564702009", 
	"rbxassetid://84894992438545"  
}

-- 2. Define the "Impact" sounds
local hitSoundIDs = {
	"rbxassetid://139399013252824", 
	"rbxassetid://139399013252824", 
	"rbxassetid://140631135739557"   
}

local loadedSwings = {}
for _, id in ipairs(swingSoundIDs) do
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.5
	sound.PlaybackSpeed = 2.0
	sound.Parent = tool 
	table.insert(loadedSwings, sound)
end

local loadedHits = {}
for _, id in ipairs(hitSoundIDs) do
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.7
	table.insert(loadedHits, sound)
end

local isAttacking = false
local isEquipped = false
local comboIndex = 1
local lastAttackTime = 0
local comboResetTime = 0.75
local attackCooldown = 0.1    
local comboFinishCooldown = 0.25

-----------------------------------
-- SKILL (E) SETUP
-----------------------------------
local skillEOnCooldown = false
local skillECooldownTime = 2 

local skillEAnim = Instance.new("Animation")
skillEAnim.AnimationId = "rbxassetid://115632989161735" 
local skillETrack = animator:LoadAnimation(skillEAnim)
skillETrack.Priority = Enum.AnimationPriority.Action3 

-- Sound 1 
local skillESound1 = Instance.new("Sound")
skillESound1.SoundId = "rbxassetid://140209514807090"
skillESound1.Volume = 0.8
skillESound1.Parent = tool

-- Sound 2 
local skillESound2 = Instance.new("Sound")
skillESound2.SoundId = "rbxassetid://139316396351592"
skillESound2.Volume = 0.1
skillESound2.Parent = tool

-- Sound 3 
local skillESound3 = Instance.new("Sound")
skillESound3.SoundId = "rbxassetid://115776744946743"
skillESound3.Volume = 1
skillESound3.Parent = tool


-----------------------------------
-- SKILL (Q) SETUP
-----------------------------------
local skillQOnCooldown = false
local skillQCooldownTime = 5



local skillQAnim = Instance.new("Animation")
skillQAnim.AnimationId = "rbxassetid://126483211414095" 
local skillQTrack = animator:LoadAnimation(skillQAnim)
skillQTrack.Priority = Enum.AnimationPriority.Action3 

-- Sound 1 
local skillQSound1 = Instance.new("Sound")
skillQSound1.SoundId = "rbxassetid://130293516985070"
skillQSound1.Volume = 0.8
skillQSound1.Parent = tool

-- Sound 2 
local skillQSound2 = Instance.new("Sound")
skillQSound2.SoundId = "rbxassetid://122258480286280"
skillQSound2.Volume = 0.1
skillQSound2.Parent = tool

-- Sound 3 
local skillQSound3 = Instance.new("Sound")
skillQSound3.SoundId = "rbxassetid://140221563557515"
skillQSound3.Volume = 1
skillQSound3.Parent = tool

-----------------------------------
-- SKILL (R) SETUP
-----------------------------------
local skillROnCooldown = false
local skillRCooldownTime = 2

-- Sound 1 
local skillRSound1 = Instance.new("Sound")
skillRSound1.SoundId = "rbxassetid://103991094857679"
skillRSound1.Volume = 0.8
skillRSound1.Parent = tool

-- Sound 2 
local skillRSound2 = Instance.new("Sound")
skillRSound2.SoundId = "rbxassetid://139249629022775"
skillRSound2.Volume = 0.6
skillRSound2.Parent = tool

-- Sound 3 
local skillRSound3 = Instance.new("Sound")
skillRSound3.SoundId = "rbxassetid://140624166269971 "
skillRSound3.Volume = 1
skillRSound3.Parent = tool

-----------------------------------
-- EQUIP & UNEQUIP LOGIC
-----------------------------------
tool.Equipped:Connect(function()
	isEquipped = true
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	isAttacking = false
	comboIndex = 1
	for _, track in ipairs(loadedTracks) do
		if track.IsPlaying then
			track:Stop()
		end
	end
	if skillETrack.IsPlaying then
		skillETrack:Stop()
	end
end)


-----------------------------------
-- BASIC ATTACK LOGIC (Left Click)
-----------------------------------
tool.Activated:Connect(function()
	if isAttacking then return end
	if character:FindFirstChild("stunned") then return end
	if character:GetAttribute("IsSprinting") == true then return end
	if character:GetAttribute("IsDashing") == true then return end

	isAttacking = true

	local currentTime = tick()

	if currentTime - lastAttackTime > comboResetTime then
		comboIndex = 1
	end

	local currentTrack = loadedTracks[comboIndex]
	local weaponTrail = game.ReplicatedStorage.Weapons["Hell Scythe"].HandleR:FindFirstChild("Trail", true)

	if weaponTrail then 
		weaponTrail.Enabled = true 
	end
	currentTrack:Play(0.2)

	local swingSound = loadedSwings[comboIndex]
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		game.ReplicatedStorage.GlobalSoundEvent:FireServer(swingSound.SoundId, rootPart, swingSound.Volume, swingSound.PlaybackSpeed)
	end

	local hitbox = Instance.new("Part")
	hitbox.Parent = workspace
	hitbox.CanCollide = false
	hitbox.Anchored = true 
	hitbox.Size = Vector3.new(12, 5, 6)
	hitbox.BrickColor = BrickColor.new("Really red")
	hitbox.Transparency = 1
	debris:AddItem(hitbox, 1)

	local hitEnemies = {}
	local playedHitSound = false

	local comboVFXMapping = {
		[1] = "BA1VFX", 
		[2] = "BA2VFX", 
		[3] = "BA3VFX"  
	}	
	local targetVFXName = comboVFXMapping[comboIndex]
	local activeVFX = nil 


	task.spawn(function()	
		for i = 1, 10 do 
			local loopRoot = character:FindFirstChild("HumanoidRootPart")
			if loopRoot then
				hitbox.CFrame = loopRoot.CFrame * CFrame.new(0, 0, -7)
			end
			task.wait(0.03)
			if i == 10 then
				local cameraCFrame = workspace.CurrentCamera.CFrame
				local camLook = cameraCFrame.LookVector
				-- Zero out the vertical component ? flat horizontal direction
				local flatLook = Vector3.new(camLook.X, 0, camLook.Z)

				-- In case the camera is looking exactly straight down/up, we need a fallback
				if flatLook.Magnitude < 0.01 then
					flatLook = Vector3.new(0, 0, -1)  -- default forward
				end
				flatLook = flatLook.Unit

				-- Create a rotation that faces flatLook, with world-up (0,1,0)
				local attackRotation = CFrame.lookAt(Vector3.zero, flatLook)
				
				local finalCFrame = CFrame.new(hitbox.Position) * attackRotation
				game.ReplicatedStorage.VFXSkillEvent:FireServer(targetVFXName, finalCFrame)
			end
		end

		local overlappingParts = workspace:GetPartsInPart(hitbox)

		for _, hitPart in ipairs(overlappingParts) do
			local enemyCharacter = hitPart.Parent

			if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
				if not hitEnemies[enemyCharacter] then
					hitEnemies[enemyCharacter] = true 

					if not playedHitSound then
						playedHitSound = true
						local enemyRoot = enemyCharacter:FindFirstChild("HumanoidRootPart")
						if enemyRoot then
							local hitSound = loadedHits[comboIndex]
							local randomSpeed = math.random(85, 115) / 100
							game.ReplicatedStorage.GlobalSoundEvent:FireServer(hitSound.SoundId, enemyRoot, hitSound.Volume, randomSpeed)
						end
					end
					
					debris:AddItem(activeVFX, 2)
					
					local hitType = "regular"
					if comboIndex == #loadedTracks then
						hitType = "last"
					end

					game.ReplicatedStorage.CombatEvent:FireServer(enemyCharacter, hitType)
				end
			end
		end
	end)

	currentTrack.Stopped:Wait()

	if weaponTrail then weaponTrail.Enabled = false end

	if comboIndex == #loadedTracks then
		task.wait(comboFinishCooldown)
	else
		task.wait(attackCooldown)
	end

	lastAttackTime = tick()

	comboIndex = comboIndex + 1
	if comboIndex > #loadedTracks then
		comboIndex = 1
	end

	isAttacking = false
end)

-----------------------------------
-- SKILL LOGIC (E Key)
-----------------------------------
uis.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isEquipped then return end
	if isAttacking or skillEOnCooldown or character:FindFirstChild("stunned") or character:GetAttribute("IsSSprint") then return end

	if input.KeyCode == Enum.KeyCode.E then
		isAttacking = true 
		skillEOnCooldown = true
		pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("StartSkillCooldown"):Fire(2, skillECooldownTime) end)

		skillETrack:Play()

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillESound1.SoundId, rootPart, skillESound1.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillESound2.SoundId, rootPart, skillESound2.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillESound3.SoundId, rootPart, skillESound3.Volume, 1)
		end

		local hitbox = Instance.new("Part")
		hitbox.Parent = workspace
		hitbox.CanCollide = false
		hitbox.Anchored = true
		hitbox.Size = Vector3.new(10, 10, 35) 
		hitbox.BrickColor = BrickColor.new("Blue") 
		hitbox.Transparency = 1
		debris:AddItem(hitbox, 2)

		local hitEnemies = {}
		
		task.spawn(function()
			for i = 1, 15 do -- Scans and updates position for 0.45 seconds
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					hitbox.CFrame = rootPart.CFrame * CFrame.new(0, 0, -24)
				end

				local overlappingParts = workspace:GetPartsInPart(hitbox)
				for _, hitPart in ipairs(overlappingParts) do
					local enemyCharacter = hitPart.Parent

					if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
						if not hitEnemies[enemyCharacter] then
							hitEnemies[enemyCharacter] = true 
							game.ReplicatedStorage.SkillEvent:FireServer(enemyCharacter, "E", "SCYTHE")
						end
					end
					
					
				end
				task.wait(0.03)
			end
		end)
		
		game.ReplicatedStorage.VFXSkillEvent:FireServer("SkillEVFX", hitbox.CFrame)
		

		task.wait(0.9) 
		isAttacking = false 

		task.wait(skillECooldownTime)
		skillEOnCooldown = false
	end
end)

-----------------------------------
-- SKILL LOGIC (Q Key)
-----------------------------------
uis.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isEquipped then return end
	if isAttacking or skillQOnCooldown or character:FindFirstChild("stunned") or character:GetAttribute("IsSprinting") then return end

	if input.KeyCode == Enum.KeyCode.Q then
		isAttacking = true 
		skillQOnCooldown = true
		pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("StartSkillCooldown"):Fire(1, skillQCooldownTime) end)

		skillQTrack:Play()
		
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillQSound1.SoundId, rootPart, skillQSound1.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillQSound2.SoundId, rootPart, skillQSound2.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillQSound3.SoundId, rootPart, skillQSound3.Volume, 1)
		end

		local rootPart = character:WaitForChild("HumanoidRootPart")
		local hitbox = Instance.new("Part")
		hitbox.Parent = workspace
		hitbox.CanCollide = false
		hitbox.Anchored = true
		hitbox.Size = Vector3.new(20, 10, 20)
		hitbox.Transparency = 1
		hitbox.BrickColor = BrickColor.new("Bright violet")
		hitbox.CFrame = rootPart.CFrame * CFrame.new(0, 0, -20)
		debris:AddItem(hitbox, 1)

		-- Detect and pull enemies
		local overlappingParts = workspace:GetPartsInPart(hitbox)
		for _, hitPart in ipairs(overlappingParts) do
			local enemyCharacter = hitPart.Parent
			if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
				-- Fire to server with "pull" type
				game.ReplicatedStorage.SkillEvent:FireServer(enemyCharacter, "Q", "SCYTHE" ,hitbox.Position)
			end
		end

		game.ReplicatedStorage.VFXSkillEvent:FireServer("SkillQVFX", hitbox.CFrame)

		task.wait(0.5) 
		isAttacking = false 
		task.wait(skillQCooldownTime)
		skillQOnCooldown = false
	end
end)


-----------------------------------
-- SKILL LOGIC (R Key)
-----------------------------------
uis.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isEquipped then return end
	if isAttacking or skillROnCooldown or character:FindFirstChild("stunned") or character:GetAttribute("IsSSprint") then return end

	if input.KeyCode == Enum.KeyCode.R then
		isAttacking = true 
		skillROnCooldown = true
		pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("StartSkillCooldown"):Fire(3, skillRCooldownTime) end)

		--skillRTrack:Play()

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillRSound1.SoundId, rootPart, skillRSound1.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillRSound2.SoundId, rootPart, skillRSound2.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillRSound3.SoundId, rootPart, skillRSound3.Volume, 1)
		end

		local hitbox = Instance.new("Part")
		hitbox.Parent = workspace
		hitbox.CanCollide = false
		hitbox.Anchored = true
		hitbox.Size = Vector3.new(30, 10, 35) 
		hitbox.BrickColor = BrickColor.new("Really red") 
		hitbox.Transparency = 1
		debris:AddItem(hitbox, 1)

		local hitEnemies = {}

		task.spawn(function()
			for i = 1, 15 do -- Scans and updates position for 0.45 seconds
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					hitbox.CFrame = rootPart.CFrame * CFrame.new(0, 0, -25)
				end

				local overlappingParts = workspace:GetPartsInPart(hitbox)
				for _, hitPart in ipairs(overlappingParts) do
					local enemyCharacter = hitPart.Parent

					if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
						if not hitEnemies[enemyCharacter] then
							hitEnemies[enemyCharacter] = true 
							game.ReplicatedStorage.SkillEvent:FireServer(enemyCharacter, "R", "SCYTHE")
						end
					end
				end
				task.wait(0.03)
			end
		end)
		
		game.ReplicatedStorage.VFXSkillEvent:FireServer("SkillRVFX", hitbox.CFrame)

		task.wait(0.9) 
		isAttacking = false 

		task.wait(skillRCooldownTime)
		skillROnCooldown = false
	end
end)