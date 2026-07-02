local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = script.Parent
local bg = gui:WaitForChild("Background")
local ornament = bg:WaitForChild("OrnamentContainer")
local center = bg:WaitForChild("CenterStripe")
local title = center:WaitForChild("Title")
local stats = bg:WaitForChild("StatsPanel")
local btnContainer = bg:WaitForChild("NextStageBtn")
local btnText = btnContainer:WaitForChild("ActionBtn")

local hoverSound = game:GetService("SoundService"):FindFirstChild("hover")
local clickSound = game:GetService("SoundService"):FindFirstChild("button")

local isVisible = false
local hasVoted = false -- Prevents spamming the button locally

local elementsToFade = {
	{obj = center, prop = "BackgroundTransparency", targetVal = 0},
	{obj = center:GetChildren()[2], prop = "BackgroundTransparency", targetVal = 0},
	{obj = center:GetChildren()[3], prop = "BackgroundTransparency", targetVal = 0},
	{obj = title, prop = "TextTransparency", targetVal = 0},
	{obj = stats, prop = "BackgroundTransparency", targetVal = 0.2},
	{obj = stats:WaitForChild("UIStroke"), prop = "Transparency", targetVal = 0},
	{obj = stats:WaitForChild("MapCleared"), prop = "TextTransparency", targetVal = 0},
	{obj = stats:WaitForChild("TimeElapsed"), prop = "TextTransparency", targetVal = 0},
	{obj = btnContainer, prop = "BackgroundTransparency", targetVal = 0},
	{obj = btnContainer:WaitForChild("BorderOuter"), prop = "Transparency", targetVal = 0},
	{obj = btnContainer:WaitForChild("BorderInner"):WaitForChild("Stroke"), prop = "Transparency", targetVal = 0},
	{obj = btnText, prop = "TextTransparency", targetVal = 0},
}

for _, child in ipairs(ornament:GetChildren()) do
	if child:IsA("Frame") and child:FindFirstChild("UIStroke") then
		table.insert(elementsToFade, {obj = child.UIStroke, prop = "Transparency", targetVal = 0})
	end
end

for _, child in ipairs(btnContainer:GetChildren()) do
	if child.Name == "Frame" and child:FindFirstChild("UIStroke") then
		table.insert(elementsToFade, {obj = child, prop = "BackgroundTransparency", targetVal = 0})
		table.insert(elementsToFade, {obj = child.UIStroke, prop = "Transparency", targetVal = 0})
	end
end

local function hideAll()
	bg.BackgroundTransparency = 1
	for _, item in ipairs(elementsToFade) do
		item.obj[item.prop] = 1
	end
end

hideAll()

-- NEW: Extracted the fade-out logic so the server can trigger it
local function closeUI()
	isVisible = false
	TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
	for _, item in ipairs(elementsToFade) do
		local props = {}
		props[item.prop] = 1
		TweenService:Create(item.obj, TweenInfo.new(0.5), props):Play()
	end
	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local darkSoulsHUD = playerGui:FindFirstChild("DarkSoulsHUD")
	if darkSoulsHUD then
		darkSoulsHUD.Enabled = true
	end
end

local hoverIn = TweenService:Create(btnContainer, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 10, 10)})
local hoverOut = TweenService:Create(btnContainer, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 0, 0)})

btnText.MouseEnter:Connect(function() 
	if isVisible and not hasVoted then 
		hoverIn:Play() 
		if hoverSound then hoverSound:Play() end
	end 
end)

btnText.MouseLeave:Connect(function() 
	if isVisible and not hasVoted then 
		hoverOut:Play() 
	end 
end)

