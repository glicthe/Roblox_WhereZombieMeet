local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local function setupZombie(npc)
	local torso        = npc:WaitForChild("Torso")
	local head         = npc:WaitForChild("Head")
	local npchumanoid  = npc:WaitForChild("Humanoid")

	npchumanoid.MaxHealth = math.random(100, 400)
	npchumanoid.Health    = npchumanoid.MaxHealth

	if not npc:GetAttribute("DisplayName") then npc:SetAttribute("DisplayName", npc.Name) end
	if not npc:GetAttribute("EnemyType") then npc:SetAttribute("EnemyType", "Undead") end
	if not npc:GetAttribute("Level") then npc:SetAttribute("Level", math.floor(npchumanoid.MaxHealth / 10)) end
	if not npc:GetAttribute("IsBoss") then npc:SetAttribute("IsBoss", false) end

	local footstep = Instance.new("Sound", head)
	footstep.Name     = "footstep"
	footstep.SoundId  = "rbxassetid://4113577407"
	footstep.Looped   = true
	footstep.Volume   = 0
	footstep:Play()

	local sight        = 80
	local walking      = false
	local canrandomwalk = true

	local animator = npchumanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = npchumanoid
	end

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://86023348614572"
	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped   = true
	idleTrack:Play()

	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = "rbxassetid://76398130594053"
	local walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	walkTrack.Looped   = true
	
	local hitAnim = Instance.new("Animation")
	hitAnim.AnimationId = "rbxassetid://111531309371001"
	local hitTrack = animator:LoadAnimation(hitAnim)
	hitTrack.Priority = Enum.AnimationPriority.Action

	local oldHealth = npchumanoid.Health

	-- 1. Create the Highlight but KEEP IT DISABLED
	local damageHighlight = Instance.new("Highlight")
	damageHighlight.Name = "DamageFlash"
	damageHighlight.FillColor = Color3.fromRGB(255, 0, 0)
	damageHighlight.FillTransparency = 0.2
	damageHighlight.OutlineTransparency = 1
	damageHighlight.Enabled = false -- CRITICAL FIX: Stops the 31-limit crash
	damageHighlight.Parent = npc

	local flashTick = 0

	npchumanoid.HealthChanged:Connect(function(health)
		if health < oldHealth and health > 0 then
			pcall(function() hitTrack:Play() end)

			-- 2. Instantly turn the flash on
			damageHighlight.Enabled = true

			-- 3. Track this specific hit so rapid attacks don't cancel each other out
			flashTick = flashTick + 1
			local currentTick = flashTick

			-- 4. Turn it off cleanly after a fraction of a second
			task.delay(0.25, function()
				if flashTick == currentTick then
					damageHighlight.Enabled = false
				end
			end)
		end

		oldHealth = health
	end)

	local currentAnimationState = "Idle"

	npchumanoid.Running:Connect(function(speed)
		local isMoving = speed > 1.0

		if isMoving and currentAnimationState ~= "Walking" then
			currentAnimationState = "Walking"
			footstep.Volume = 0.5
			idleTrack:Stop(0.2)
			walkTrack:Play(0.2)
		elseif not isMoving and currentAnimationState ~= "Idle" then
			currentAnimationState = "Idle"
			footstep.Volume = 0
			walkTrack:Stop(0.2)
			idleTrack:Play(0.2)
		end
	end)

	local function walkrandomly()
		while npc.Parent and npchumanoid.Health > 0 do
			task.wait(math.random(5, 10))
			npchumanoid.WalkSpeed  = 8
			if not walking and canrandomwalk and not npc:GetAttribute("IsChasing") then
				local walkpart = Instance.new("Part", workspace)
				walkpart.Size         = Vector3.new(1, 1, 1)
				walkpart.Anchored     = true
				walkpart.Transparency = 1
				walkpart.CanCollide   = false
				walkpart.CFrame       = torso.CFrame * CFrame.new(math.random(-20, 20), 0, math.random(-20, 20))

				local path = game:GetService("PathfindingService"):FindPathAsync(torso.Position, walkpart.Position)
				local waypoints = path:GetWaypoints()
				if path.Status == Enum.PathStatus.Success then
					for _, v in pairs(waypoints) do
						if canrandomwalk and not npc:GetAttribute("IsChasing") and npchumanoid.Health > 0 then
							npchumanoid:MoveTo(v.Position)
							local allow = 0
							while (torso.Position - v.Position).Magnitude > 4 and allow < 25 do
								allow = allow + 1
								task.wait()
							end
						else
							break
						end
					end
				end
				walkpart:Destroy()
			end
		end
	end

	local isDead = false
	local function death()
		if isDead then return end
		isDead = true
		
		-- 1. Segera hapus komponen UI yang menempel di kepala agar bersih
		local bb = head:FindFirstChild("ZombieHealthBar")
		if bb then bb:Destroy() end
		
		if npc:FindFirstChild("Health") then npc.Health:Destroy() end
		if head:FindFirstChild("footstep") then head.footstep:Destroy() end
		
		-- 2. Hapus highlight merah jika masih ada
		local flash = npc:FindFirstChild("DamageFlash")
		if flash then flash:Destroy() end
		
		-- 3. Biarkan mesin Roblox (BreakJointsOnDeath) memecah sendinya secara otomatis seperti lego!
		-- Kita hanya perlu memastikan kepingannya bisa menyentuh lantai (tidak tembus pandang secara fisik)
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end

		-- 4. Jadwalkan mayat asli untuk dihapus dalam 3 detik
				game.Debris:AddItem(npc, 3)
		
				-- Increment Global Kill Count
		local killCount = RS:FindFirstChild("GlobalKillCount")
		if killCount then
			killCount.Value += 1
		end
        
        -- Record individual player kill
        local creatorTag = npchumanoid:FindFirstChild("creator")
        if creatorTag and creatorTag.Value then
            local pName = creatorTag.Value.Name
            local killsFolder = RS:FindFirstChild("StageStats") and RS.StageStats:FindFirstChild("Kills")
            if killsFolder then
                local pKillVal = killsFolder:FindFirstChild(pName)
                if not pKillVal then
                    pKillVal = Instance.new("IntValue", killsFolder)
                    pKillVal.Name = pName
                    pKillVal.Value = 0
                end
                pKillVal.Value += 1
            end
        end



		-- 5. Efek memudar setelah 1.5 detik
		task.delay(1.5, function()
			if not npc or not npc.Parent then return end
			local fadeTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear)
			for _, part in ipairs(npc:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					TweenService:Create(part, fadeTweenInfo, {Transparency = 1}):Play()
				end
			end
		end)

		-- 6. Logika Drop Item (Coin/Health)
		local dropChance = math.random(1, 100)
		local dropItem = nil
		if dropChance <= 60 then
			local coinTemp = RS:FindFirstChild("Coin")
			if coinTemp then dropItem = coinTemp:Clone() end
		else
			local healthTemp = RS:FindFirstChild("Health")
			if healthTemp then dropItem = healthTemp:Clone() end
		end

		if dropItem then
			local pickupScript = dropItem:FindFirstChildOfClass("Script")
			if pickupScript then pickupScript.Disabled = true end

			local angle = math.random() * math.pi * 2
			local radius = math.random(4, 7)
			local offset = Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)

			local startPos = torso.Position + Vector3.new(0, 1, 0)
			local midPos = startPos + offset * 0.5 + Vector3.new(0, 5, 0)

			local ray = Ray.new(startPos + offset, Vector3.new(0, -20, 0))
			local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, {dropItem, npc})

			local endY = startPos.Y - 2
			if hit then
				endY = hitPos.Y + (dropItem.Size.Y / 2) + 0.2
			end

			local endPos = Vector3.new(startPos.X + offset.X, endY, startPos.Z + offset.Z)

			dropItem.CFrame = CFrame.new(startPos)
			dropItem.Parent = workspace

			local t1 = TweenService:Create(dropItem, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(midPos)})
			t1:Play()
			t1.Completed:Connect(function()
				local t2 = TweenService:Create(dropItem, TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {CFrame = CFrame.new(endPos)})
				t2:Play()
				t2.Completed:Connect(function()
					if pickupScript then pickupScript.Disabled = false end
				end)
			end)
		end
	end
	
	npchumanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if npchumanoid.Health <= 0 then
			death()
		end
	end)
	
	npchumanoid.Died:Connect(death)
	task.spawn(walkrandomly)
end

for _, zombie in ipairs(CollectionService:GetTagged("Zombie")) do
	task.spawn(function()
		setupZombie(zombie)
	end)
end

CollectionService:GetInstanceAddedSignal("Zombie"):Connect(setupZombie)
