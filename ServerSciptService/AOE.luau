--[[
    AOE_NPC_Attack.lua
    Target: HADES
    Pola Serangan: Dinamis (Random Burst, Sequential Chaser, Predictive Trap)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local function playExplosionVFX(position)
    local explodeRef = game:GetService("ReplicatedStorage"):FindFirstChild("VFX") and game:GetService("ReplicatedStorage").VFX:FindFirstChild("Explode")
    if explodeRef then
        local clone = explodeRef:Clone()
        clone.Position = position
        clone.Anchored = true
        clone.CanCollide = false
        clone.Transparency = 1 -- Hide the part itself, only show particles
        clone.Parent = workspace
        
        for _, child in ipairs(clone:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                child:Emit(child:GetAttribute("EmitCount") or 30)
            end
        end
        Debris:AddItem(clone, 3)
    end
end


----------------------------------------------------------------
-- KONFIGURASI
----------------------------------------------------------------
local CONFIG = {
	NPCName        = "HADES",   
	AggroRange     = 120,       
	AttackRange    = 120,       
	AOERadius      = 12,        
	Damage         = 25,        
	TelegraphTime  = 1.5,       
	AttackCooldown = 4,         

	TelegraphColor = Color3.fromRGB(196, 68, 45),
	DashColor      = Color3.fromRGB(255, 255, 255),

	FillStartTransparency = 0.95,
	FillMaxTransparency   = 0.78,
	ImpactTransparency    = 0.35,

	DashCount = 28,

	-- Animasi
	AnimIdle = "rbxassetid://71041109678223",
	AnimAttacks = {
		"rbxassetid://94922884454218",
		"rbxassetid://110288953497892",
		"rbxassetid://137559790334345",
		"rbxassetid://88004337405609"
	}
}

----------------------------------------------------------------
-- UTIL: kumpulkan semua karakter player & bos
----------------------------------------------------------------
local function getAllCharacters(extra)
	local list = {}
	playExplosionVFX(groundPos)
        for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	
	local boss = workspace:FindFirstChild(CONFIG.NPCName)
	if boss then
		table.insert(list, boss)
	end
	
	if extra then
		table.insert(list, extra)
	end
	return list
end

----------------------------------------------------------------
-- UTIL: cari posisi tanah/terrain tepat di bawah suatu titik
----------------------------------------------------------------
local function getGroundPosition(worldPos, ignoreList)
	local rayOrigin = worldPos + Vector3.new(0, 50, 0)
	local rayDirection = Vector3.new(0, -300, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result then
		return result.Position
	end

	return Vector3.new(worldPos.X, worldPos.Y - 3, worldPos.Z)
end

----------------------------------------------------------------
-- BUAT FILL (isi lingkaran AOE)
----------------------------------------------------------------
local function createFillCircle(position, color)
	local circle = Instance.new("Part")
	circle.Name = "AOECircleFill"
	circle.Shape = Enum.PartType.Cylinder
	circle.Material = Enum.Material.Neon
	circle.Color = color
	circle.Transparency = CONFIG.FillStartTransparency
	circle.CanCollide = false
	circle.CanQuery = false
	circle.Anchored = true
	circle.Size = Vector3.new(0.15, 0.15, 0.15) 
	circle.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Parent = workspace
	return circle
end

----------------------------------------------------------------
-- BUAT OUTLINE PUTUS-PUTUS
----------------------------------------------------------------
local function createDashedRing(centerPos, fillCircle)
	local ring = Instance.new("Folder")
	ring.Name = "AOERingDashes"
	ring.Parent = workspace

	local dashes = {}
	for i = 1, CONFIG.DashCount do
		if i % 2 == 1 then
			local dash = Instance.new("Part")
			dash.Name = "Dash"
			dash.Material = Enum.Material.Neon
			dash.Color = CONFIG.DashColor
			dash.Anchored = true
			dash.CanCollide = false
			dash.CanQuery = false
			dash.Size = Vector3.new(0.3, 0.05, 0.6)
			dash.Parent = ring
			dashes[i] = dash
		end
	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not fillCircle or not fillCircle.Parent then
			connection:Disconnect()
			ring:Destroy()
			return
		end

		local radius = fillCircle.Size.Y / 2
		local dashLength = math.max(0.4, (2 * math.pi * radius / CONFIG.DashCount) * 0.7)

		for i, dash in pairs(dashes) do
			local angle = (i / CONFIG.DashCount) * math.pi * 2

			local x = centerPos.X + radius * math.cos(angle)
			local z = centerPos.Z + radius * math.sin(angle)
			local dashPos = Vector3.new(x, centerPos.Y + 0.15, z)

			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))

			dash.Size = Vector3.new(0.3, 0.05, dashLength)
			dash.CFrame = CFrame.new(dashPos, dashPos + tangent)
			
			dash.Transparency = math.clamp(fillCircle.Transparency - 0.3, 0, 1)
		end
	end)

	return ring
end

----------------------------------------------------------------
-- JALANKAN SATU LINGKARAN AOE DI SATU POSISI
----------------------------------------------------------------
local function castSingleAOE(position, ignoreList)
	local groundPos = getGroundPosition(position, ignoreList)

	local fillCircle = createFillCircle(groundPos, CONFIG.TelegraphColor)
	createDashedRing(groundPos, fillCircle)

	local fullSize = Vector3.new(0.15, CONFIG.AOERadius * 2, CONFIG.AOERadius * 2)
	TweenService:Create(
		fillCircle,
		TweenInfo.new(CONFIG.TelegraphTime, Enum.EasingStyle.Quad),
		{
			Size = fullSize,
			Transparency = CONFIG.FillMaxTransparency,
		}
	):Play()

	task.delay(CONFIG.TelegraphTime * 0.65, function()
		if fillCircle and fillCircle.Parent then
			TweenService:Create(
				fillCircle,
				TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 4, true),
				{ Transparency = math.max(CONFIG.FillMaxTransparency - 0.3, 0) }
			):Play()
		end
	end)

	task.delay(CONFIG.TelegraphTime, function()
		if not fillCircle or not fillCircle.Parent then
			return
		end

		fillCircle.Transparency = CONFIG.ImpactTransparency
		fillCircle.Size = fullSize

		playExplosionVFX(groundPos)
        for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if root and humanoid then
				local flatTarget = Vector3.new(groundPos.X, root.Position.Y, groundPos.Z)
				local distance = (root.Position - flatTarget).Magnitude

				if distance <= CONFIG.AOERadius then
					humanoid:TakeDamage(CONFIG.Damage)
				end
			end
		end
		
		local fadeTween = TweenService:Create(
			fillCircle,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = 1 }
		)
		fadeTween:Play()

		Debris:AddItem(fillCircle, 0.5)
	end)