btnText.MouseButton1Click:Connect(function()
	if isVisible and not hasVoted then
		hasVoted = true -- Lock the button locally
		if clickSound then clickSound:Play() end

		if btnText.Text:match("RETURN") or title.Text:match("VICTORY") then
			btnText.Text = "RETURNING TO LOBBY..."
			
			-- [Smooth Instant Transition Overlay]
			local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
			local transGui = Instance.new("ScreenGui")
			transGui.Name = "TeleportTransitionGui"
			transGui.DisplayOrder = 100000
			transGui.IgnoreGuiInset = true
			transGui.Parent = playerGui
			
			local blackFrame = Instance.new("Frame")
			blackFrame.Size = UDim2.new(1, 0, 1, 0)
			blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			blackFrame.BackgroundTransparency = 1
			blackFrame.Parent = transGui
			
			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 0, 50)
			textLabel.Position = UDim2.new(0, 0, 0.5, -25)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = "RETURNING TO LOBBY..."
			textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextSize = 24
			textLabel.TextTransparency = 1
			textLabel.Parent = blackFrame
			
			TweenService:Create(blackFrame, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()
			TweenService:Create(textLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
		else
			btnText.Text = "WAITING FOR OTHERS..."
		end

		-- Tell server we are ready
		ReplicatedStorage:WaitForChild("NextLevelEvent"):FireServer()
	end
end)

-- NEW: Listen for the server to update the ready count
local syncEvent = ReplicatedStorage:WaitForChild("SyncReadyCount")
syncEvent.OnClientEvent:Connect(function(readyCount, totalPlayers)
	if not isVisible then return end

	-- Update the text to show the live fraction
	btnText.Text = "WAITING... (" .. readyCount .. "/" .. totalPlayers .. " READY)"

	-- If everyone is ready, close the UI
	if readyCount >= totalPlayers then
		closeUI()
	end
end)

local re = ReplicatedStorage:WaitForChild("ShowStageCleared")
re.OnClientEvent:Connect(function(stageNum, timeStr, playerStats)
	hasVoted = false -- Reset vote lock for the new stage

	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local darkSoulsHUD = playerGui:FindFirstChild("DarkSoulsHUD")
	if darkSoulsHUD then
		darkSoulsHUD.Enabled = false
	end

	if stageNum == 1 then
		title.Text = "STAGE CLEAR"
		btnText.Text = "PROCEED TO STAGE 2"
	elseif stageNum == 2 then
		title.Text = "STAGE CLEAR"
		btnText.Text = "PROCEED TO BOSS STAGE"
	else
		title.Text = "VICTORY ACHIEVED"
		btnText.Text = "RETURN TO LOBBY"
	end

	stats.TimeElapsed.Text = "TIME ELAPSED: " .. tostring(timeStr)

	-- Cleanup old dynamic player rows if any
	for _, child in ipairs(stats:GetChildren()) do
		if child.Name == "PlayerRow_Dynamic" then
			child:Destroy()
		end
	end

	-- Generate new rows dynamically
	local template = stats:FindFirstChild("EnemiesSlain")
	if template then
		template.Visible = false -- hide the original
		local yOffset = template.Position.Y.Offset

		for i, pStat in ipairs(playerStats) do
			local newRow = template:Clone()
			newRow.Name = "PlayerRow_Dynamic"
			newRow.Text = pStat.name .. " - KILLS: " .. pStat.kills .. " | GOLD: " .. pStat.coins
			newRow.Position = UDim2.new(template.Position.X.Scale, template.Position.X.Offset, template.Position.Y.Scale, yOffset + ((i-1) * 35))
			newRow.Visible = true
			newRow.Parent = stats

			-- Re-add to fade table for animation
			table.insert(elementsToFade, {obj = newRow, prop = "TextTransparency", targetVal = 0})
		end
	end

	hideAll()
	isVisible = true

	TweenService:Create(bg, TweenInfo.new(1.5, Enum.EasingStyle.Cubic), {BackgroundTransparency = 0}):Play()
	task.wait(0.5)

	for _, item in ipairs(elementsToFade) do
		local props = {}
		props[item.prop] = item.targetVal
		TweenService:Create(item.obj, TweenInfo.new(2, Enum.EasingStyle.Cubic), props):Play()
	end
end)