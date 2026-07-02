---------------------------
-- AXE ATTACK
--------------------------

local tool = script.Parent
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local debris = game:GetService("Debris")
local uis = game:GetService("UserInputService")

-----------------------------------
-- BASIC ATTACK (M1) SETUP
-----------------------------------
local comboAnimations = {
	"rbxassetid://72722718965730", 
	"rbxassetid://71527609662729", 
	"rbxassetid://120938652426115",
	"rbxassetid://80238608657830"
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
	"rbxassetid://84894992438545",
	"rbxassetid://101266427032050"
}

-- 2. Define the "Impact" sounds
local hitSoundIDs = {
	"rbxassetid://139399013252824", 
	"rbxassetid://139399013252824", 
	"rbxassetid://140631135739557",
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
local attackCooldown = 0.2   
local comboFinishCooldown = 0.3

-----------------------------------
-- SKILL (E) SETUP
-----------------------------------
local skillEOnCooldown = false
local skillECooldownTime = 2 

local skillEAnim = Instance.new("Animation")
skillEAnim.AnimationId = "rbxassetid://140693056975462" 
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
skillQAnim.AnimationId = "rbxassetid://130380047238717" 
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
local skillRCooldownTime = 10

local skillRAnim = Instance.new("Animation")
skillRAnim.AnimationId = "rbxassetid://127183360131331" 
local skillRTrack = animator:LoadAnimation(skillRAnim)
skillRTrack.Priority = Enum.AnimationPriority.Action3 

-- Sound 1 
local skillRSound1 = Instance.new("Sound")
skillRSound1.SoundId = "rbxassetid://140221563557515"
skillRSound1.Volume = 0.8
skillRSound1.Parent = tool

-- Sound 2 
local skillRSound2 = Instance.new("Sound")
skillRSound2.SoundId = "rbxassetid://139249629022775"
skillRSound2.Volume = 0.6
skillRSound2.Parent = tool

-- Sound 3 
local skillRSound3 = Instance.new("Sound")
skillRSound3.SoundId = "rbxassetid://126941244422484"
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
	if skillETrack.IsPlaying then skillETrack:Stop() end
	if skillQTrack.IsPlaying then skillQTrack:Stop() end
	if skillRTrack.IsPlaying then skillRTrack:Stop() end
end)