end

----------------------------------------------------------------
-- POLA SERANGAN
----------------------------------------------------------------

-- Pola 1: Random Burst 
local function castPatternBurst(targetCharacter)
	local root = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local center = root.Position
	local positions = {}
	local maxAttempts = 30
	local ignoreList = getAllCharacters(targetCharacter)
	
	for i = 1, 5 do
		for attempt = 1, maxAttempts do
			local pos = center
			if i > 1 then
				local angle = math.random() * math.pi * 2
				local r = math.random() * 25 + 10 
				pos = center + Vector3.new(math.cos(angle)*r, 0, math.sin(angle)*r)
			end
			
			local valid = true
			for _, existing in ipairs(positions) do
				local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(existing.X, 0, existing.Z)).Magnitude
				if dist < (CONFIG.AOERadius * 1.8) then 
					valid = false
					break
				end
			end
			
			if valid or attempt == maxAttempts then
				table.insert(positions, pos)
				castSingleAOE(pos, ignoreList)
				break
			end
		end
	end
end

-- Pola 2: Sequential Chaser 
local function castPatternChaser(targetCharacter)
	local ignoreList = getAllCharacters(targetCharacter)
	
	task.spawn(function()
		for i = 1, 5 do
			local root = targetCharacter:FindFirstChild("HumanoidRootPart")
			if root then
				castSingleAOE(root.Position, ignoreList)
			end
			task.wait(0.6)
		end
	end)
