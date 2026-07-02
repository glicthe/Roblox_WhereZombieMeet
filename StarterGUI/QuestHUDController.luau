local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local QuestData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestDataModule"))

local gui = script.Parent
local bg = gui:WaitForChild("Background")
local ornament = bg:WaitForChild("OrnamentContainer")
local center = bg:WaitForChild("CenterStripe")
local title = center:WaitForChild("Title")
local listContainer = bg:WaitForChild("QuestListContainer")
local scroll = listContainer:WaitForChild("ScrollingFrame")
local template = scroll:WaitForChild("QuestItemTemplate")
local closeBtnFrame = bg:WaitForChild("CloseBtn")
local closeBtnText = closeBtnFrame:WaitForChild("ActionBtn")

local hoverSound = gui:FindFirstChild("hover")
local clickSound = gui:FindFirstChild("button")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QuestOpenGUI = Remotes:WaitForChild("QuestOpenGUI")
local QuestAcceptRemote = Remotes:WaitForChild("QuestAcceptRemote")
local QuestClaimRemote = Remotes:WaitForChild("QuestClaimRemote")
local QuestProgressRemote = Remotes:WaitForChild("QuestProgressRemote")

local isVisible = false
local currentPlayerData = nil

-- Collect all elements to fade
local elementsToFade = {}