-----------------------------------
-- BASIC ATTACK LOGIC (Left Click)
-----------------------------------
tool.Activated:Connect(function()
	if isAttacking then return end
	if character:FindFirstChild("stunned") then return end
	if character:GetAttribute("IsSprinting") == true then return end

	isAttacking = true
	local currentTime = tick()

	if currentTime - lastAttackTime > comboResetTime then
		comboIndex = 1
	end

	local currentTrack = loadedTracks[comboIndex]
	local weaponTrail = tool:FindFirstChild("Trail", true)
	
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
	hitbox.Size = Vector3.new(8, 5, 6)
	hitbox.BrickColor = BrickColor.new("Really red")
	hitbox.Transparency = 1
	debris:AddItem(hitbox, 1)

	local hitEnemies = {}
	local playedHitSound = false

	task.spawn(function()
		for i = 1, 10 do 
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				hitbox.CFrame = rootPart.CFrame * CFrame.new(0, 0, -5)
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

						local hitType = "regular"
						if comboIndex == #loadedTracks then
							hitType = "last"
						end

						game.ReplicatedStorage.CombatEvent:FireServer(enemyCharacter, hitType)
					end
				end
			end
			task.wait(0.03)
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
	if character:GetAttribute("IsDashing") == true then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		isAttacking = true 
		skillEOnCooldown = true
		pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("StartSkillCooldown"):Fire(2, skillECooldownTime) end)

		local originalWalkSpeed = humanoid.WalkSpeed
		local originalJumpPower = humanoid.JumpPower
		humanoid.WalkSpeed = 0
		if humanoid.UseJumpPower then
			humanoid.JumpPower = 0
		else
			humanoid.JumpHeight = 0
		end
		
		skillETrack:Play()

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillESound1.SoundId, rootPart, skillESound1.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillESound2.SoundId, rootPart, skillESound2.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillESound3.SoundId, rootPart, skillESound3.Volume, 1)
		end

		local hitEnemies = {}

		-- Lock the starting position so the spikes travel in the direction the player cast it
		local startCFrame = character:WaitForChild("HumanoidRootPart").CFrame

		local vfxFolder = game.ReplicatedStorage:FindFirstChild("VFX")
		local vfxTemplate = nil
		if vfxFolder and vfxFolder:FindFirstChild("Weapon") and vfxFolder.Weapon:FindFirstChild("Axe") then
			vfxTemplate = vfxFolder.Weapon.Axe:FindFirstChild("SkillEVFX")
		end

		task.spawn(function()
			-- WAIT FOR ANIMATION TO SMASH THE GROUND
			-- Adjust this 0.4 based on the exact second the axe hits the floor in your animation
			task.wait(1.5) 

			local segments = 8            -- How many spikes/hitboxes to spawn in the line
			local forwardOffset = 5       -- Distance between each spike
			local travelSpeed = 0.05      -- How fast the wave travels forward
			local lingerTime = 0.8        -- How long the previous spikes stay on screen before vanishing

			for i = 1, segments do
				-- The hitbox grows larger on every loop iteration
				local boxWidth = 6   -- Gets wider
				local boxHeight = 0.5 + (i * 1.5)   -- Gets taller
				local boxDepth = 6              -- Thickness stays the same to connect cleanly

				-- Offset Y so the bottom of the growing hitbox stays on the ground (RootPart is usually 3 studs above ground)
				local currentCFrame = startCFrame * CFrame.new(0, -3 + (boxHeight / 2), - (i * forwardOffset))

				-- Create segment hitbox
				local segmentBox = Instance.new("Part")
				segmentBox.Parent = workspace
				segmentBox.CanCollide = false
				segmentBox.Anchored = true
				segmentBox.Size = Vector3.new(boxWidth, boxHeight, boxDepth)
				segmentBox.CFrame = currentCFrame
				segmentBox.BrickColor = BrickColor.new("Blue") 
				segmentBox.Transparency = 0.5

				-- Delayed disappearance for this specific segment
				debris:AddItem(segmentBox, lingerTime)

				-- Scan for hits in this specific segment
				local overlappingParts = workspace:GetPartsInPart(segmentBox)
				for _, hitPart in ipairs(overlappingParts) do
					local enemyCharacter = hitPart.Parent

					if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
						-- Ensure an enemy isn't hit 8 times by the overlapping wave
						if not hitEnemies[enemyCharacter] then
							hitEnemies[enemyCharacter] = true 
							game.ReplicatedStorage.SkillEvent:FireServer(enemyCharacter, "E", "AXE")
						end
					end
				end

				-- Spawn VFX for this segment
				if vfxTemplate then
					local vfxClone = vfxTemplate:Clone()
					-- Drop the VFX to ground level so particles erupt from the floor
					vfxClone.CFrame = currentCFrame * CFrame.new(0, -boxHeight / 2, 0)
					vfxClone.Parent = workspace

					for _, child in ipairs(vfxClone:GetDescendants()) do
						if child:IsA("ParticleEmitter") then
							child:Emit(1)
						end
					end
					debris:AddItem(vfxClone, lingerTime)
				end

				-- Delay before spawning the next, bigger spike in the wave
				task.wait(travelSpeed)
			end
		end)

		task.wait(1.5) 
		isAttacking = false 

		humanoid.WalkSpeed = originalWalkSpeed
		if humanoid.UseJumpPower then
			humanoid.JumpPower = originalJumpPower
		else
			humanoid.JumpHeight = 7.2
		end

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

		local startCFrame = character:WaitForChild("HumanoidRootPart").CFrame

		local hitbox1 = Instance.new("Part")
		hitbox1.Parent = workspace
		hitbox1.CanCollide = false
		hitbox1.Anchored = true
		hitbox1.Size = Vector3.new(25, 2, 5)
		hitbox1.Transparency = 0.5
		hitbox1.BrickColor = BrickColor.new("Bright violet")
		debris:AddItem(hitbox1, 1.5)

		local hitbox2 = Instance.new("Part")
		hitbox2.Parent = workspace
		hitbox2.CanCollide = false
		hitbox2.Anchored = true
		hitbox2.Size = Vector3.new(25, 2, 5)
		hitbox2.Transparency = 0.5
		hitbox2.BrickColor = BrickColor.new("Bright violet")
		debris:AddItem(hitbox2, 1.5)

		local hitEnemies = {}

		local function scanHitbox(box, currentPos)
			local overlappingParts = workspace:GetPartsInPart(box)
			for _, hitPart in ipairs(overlappingParts) do
				local enemyCharacter = hitPart.Parent
				if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
					if not hitEnemies[enemyCharacter] then
						hitEnemies[enemyCharacter] = true
						game.ReplicatedStorage.SkillEvent:FireServer(enemyCharacter, "Q", "AXE", currentPos)
					end
				end
			end
		end

		local vfxClone = nil
		local vfxFolder = game.ReplicatedStorage:FindFirstChild("VFX")
		if vfxFolder and vfxFolder:FindFirstChild("Weapon") and vfxFolder.Weapon:FindFirstChild("Axe") then
			local vfxTemplate = vfxFolder.Weapon.Axe:FindFirstChild("SkillQVFX")
			if vfxTemplate then
				vfxClone = vfxTemplate:Clone()
				vfxClone.Parent = workspace
				for _, child in ipairs(vfxClone:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						child:Emit(1)
					end
				end
				debris:AddItem(vfxClone, 1.5)
			end
		end

		task.spawn(function()
			local travelDistance = 0
			local speed = 2 

			for i = 1, 30 do 
				travelDistance = travelDistance + speed
				local currentCenter = startCFrame * CFrame.new(0, 0, -5 - travelDistance)

				hitbox1.CFrame = currentCenter * CFrame.Angles(0, 0, math.rad(15))
				hitbox2.CFrame = currentCenter * CFrame.Angles(0, 0, math.rad(-15))

				if vfxClone then
					vfxClone.CFrame = currentCenter
				end

				scanHitbox(hitbox1, currentCenter.Position)
				scanHitbox(hitbox2, currentCenter.Position)

				task.wait(0.03)
			end
		end)

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

		skillRTrack:Play()

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillRSound1.SoundId, rootPart, skillRSound1.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillRSound2.SoundId, rootPart, skillRSound2.Volume, 1)
			game.ReplicatedStorage.GlobalSoundEvent:FireServer(skillRSound3.SoundId, rootPart, skillRSound3.Volume, 1)
		end

		local activeDuration = 2
		local damageTickRate = 0.5 

		local hitbox = Instance.new("Part")
		hitbox.Parent = workspace
		hitbox.CanCollide = false
		hitbox.Anchored = true
		hitbox.Size = Vector3.new(15, 10, 15) 
		hitbox.BrickColor = BrickColor.new("Really red") 
		hitbox.Transparency = 0.75
		debris:AddItem(hitbox, activeDuration)

		local vfxFolder = game.ReplicatedStorage:FindFirstChild("VFX")
		local vfxClone = nil
		if vfxFolder and vfxFolder:FindFirstChild("Weapon") and vfxFolder.Weapon:FindFirstChild("Axe") then
			local vfxTemplate = vfxFolder.Weapon.Axe:FindFirstChild("SkillRVFX")
			if vfxTemplate then
				vfxClone = vfxTemplate:Clone()
				vfxClone.Parent = workspace
				debris:AddItem(vfxClone, activeDuration)
			end
		end

		task.spawn(function()
			local hitTimers = {}
			local elapsed = 0

			while elapsed < activeDuration do
				local currentRoot = character:FindFirstChild("HumanoidRootPart")
				if currentRoot then
					hitbox.CFrame = currentRoot.CFrame

					if vfxClone then
						vfxClone.CFrame = currentRoot.CFrame
					end
				end

				local overlappingParts = workspace:GetPartsInPart(hitbox)
				for _, hitPart in ipairs(overlappingParts) do
					local enemyCharacter = hitPart.Parent

					if enemyCharacter and enemyCharacter:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemyCharacter) then
						local lastHitTime = hitTimers[enemyCharacter] or 0

						if tick() - lastHitTime >= damageTickRate then
							hitTimers[enemyCharacter] = tick()
							game.ReplicatedStorage.SkillEvent:FireServer(enemyCharacter, "R")
						end
					end
				end

				if vfxClone then
					for _, child in ipairs(vfxClone:GetDescendants()) do
						if child:IsA("ParticleEmitter") then
							child:Emit(1)
						end
					end
				end

				task.wait(0.03)
				elapsed = elapsed + 0.03
			end
		end)

		task.wait(0.9) 
		isAttacking = false 

		task.wait(skillRCooldownTime)
		skillROnCooldown = false
	end
end)