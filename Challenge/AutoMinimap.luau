local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local radarGui = Instance.new("ScreenGui")
radarGui.Name = "RadarGui"
radarGui.ResetOnSpawn = false
radarGui.Parent = playerGui

local minimapFrame = Instance.new("Frame")
minimapFrame.Size = UDim2.new(0, 180, 0, 180)
minimapFrame.Position = UDim2.new(1, -230, 0, -20)
minimapFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
minimapFrame.BackgroundTransparency = 0.4
minimapFrame.ClipsDescendants = true
minimapFrame.Parent = radarGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(1, 0)
frameCorner.Parent = minimapFrame

local RADAR_RADIUS = 150 
local BLIP_CACHE = {}

local function createBlip(parent)
	local blip = Instance.new("Frame")
	blip.AnchorPoint = Vector2.new(0.5, 0.5)
	local c = Instance.new("UICorner")
	c.Parent = blip
	blip.Parent = parent

	local blipData = {
		frame = blip,
		corner = c
	}
	table.insert(BLIP_CACHE, blipData)
	return blipData
end

local centerBlipData = createBlip(minimapFrame)
centerBlipData.frame.Size = UDim2.new(0, 8, 0, 8)
centerBlipData.frame.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
centerBlipData.frame.Position = UDim2.new(0.5, 0, 0.5, 0)
centerBlipData.frame.ZIndex = 10
centerBlipData.corner.CornerRadius = UDim.new(1, 0)

local camera = Workspace.CurrentCamera

RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local camLook = camera.CFrame.LookVector
	local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
	if flatLook.Magnitude > 0.001 then
		flatLook = flatLook.Unit
	else
		flatLook = Vector3.new(0, 0, -1)
	end
	local camRotationCFrame = CFrame.lookAt(Vector3.zero, flatLook)

	for _, data in ipairs(BLIP_CACHE) do
		if data ~= centerBlipData then
			data.frame.Visible = false
		end
	end

	local activeTargets = {}

	for _, room in ipairs(CollectionService:GetTagged("RadarRoom")) do
		table.insert(activeTargets, {model = room, color = Color3.fromRGB(100, 100, 100), size = UDim2.new(0, 24, 0, 24), zIndex = 1, isStruct = true, shape = "Room"})
	end

	for _, road in ipairs(CollectionService:GetTagged("RadarRoad")) do
		table.insert(activeTargets, {model = road, color = Color3.fromRGB(70, 70, 70), size = UDim2.new(0, 10, 0, 22), zIndex = 1, isStruct = true, shape = "Road"})
	end

	for _, zombie in ipairs(CollectionService:GetTagged("Zombie")) do
		table.insert(activeTargets, {model = zombie, color = Color3.fromRGB(255, 50, 50), size = UDim2.new(0, 6, 0, 6), zIndex = 5, isStruct = false})
	end

	for _, boss in ipairs(CollectionService:GetTagged("BossZombie")) do
		table.insert(activeTargets, {model = boss, color = Color3.fromRGB(180, 50, 255), size = UDim2.new(0, 10, 0, 10), zIndex = 6, isStruct = false})
	end

	local maxUIOffset = minimapFrame.AbsoluteSize.X / 2
	local scale = maxUIOffset / RADAR_RADIUS
	local blipIndex = 2 

	for _, target in ipairs(activeTargets) do
		local targetPos
		local isValid = false

		if target.isStruct then
			targetPos = target.model:GetPivot().Position
			isValid = true
		else
			local targetRoot = target.model:FindFirstChild("HumanoidRootPart")
			local targetHum = target.model:FindFirstChild("Humanoid")
			if targetRoot and targetHum and targetHum.Health > 0 then
				targetPos = targetRoot.Position
				isValid = true
			end
		end

		if isValid then
			local worldOffset = targetPos - root.Position

			if worldOffset.Magnitude <= RADAR_RADIUS then
				local blipData = BLIP_CACHE[blipIndex]
				if not blipData then
					blipData = createBlip(minimapFrame)
				end

				blipData.frame.BackgroundColor3 = target.color
				blipData.frame.Size = target.size
				blipData.frame.ZIndex = target.zIndex

				-- Apply specific corner radii based on the shape type
				if target.shape == "Road" then
					blipData.corner.CornerRadius = UDim.new(0, 0) -- Sharp Rectangle
				elseif target.shape == "Room" then
					blipData.corner.CornerRadius = UDim.new(0.15, 0) -- Slightly Rounded Square
				else
					blipData.corner.CornerRadius = UDim.new(1, 0) -- Circle for entities
				end

				local relativeOffset = camRotationCFrame:VectorToObjectSpace(worldOffset)
				blipData.frame.Position = UDim2.new(0.5, relativeOffset.X * scale, 0.5, relativeOffset.Z * scale)

				-- Rotate the rectangles to match their physical orientation
				if target.isStruct then
					local objLook = target.model:GetPivot().LookVector
					local relLook = camRotationCFrame:VectorToObjectSpace(objLook)
					blipData.frame.Rotation = math.deg(math.atan2(relLook.X, -relLook.Z))
				else
					blipData.frame.Rotation = 0
				end

				blipData.frame.Visible = true

				blipIndex += 1
			end
		end
	end
end)