local function collectFadeElements()
	elementsToFade = {
		{obj = center, prop = "BackgroundTransparency", targetVal = 0.3},
		{obj = title, prop = "TextTransparency", targetVal = 0},
		{obj = listContainer, prop = "BackgroundTransparency", targetVal = 0.15},
		{obj = closeBtnFrame, prop = "BackgroundTransparency", targetVal = 0},
		{obj = closeBtnText, prop = "TextTransparency", targetVal = 0},
		{obj = closeBtnText, prop = "BackgroundTransparency", targetVal = 0.2},
	}
	
	-- Ornament strokes
	for _, child in ipairs(ornament:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("UIStroke") then
			table.insert(elementsToFade, {obj = child.UIStroke, prop = "Transparency", targetVal = 0.4})
		end
	end
	
	-- Center stripe borders
	local topBorder = center:FindFirstChild("TopBorder")
	local botBorder = center:FindFirstChild("BottomBorder")
	if topBorder then table.insert(elementsToFade, {obj = topBorder, prop = "BackgroundTransparency", targetVal = 0}) end
	if botBorder then table.insert(elementsToFade, {obj = botBorder, prop = "BackgroundTransparency", targetVal = 0}) end
	
	-- List container stroke
	local listStroke = listContainer:FindFirstChild("UIStroke")
	if listStroke then table.insert(elementsToFade, {obj = listStroke, prop = "Transparency", targetVal = 0.2}) end
	
	-- Close button decorations
	local outerBorder = closeBtnFrame:FindFirstChild("BorderOuter")
	if outerBorder then table.insert(elementsToFade, {obj = outerBorder, prop = "Transparency", targetVal = 0}) end
	
	local innerBorder = closeBtnFrame:FindFirstChild("BorderInner")
	if innerBorder and innerBorder:FindFirstChild("Stroke") then
		table.insert(elementsToFade, {obj = innerBorder.Stroke, prop = "Transparency", targetVal = 0})
	end
	
	for _, child in ipairs(closeBtnFrame:GetChildren()) do
		if child.Name:match("Diamond") then
			table.insert(elementsToFade, {obj = child, prop = "BackgroundTransparency", targetVal = 0})
		end
	end
end

local function hideAll()
	bg.BackgroundTransparency = 1
	for _, item in ipairs(elementsToFade) do
		pcall(function()
			if item.prop == "Transparency" then
				item.obj.Transparency = 1
			else
				item.obj[item.prop] = 1
			end
		end)
	end
end

-- Get tier color data
local function getTierColor(tier)
	return QuestData.TierColors[tier] or QuestData.TierColors["B"]
end

-- Get quest status: "available", "active", "claimable", "claimed"
local function getQuestStatus(questId, playerData)
	if not playerData then return "available" end
	
	-- Check if claimed
	if playerData.claimedQuests then
		for _, id in ipairs(playerData.claimedQuests) do
			if id == questId then return "claimed" end
		end
	end
	
	-- Check if accepted
	local isAccepted = false
	if playerData.acceptedQuests then
		for _, id in ipairs(playerData.acceptedQuests) do
			if id == questId then isAccepted = true break end
		end
	end
	
	if not isAccepted then return "available" end
	
	-- Check progress
	local progress = 0
	if playerData.progress and playerData.progress[questId] then
		progress = playerData.progress[questId]
	end
	
	-- Find quest goal
	for _, quest in ipairs(QuestData.Quests) do
		if quest.id == questId then
			if progress >= quest.goal then
				return "claimable"
			else
				return "active"
			end
		end
	end
	
	return "active"
end

-- Populate quest items
local function populateQuests(playerData)
	currentPlayerData = playerData
	
	-- Clear old dynamic items
	for _, child in ipairs(scroll:GetChildren()) do
		if child.Name == "QuestItem_Dynamic" then
			child:Destroy()
		end
	end
	
	-- Sort quests: S first, then A, then B
	local tierOrder = {S = 1, A = 2, B = 3}
	local sortedQuests = {}
	for _, q in ipairs(QuestData.Quests) do
		table.insert(sortedQuests, q)
	end
	table.sort(sortedQuests, function(a, b)
		return (tierOrder[a.tier] or 99) < (tierOrder[b.tier] or 99)
	end)
	
	for i, quest in ipairs(sortedQuests) do
		local item = template:Clone()
		item.Name = "QuestItem_Dynamic"
		item.Visible = true
		item.LayoutOrder = i
		item.Parent = scroll
		
		-- Set tier visuals
		local tierInfo = getTierColor(quest.tier)
		item.TierStroke.Color = tierInfo.border
		item.TierBadge.Text = tierInfo.label
		item.TierBadge.BackgroundColor3 = tierInfo.border
		
		-- Set quest info
		item.QuestTitle.Text = quest.title
		item.QuestDesc.Text = quest.description
		item.RewardContainer.RewardAmount.Text = tostring(quest.reward)
		
		-- Category tag
		if quest.category == "RAID" or quest.category == "Raid" then
			item.CategoryTag.Text = "RAID"
			item.CategoryTag.BackgroundColor3 = Color3.fromRGB(80, 20, 120)
			item.CategoryTag.TextColor3 = Color3.fromRGB(220, 180, 255)
		else
			item.CategoryTag.Text = "CAMPAIGN"
			item.CategoryTag.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
			item.CategoryTag.TextColor3 = Color3.fromRGB(255, 200, 200)
		end
		
		-- Progress
		local progress = 0
		if playerData and playerData.progress and playerData.progress[quest.id] then
			progress = playerData.progress[quest.id]
		end
		
		local fillRatio = math.clamp(progress / quest.goal, 0, 1)
		item.ProgressBar.Fill.Size = UDim2.new(fillRatio, 0, 1, 0)
		item.ProgressBar.Fill.BackgroundColor3 = tierInfo.border
		item.ProgressText.Text = tostring(progress) .. "/" .. tostring(quest.goal)
		
		-- Status & button
		local status = getQuestStatus(quest.id, playerData)
		local actionBtn = item.ActionBtn
		
		if status == "available" then
			actionBtn.Text = "ACCEPT"
			actionBtn.BackgroundColor3 = Color3.fromRGB(60, 10, 10)
		elseif status == "active" then
			actionBtn.Text = "ACTIVE"
			actionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			actionBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
		elseif status == "claimable" then
			actionBtn.Text = "CLAIM!"
			actionBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 20)
			actionBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif status == "claimed" then
			actionBtn.Text = "COMPLETED \226\156\147"
			actionBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			actionBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
		end
		
		-- Button click handler
		actionBtn.MouseButton1Click:Connect(function()
			if clickSound then clickSound:Play() end
			
			if status == "available" then
				QuestAcceptRemote:FireServer(quest.id)
				actionBtn.Text = "ACTIVE"
				actionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				actionBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
				status = "active"
			elseif status == "claimable" then
				QuestClaimRemote:FireServer(quest.id)
				actionBtn.Text = "COMPLETED \226\156\147"
				actionBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				actionBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
				status = "claimed"
			end
		end)
		
		-- Hover effects
		actionBtn.MouseEnter:Connect(function()
			if hoverSound then hoverSound:Play() end
			if status == "available" or status == "claimable" then
				TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 25, 25)}):Play()
			end
		end)
		
		actionBtn.MouseLeave:Connect(function()
			TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 15, 15)}):Play()
		end)
	end
