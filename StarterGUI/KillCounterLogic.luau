script.Parent.Enabled = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local container = script.Parent:WaitForChild("MedievalKillHUD")

-- Standard UI
local base = container:WaitForChild("BasePlate")
local textLabel = base:WaitForChild("CountText")
local baseStroke = base:WaitForChild("BaseStroke")

-- Boss UI
local bossBase = container:WaitForChild("BossBasePlate")
local bossTextLabel = bossBase:WaitForChild("CountText")
local bossBaseStroke = bossBase:WaitForChild("BaseStroke")

-- Updated Paths pointing to your exact folder structure
local stageStats = ReplicatedStorage:WaitForChild("StageStats")
local currentLevel = stageStats:WaitForChild("StageNumber")
local killsFolder = stageStats:WaitForChild("Kills")
local killCount = ReplicatedStorage:WaitForChild("GlobalKillCount")
local bossKillCount = ReplicatedStorage:WaitForChild("BossKillCount")

local GOLD = Color3.fromRGB(185, 145, 75)
local RED_PULSE = Color3.fromRGB(220, 20, 20)
local TEXT_GOLD = Color3.fromRGB(230, 210, 160)
local TEXT_RED = Color3.fromRGB(255, 30, 30)

-- Hide boss UI by default when the game starts
bossBase.Visible = false

local function getDiamonds(targetBase)
	local diamonds = {}
	for _, child in ipairs(targetBase:GetChildren()) do
		if child.Name:find("Diamond") and child:IsA("Frame") and child:FindFirstChildOfClass("UIStroke") then
			table.insert(diamonds, child)
		end
	end
	return diamonds
end

local normalDiamonds = getDiamonds(base)
local bossDiamonds = getDiamonds(bossBase)

local function updateText(val)
	textLabel.Text = tostring(val) .. " / 25"
end

local function updateBossText(val)
	bossTextLabel.Text = "BOSS : " .. tostring(val) .. " / 1"
end

local function applyShakeAndFlash(targetBase, targetText, targetStroke, targetDiamonds)
	local originalPos = targetBase.Position
	local randX = math.random(-8, 8)
	local randY = math.random(-8, 8)

	targetBase.Position = originalPos + UDim2.new(0, randX, 0, randY)
	TweenService:Create(targetBase, TweenInfo.new(0.4, Enum.EasingStyle.Bounce), {Position = originalPos}):Play()

	TweenService:Create(targetText, TweenInfo.new(0.05), {TextColor3 = TEXT_RED}):Play()
	TweenService:Create(targetStroke, TweenInfo.new(0.05), {Color = RED_PULSE, Thickness = 5}):Play()

	for _, d in ipairs(targetDiamonds) do
		local str = d:FindFirstChildOfClass("UIStroke")
		if str then
			TweenService:Create(str, TweenInfo.new(0.05), {Color = RED_PULSE, Thickness = 3}):Play()
		end
		TweenService:Create(d, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = d.Rotation + 90}):Play()
	end

	task.delay(0.1, function()
		TweenService:Create(targetText, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {TextColor3 = TEXT_GOLD}):Play()
		TweenService:Create(targetStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {Color = GOLD, Thickness = 2.5}):Play()

		for _, d in ipairs(targetDiamonds) do
			local str = d:FindFirstChildOfClass("UIStroke")
			if str then
				TweenService:Create(str, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {Color = GOLD, Thickness = 1.5}):Play()
			end
		end
	end)
end

updateText(killCount.Value)
updateBossText(bossKillCount.Value)

-- This function decides if the Boss UI should be visible
local SOLO_POSITION = UDim2.new(0.5, 0,0.5, 0)       -- Where the normal counter sits on Levels 1 & 2
local DUO_TOP_POSITION = UDim2.new(0.5, 0,1.5, 0)    -- Where the normal counter slides to on Level 3
local DUO_BOTTOM_POSITION = UDim2.new(0.264, 0,0.5, 0) -- Where the boss counter slides to on Level 3

local function checkLevel()
	if currentLevel.Value == 3 then
		-- Snap the boss UI to the same starting spot as the main counter, then slide them both into position
		bossBase.Position = DUO_TOP_POSITION
		bossBase.Visible = true

		TweenService:Create(base, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {Position = DUO_TOP_POSITION}):Play()
		TweenService:Create(bossBase, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {Position = DUO_BOTTOM_POSITION}):Play()
	else
		bossBase.Visible = false

		-- Slide the main counter back to the center
		TweenService:Create(base, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), {Position = SOLO_POSITION}):Play()
	end
end

checkLevel()
currentLevel.Changed:Connect(checkLevel)

killCount.Changed:Connect(function(newVal)
	updateText(newVal)
	applyShakeAndFlash(base, textLabel, baseStroke, normalDiamonds)
end)

bossKillCount.Changed:Connect(function(newVal)
	updateBossText(newVal)
	applyShakeAndFlash(bossBase, bossTextLabel, bossBaseStroke, bossDiamonds)
end)