end

-- Pola 3: Predictive Trap 
local function castPatternTrap(targetCharacter)
	local root = targetCharacter:FindFirstChild("HumanoidRootPart")
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	
	local ignoreList = getAllCharacters(targetCharacter)
	local center = root.Position
	local moveDir = humanoid.MoveDirection
	
	if moveDir.Magnitude < 0.1 then
		moveDir = root.CFrame.LookVector
	end
	
	castSingleAOE(center, ignoreList)
	
	task.spawn(function()
		task.wait(0.3)
		local trapRadius = CONFIG.AOERadius * 2
		
		local forward = moveDir.Unit
		local right = Vector3.new(forward.Z, 0, -forward.X)
		
		local p1 = center + forward * trapRadius
		local p2 = center + (forward * trapRadius * 0.5) + (right * trapRadius * 0.8)
		local p3 = center + (forward * trapRadius * 0.5) - (right * trapRadius * 0.8)
		local p4 = center - forward * (trapRadius * 0.5)
		
		castSingleAOE(p1, ignoreList)
		castSingleAOE(p2, ignoreList)
		castSingleAOE(p3, ignoreList)
		castSingleAOE(p4, ignoreList)
	end)
end

----------------------------------------------------------------
-- LOGIKA NPC
----------------------------------------------------------------
local function findClosestPlayer(npcRoot)
	local closestRoot, closestDist = nil, math.huge

	playExplosionVFX(groundPos)
        for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root then
			local dist = (root.Position - npcRoot.Position).Magnitude
			if dist < closestDist then
				closestRoot, closestDist = root, dist
			end
		end
	end

	return closestRoot, closestDist
end

local function startNPC(npcModel)
	local npcRoot = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")

	if not npcRoot or not humanoid then
		warn("NPC '" .. npcModel.Name .. "' butuh HumanoidRootPart dan Humanoid")
		return
	end

	-- Persiapan Animasi
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Load IDLE
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = CONFIG.AnimIdle
	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Looped = true
	idleTrack:Play()

	-- Load ATK
	local atkTracks = {}
	for _, id in ipairs(CONFIG.AnimAttacks) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		table.insert(atkTracks, track)
	end

	local rs = game:GetService("ReplicatedStorage")
	local stats = rs:WaitForChild("StageStats")
	local aggroVal = stats:WaitForChild("BossAggroed")

	task.spawn(function()
		while npcModel.Parent and humanoid.Health > 0 do
			if aggroVal.Value == true then
				local targetRoot, distance = findClosestPlayer(npcRoot)

				if targetRoot and distance <= CONFIG.AttackRange then
					-- Mainkan animasi acak (1-4)
					local randomAtk = atkTracks[math.random(1, #atkTracks)]
					randomAtk:Play()

					-- Pilih pola serangan
					local patternIndex = math.random(1, 3)
					if patternIndex == 1 then
						castPatternBurst(targetRoot.Parent)
					elseif patternIndex == 2 then
						castPatternChaser(targetRoot.Parent)
					else
						castPatternTrap(targetRoot.Parent)
					end
					
					task.wait(CONFIG.AttackCooldown)
				else
					task.wait(0.5)
				end
			else
				task.wait(0.5)
			end
		end
	end)
end

----------------------------------------------------------------
-- JALANKAN
----------------------------------------------------------------
local npc = workspace:WaitForChild(CONFIG.NPCName)
startNPC(npc)
