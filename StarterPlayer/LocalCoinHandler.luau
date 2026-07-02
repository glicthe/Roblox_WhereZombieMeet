local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local coinEvent = ReplicatedStorage:WaitForChild("CoinCollectedEvent")

local MAGNET_RANGE = 25

-- Table to track coins currently being magnetized to this player
local activeMagnets = {}
-- Table to track coins this player has already completely collected
local locallyCollected = {}

RunService.Heartbeat:Connect(function(dt)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Scan the workspace for Coins
	for _, coin in ipairs(workspace:GetChildren()) do
		if coin.Name == "Coin" and not locallyCollected[coin] then

			local dist = (root.Position - coin.Position).Magnitude

			-- 1. Idle Animation (Bobbing and Spinning)
			if not activeMagnets[coin] then
				local timeNow = tick()
				-- We use the coin's Y position as the base to bounce from
				local floatBaseY = coin:GetAttribute("BaseY")
				if not floatBaseY then 
					coin:SetAttribute("BaseY", coin.Position.Y)
					floatBaseY = coin.Position.Y
				end

				local newY = floatBaseY + math.sin(timeNow * 3) * 0.4
				coin.CFrame = CFrame.new(coin.Position.X, newY, coin.Position.Z) * CFrame.Angles(0, timeNow * 2, 0)

				-- Check if close enough to magnetize
				if dist < MAGNET_RANGE then
					activeMagnets[coin] = {speed = 5}
				end

				-- 2. Magnet Chase Logic
			else
				local magnetData = activeMagnets[coin]
				magnetData.speed = magnetData.speed + (dt * 100)

				local trail = coin:FindFirstChildOfClass("Trail")
				if trail then trail.Enabled = true end

				-- If it reached the player, send the claim to the server
				if dist < 1.5 or dist < (magnetData.speed * dt) then
					locallyCollected[coin] = true
					activeMagnets[coin] = nil
					coinEvent:FireServer(coin) -- Tell server we got it
				else
					-- Move towards player
					local dir = (root.Position - coin.Position).Unit
					local moveVec = dir * magnetData.speed * dt
					coin.CFrame = CFrame.new(coin.Position + moveVec) * CFrame.Angles(0, tick() * 10, 0)
				end
			end
		end
	end
end)

-- When the server confirms the collection, run the VFX
coinEvent.OnClientEvent:Connect(function(targetCoin)
	if not targetCoin then return end
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")

	-- FLOATING TEXT (3D Indicator)
	task.spawn(function()
		if not root then return end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 180, 0, 65)
		bb.StudsOffset = Vector3.new(math.random(5, 25)/10, math.random(15, 30)/10, math.random(-5, 5)/10)
		bb.Adornee = root
		bb.AlwaysOnTop = true
		bb.Parent = char

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.Text = "+5"
		txt.TextColor3 = Color3.fromRGB(255, 215, 0)
		txt.TextStrokeTransparency = 0
		txt.TextStrokeColor3 = Color3.fromRGB(80, 50, 0)
		txt.Font = Enum.Font.Antique
		txt.TextScaled = true
		txt.Parent = bb

		TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffset = bb.StudsOffset + Vector3.new(0, 4, 0)}):Play()
		TweenService:Create(txt, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		Debris:AddItem(bb, 1.5)
	end)

	-- SOUND EFFECT
	local coinSound = game:GetService("SoundService"):FindFirstChild("coins")
	if coinSound and coinSound:IsA("Sound") then
		local sClone = coinSound:Clone()
		sClone.Parent = root or char
		sClone:Play()
		Debris:AddItem(sClone, sClone.TimeLength > 0 and sClone.TimeLength + 1 or 5)
	end

	-- VFX Logic
	if root then
		local coinVFX = ReplicatedStorage:FindFirstChild("Coin Effect")
		if coinVFX and coinVFX:IsA("BasePart") then
			local vfxClone = coinVFX:Clone()
			vfxClone.Name = "CoinVFX_Clone"
			vfxClone.Transparency = 1
			vfxClone.CanCollide = false
			vfxClone.Massless = true
			vfxClone.Anchored = false
			vfxClone.CFrame = root.CFrame
			vfxClone.Parent = char

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = vfxClone
			weld.Parent = vfxClone

			local emitters = {}
			for _, child in ipairs(vfxClone:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child:Emit(child.Rate > 0 and child.Rate or 20)
					child.Enabled = true
					table.insert(emitters, child)
				end
			end

			task.delay(1.5, function()
				for _, emitter in ipairs(emitters) do emitter.Enabled = false end
			end)
			Debris:AddItem(vfxClone, 3.5)
		end

		local wsCoinVFX = ReplicatedStorage:FindFirstChild("WorkspaceCoinVFX")
		
		if wsCoinVFX and wsCoinVFX:IsA("BasePart") then
			local vfxClone2 = wsCoinVFX:Clone()
			vfxClone2.Name = "WorkspaceCoinVFX_Clone"
			vfxClone2.Transparency = 1
			vfxClone2.CanCollide = false
			vfxClone2.Massless = true
			vfxClone2.Anchored = false
			vfxClone2.CFrame = root.CFrame
			vfxClone2.Parent = char

			local weld2 = Instance.new("WeldConstraint")
			weld2.Part0 = root
			weld2.Part1 = vfxClone2
			weld2.Parent = vfxClone2

			local emitters2 = {}
			for _, child in ipairs(vfxClone2:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child:Emit(child.Rate > 0 and child.Rate or 20)
					child.Enabled = true
					table.insert(emitters2, child)
				end
			end

			task.delay(1.5, function()
				for _, emitter in ipairs(emitters2) do emitter.Enabled = false end
			end)
			Debris:AddItem(vfxClone2, 3.5)
		end
	end

	-- Destroy the coin LOCALLY only
	targetCoin:Destroy()
end)