end

-- Open Quest Board
local function openQuestBoard(playerData)
	collectFadeElements()
	hideAll()
	isVisible = true
	
	populateQuests(playerData)
	
	gui.Enabled = true
	
	-- Fade in background
	TweenService:Create(bg, TweenInfo.new(1.2, Enum.EasingStyle.Cubic), {BackgroundTransparency = 0}):Play()
	task.wait(0.3)
	
	-- Fade in all elements
	for _, item in ipairs(elementsToFade) do
		local props = {}
		props[item.prop] = item.targetVal
		pcall(function()
			TweenService:Create(item.obj, TweenInfo.new(1.5, Enum.EasingStyle.Cubic), props):Play()
		end)
	end
	
	-- Fade in quest items
	task.wait(0.3)
	for _, child in ipairs(scroll:GetChildren()) do
		if child.Name == "QuestItem_Dynamic" then
			for _, subChild in ipairs(child:GetDescendants()) do
				pcall(function()
					if subChild:IsA("TextLabel") or subChild:IsA("TextButton") then
						local currentTransp = subChild.TextTransparency
						subChild.TextTransparency = 1
						TweenService:Create(subChild, TweenInfo.new(1, Enum.EasingStyle.Cubic), {TextTransparency = 0}):Play()
						if subChild.BackgroundTransparency < 1 then
							local targetBg = subChild.BackgroundTransparency
							subChild.BackgroundTransparency = 1
							TweenService:Create(subChild, TweenInfo.new(1, Enum.EasingStyle.Cubic), {BackgroundTransparency = targetBg}):Play()
						end
					end
				end)
			end
			-- Fade the card itself
			local targetBg = child.BackgroundTransparency
			child.BackgroundTransparency = 1
			TweenService:Create(child, TweenInfo.new(1, Enum.EasingStyle.Cubic), {BackgroundTransparency = targetBg}):Play()
			-- Fade tier stroke
			if child:FindFirstChild("TierStroke") then
				child.TierStroke.Transparency = 1
				TweenService:Create(child.TierStroke, TweenInfo.new(1, Enum.EasingStyle.Cubic), {Transparency = 0.1}):Play()
			end
		end
	end
end

-- Close Quest Board
local function closeQuestBoard()
	isVisible = false
	local fadeTime = 0.5
	
	TweenService:Create(bg, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
	for _, item in ipairs(elementsToFade) do
		local props = {}
		props[item.prop] = 1
		pcall(function()
			TweenService:Create(item.obj, TweenInfo.new(fadeTime), props):Play()
		end)
	end
	
	-- Fade out quest items
	for _, child in ipairs(scroll:GetChildren()) do
		if child.Name == "QuestItem_Dynamic" then
			TweenService:Create(child, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
			for _, subChild in ipairs(child:GetDescendants()) do
				pcall(function()
					if subChild:IsA("TextLabel") or subChild:IsA("TextButton") then
						TweenService:Create(subChild, TweenInfo.new(fadeTime), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
					end
					if subChild:IsA("UIStroke") then
						TweenService:Create(subChild, TweenInfo.new(fadeTime), {Transparency = 1}):Play()
					end
				end)
			end
		end
	end
	
	task.wait(fadeTime)
	gui.Enabled = false
end

-- Close button
closeBtnText.MouseButton1Click:Connect(function()
	if isVisible then
		if clickSound then clickSound:Play() end
		closeQuestBoard()
	end
end)

-- Hover for close button
local hoverIn = TweenService:Create(closeBtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 10, 10)})
local hoverOut = TweenService:Create(closeBtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 0, 0)})

closeBtnText.MouseEnter:Connect(function()
	if isVisible then
		hoverIn:Play()
		if hoverSound then hoverSound:Play() end
	end
end)

closeBtnText.MouseLeave:Connect(function()
	if isVisible then hoverOut:Play() end
end)

-- Listen for server to open quest board
QuestOpenGUI.OnClientEvent:Connect(function(playerData)
	openQuestBoard(playerData)
end)

-- Listen for progress updates
QuestProgressRemote.OnClientEvent:Connect(function(playerData)
	if isVisible then
		populateQuests(playerData)
	end
end)
