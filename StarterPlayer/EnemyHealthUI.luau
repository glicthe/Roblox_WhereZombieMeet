-- EnemyHealthUI.lua (CLIENT)
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local function createPointedLayer(name, color, wScale, hScale, zindex, parent)
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.Size = UDim2.new(wScale, 0, hScale, 0)
	layer.Position = UDim2.new(0.5, 0, 0.5, 0)
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.BackgroundColor3 = color
	layer.BorderSizePixel = 0
	layer.ZIndex = zindex
	layer.Parent = parent

	local leftCap = Instance.new("Frame")
	leftCap.Name = "LeftCap"
	leftCap.SizeConstraint = Enum.SizeConstraint.RelativeYY
	leftCap.Size = UDim2.new(0.707, 0, 0.707, 0)
	leftCap.AnchorPoint = Vector2.new(0.5, 0.5)
	leftCap.Position = UDim2.new(0, 0, 0.5, 0)
	leftCap.Rotation = 45
	leftCap.BackgroundColor3 = color
	leftCap.BorderSizePixel = 0
	leftCap.ZIndex = zindex
	leftCap.Parent = layer

	local rightCap = leftCap:Clone()
	rightCap.Name = "RightCap"
	rightCap.Position = UDim2.new(1, 0, 0.5, 0)
	rightCap.Parent = layer

	return layer
end

local function createHealthBar(model)
	local head = model:WaitForChild("Head", 5)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not head or not humanoid then return end

	if head:FindFirstChild("ZombieHealthBar") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZombieHealthBar"
	billboard.Size = UDim2.new(3, 0, 0.4, 0)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 60
	billboard.ResetOnSpawn = false
	billboard.LightInfluence = 0
	billboard.Adornee = head
	billboard.Parent = head

	local root = Instance.new("Frame")
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = billboard
	root.Visible = (humanoid.Health > 0)

	local outerBorder = createPointedLayer("OuterBorder", Color3.fromRGB(50, 0, 0), 0.90, 0.8, 1, root)
	local innerBg     = createPointedLayer("InnerBg", Color3.fromRGB(16, 5, 5), 0.88, 0.6, 2, root)
	local track       = createPointedLayer("Track", Color3.fromRGB(5, 0, 0), 0.86, 0.4, 3, root)
	track.ClipsDescendants = true

	local barDelay = Instance.new("Frame")
	barDelay.Name = "BarDelay"
	barDelay.Size = UDim2.new(1, 0, 1, 0)
	barDelay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	barDelay.BorderSizePixel = 0
	barDelay.ZIndex = 4
	barDelay.Parent = track
	local delayGrad = Instance.new("UIGradient")
	delayGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	delayGrad.Parent = barDelay

	local barMain = Instance.new("Frame")
	barMain.Name = "BarMain"
	barMain.Size = UDim2.new(1, 0, 1, 0)
	barMain.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	barMain.BorderSizePixel = 0
	barMain.ZIndex = 5
	barMain.Parent = track
	local barGrad = Instance.new("UIGradient")
	barGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 10, 10)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 20, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 10, 10))
	})
	barGrad.Parent = barMain

	local shine = Instance.new("Frame")
	shine.Size = UDim2.new(1, 0, 0.3, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 200, 200)
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.ZIndex = 6
	shine.Parent = barMain

	local delayTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local lastDelayTween
	local isDead = false

	local function hideAndDestroy()
		if isDead then return end
		isDead = true

		local fadeTime = 0.5
		local tInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Linear)

		for _, v in ipairs(billboard:GetDescendants()) do
			if v:IsA("Frame") then
				TweenService:Create(v, tInfo, {BackgroundTransparency = 1}):Play()
			end
		end

		task.delay(fadeTime, function()
			if billboard and billboard.Parent then
				billboard:Destroy()
			end
		end)
	end

	local function onHealthChanged(newHp)
		if isDead then return end
		if newHp <= 0 then
			hideAndDestroy()
			return
		end

		local pct = math.clamp(newHp / humanoid.MaxHealth, 0, 1)
		barMain.Size = UDim2.new(pct, 0, 1, 0)
		barMain.Visible = true
		root.Visible = true

		if lastDelayTween then lastDelayTween:Cancel() end

		task.delay(0.3, function()
			if not barDelay or not barDelay.Parent then return end
			lastDelayTween = TweenService:Create(barDelay, delayTweenInfo, {Size = UDim2.new(pct, 0, 1, 0)})
			lastDelayTween:Play()
		end)
	end

	humanoid.HealthChanged:Connect(onHealthChanged)
	humanoid.Died:Connect(hideAndDestroy)

	-- Fallback: deteksi zombie model dihapus dari game
	model.AncestryChanged:Connect(function(_, newParent)
		if not newParent then
			if billboard and billboard.Parent then
				billboard:Destroy()
			end
		end
	end)

	-- Fallback loop: cek kondisi mati setiap 0.2 detik
	task.spawn(function()
		while not isDead do
			task.wait(0.2)
			if not model or not model.Parent then
				if billboard and billboard.Parent then billboard:Destroy() end
				break
			end
			if not humanoid or not humanoid.Parent then
				hideAndDestroy()
				break
			end
			if humanoid.Health <= 0 then
				hideAndDestroy()
				break
			end
		end
	end)
end

local function onZombieAdded(zombie)
	createHealthBar(zombie)
end

for _, zombie in ipairs(CollectionService:GetTagged("Zombie")) do
	task.spawn(function()
		onZombieAdded(zombie)
	end)
end

CollectionService:GetInstanceAddedSignal("Zombie"):Connect(onZombieAdded)
