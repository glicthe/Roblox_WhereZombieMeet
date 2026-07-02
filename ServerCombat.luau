local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local combatEvent = ReplicatedStorage:WaitForChild("CombatEvent")
local skillEvent = ReplicatedStorage:WaitForChild("SkillEvent")
local indicatorTemplate = ReplicatedStorage:WaitForChild("DamageIndicator")


local function showDamageNumber(character, damageAmount, isCrit)
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    local indicator = indicatorTemplate:Clone()
    local textLabel = indicator:WaitForChild("DamageText")
    
    textLabel.Text = tostring(damageAmount)
    
    if isCrit then
        textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        indicator.Size = UDim2.new(0, 140, 0, 70)
    end
    
    indicator.Parent = head
    
    -- Animate via server TweenService
    local randomOffset = Vector3.new(math.random(-20, 20)/10, 3, math.random(-20, 20)/10)
    
    local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = TweenService:Create(indicator, tweenInfo, {StudsOffset = indicator.StudsOffset + randomOffset})
    tween:Play()
    
    local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    local fadeTween = TweenService:Create(textLabel, fadeInfo, {TextTransparency = 1, TextStrokeTransparency = 1})
    
    task.delay(0.4, function()
        if textLabel then fadeTween:Play() end
    end)
    
    Debris:AddItem(indicator, 1)
end

combatEvent.OnServerEvent:Connect(function(player, enemyCharacter, hitType)
	if not enemyCharacter then return end
	local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
	local enemyRootPart = enemyCharacter:FindFirstChild("HumanoidRootPart")

	if enemyHumanoid and enemyRootPart and enemyHumanoid.Health > 0 then
        local randDmg = math.random(1, 5)
		local dmg = 0		
		if randDmg == 5 then 
			dmg = math.random(2500, 3000)
			enemyHumanoid:TakeDamage(dmg)
			showDamageNumber(enemyCharacter, dmg, true)
		else
			dmg = 2000
			enemyHumanoid:TakeDamage(dmg)
			showDamageNumber(enemyCharacter, dmg, false)
        end
        -- Tag creator
        local creatorTag = enemyHumanoid:FindFirstChild("creator")
        if not creatorTag then
            creatorTag = Instance.new("ObjectValue", enemyHumanoid)
            creatorTag.Name = "creator"
        end
        creatorTag.Value = player


		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)

		if hitType == "regular" then
			bodyVelocity.Velocity = player.Character.HumanoidRootPart.CFrame.LookVector * 15
		elseif hitType == "last" then
			bodyVelocity.Velocity = player.Character.HumanoidRootPart.CFrame.LookVector * 30
		end

		bodyVelocity.Parent = enemyRootPart
		Debris:AddItem(bodyVelocity, 0.1) 

		local stun = Instance.new("BoolValue")
		stun.Name = "stunned"
		stun.Parent = enemyCharacter
		Debris:AddItem(stun, 1)
	end
end)

skillEvent.OnServerEvent:Connect(function(player, enemyCharacter, skillType, weaponType ,targetPosition)
	if not enemyCharacter then return end
	local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
	local enemyRoot = enemyCharacter:FindFirstChild("HumanoidRootPart")

	if not enemyHumanoid or not enemyRoot then return end
	if enemyHumanoid.Health <= 0 then return end

	if skillType == "E" then 
        local dmg = 30
				enemyHumanoid:TakeDamage(dmg)
        showDamageNumber(enemyCharacter, dmg, true) -- True for crit/heavy
        
        -- Tag creator
        local creatorTag = enemyHumanoid:FindFirstChild("creator")
        if not creatorTag then
            creatorTag = Instance.new("ObjectValue", enemyHumanoid)
            creatorTag.Name = "creator"
        end
        creatorTag.Value = player

	elseif skillType == "R" then 
		local dmg = 100
		enemyHumanoid:TakeDamage(dmg)
		showDamageNumber(enemyCharacter, dmg, true) -- True for crit/heavy

	-- Tag creator
		local creatorTag = enemyHumanoid:FindFirstChild("creator")
		if not creatorTag then
			creatorTag = Instance.new("ObjectValue", enemyHumanoid)
			creatorTag.Name = "creator"
		end
		creatorTag.Value = player
        
	elseif skillType == "Q" then
        local dmg = 5
		enemyHumanoid:TakeDamage(dmg)
        showDamageNumber(enemyCharacter, dmg, false)

		local targetPart = Instance.new("Part")
		targetPart.Position = targetPosition
		targetPart.Anchored = true
		targetPart.CanCollide = false
		targetPart.Transparency = 1
		targetPart.Parent = workspace
		Debris:AddItem(targetPart, 0.5)

		local attachment0 = Instance.new("Attachment", enemyRoot)
		local attachment1 = Instance.new("Attachment", targetPart)

		local alignPosition = Instance.new("AlignPosition", enemyRoot)
		alignPosition.Attachment0 = attachment0
		alignPosition.Attachment1 = attachment1
		alignPosition.RigidityEnabled = true

		Debris:AddItem(alignPosition, 0.5)
		Debris:AddItem(attachment0, 0.5)
		Debris:AddItem(attachment1, 0.5)
	end
end)
