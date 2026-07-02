local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local gui = script.Parent
local trackerFrame = gui:WaitForChild("TrackerFrame")
local iconBtn = gui:WaitForChild("QuestIconButton")
local countBadge = iconBtn:WaitForChild("CountBadge")
local countText = countBadge:WaitForChild("CountText")
local listContainer = trackerFrame:WaitForChild("ListContainer")
local noQuestsLabel = listContainer:WaitForChild("NoQuestsLabel")
local template = listContainer:WaitForChild("TrackerItemTemplate")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QuestOpenGUI = Remotes:WaitForChild("QuestOpenGUI")
local QuestProgressRemote = Remotes:WaitForChild("QuestProgressRemote")
local QuestCancelRemote = Remotes:WaitForChild("QuestCancelRemote")
local QuestDataModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestDataModule"))

local isVisible = false
local currentQuestData = nil

local function toggleTracker()
	isVisible = not isVisible
	-- Visible: next to left button at X = 82, Y = 0.46; Hidden: off-screen left at X = -320, Y = 0.46
	local targetPos = isVisible and UDim2.new(1, -368, 0, 65) or UDim2.new(1, 50, 0, 65)
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	TweenService:Create(trackerFrame, tweenInfo, {Position = targetPos}):Play()
	
	-- Animate icon button slightly on press
	TweenService:Create(iconBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 46, 0, 46)}):Play()
	task.delay(0.15, function()
		if iconBtn and iconBtn.Parent then
			TweenService:Create(iconBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 52, 0, 52)}):Play()
		end
	end)
end

-- Toggle via keyboard P key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggleTracker()
	end
end)

-- Toggle via clicking the QuestIconButton
iconBtn.MouseButton1Click:Connect(function()
	toggleTracker()
end)

local function findQuestInfo(questId)
	for _, q in ipairs(QuestDataModule.Quests) do
		if q.id == questId then
			return q
		end
	end
	return nil
end

local function updateTrackerDisplay()
	-- Clear old items
	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") and child.Name == "ActiveQuestItem" then
			child:Destroy()
		end
	end
	
	local acceptedCount = (currentQuestData and currentQuestData.acceptedQuests) and #currentQuestData.acceptedQuests or 0
	countText.Text = tostring(acceptedCount)
	countBadge.Visible = (acceptedCount > 0)
	
	if acceptedCount == 0 then
		noQuestsLabel.Visible = true
		return
	end
	
	noQuestsLabel.Visible = false
	
	for i, questId in ipairs(currentQuestData.acceptedQuests) do
		local quest = findQuestInfo(questId)
		if quest then
			local item = template:Clone()
			item.Name = "ActiveQuestItem"
			item.Visible = true
			item.LayoutOrder = i
			
			-- Tier Styling
			local tierInfo = QuestDataModule.TierColors[quest.tier] or QuestDataModule.TierColors["B"]
			item.TierStroke.Color = tierInfo.border
			
			-- Category Tag
			if quest.category == "RAID" or quest.category == "Raid" then
				item.CategoryTag.Text = "RAID"
				item.CategoryTag.BackgroundColor3 = Color3.fromRGB(80, 20, 120)
				item.CategoryTag.TextColor3 = Color3.fromRGB(220, 180, 255)
			else
				item.CategoryTag.Text = "CAMPAIGN"
				item.CategoryTag.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
				item.CategoryTag.TextColor3 = Color3.fromRGB(255, 200, 200)
			end
			
			-- Reward & Title
			item.RewardBadge.RewardAmount.Text = tostring(quest.reward)
			item.QuestTitle.Text = quest.title
			
			-- Progress
			local progress = 0
			if currentQuestData.progress and currentQuestData.progress[questId] then
				progress = currentQuestData.progress[questId]
			end
			local fillRatio = math.clamp(progress / quest.goal, 0, 1)
			item.ProgressBar.Fill.Size = UDim2.new(fillRatio, 0, 1, 0)
			item.ProgressBar.Fill.BackgroundColor3 = tierInfo.border
			item.ProgressBar.ProgressText.Text = tostring(progress) .. "/" .. tostring(quest.goal)
			
			-- Cancel Button Logic
			local cancelBtn = item:FindFirstChild("CancelBtn")
						if cancelBtn then
				cancelBtn.MouseButton1Click:Connect(function()
					-- Play subtle click/cancel feedback
					TweenService:Create(cancelBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 50, 50)}):Play()
					
					-- INSTANT OPTIMISTIC CLIENT-SIDE UPDATE (0ms lag!):
					if currentQuestData and currentQuestData.acceptedQuests then
						for idx, qId in ipairs(currentQuestData.acceptedQuests) do
							if qId == quest.id then
								table.remove(currentQuestData.acceptedQuests, idx)
								break
							end
						end
						updateTrackerDisplay()
					end
					
					QuestCancelRemote:FireServer(quest.id)
				end)
			end
			
			item.Parent = listContainer
		end
	end
end

QuestOpenGUI.OnClientEvent:Connect(function(data)
	currentQuestData = data
	updateTrackerDisplay()
end)

QuestProgressRemote.OnClientEvent:Connect(function(data)
	currentQuestData = data
	updateTrackerDisplay()
end)

-- Initial display check
updateTrackerDisplay()


-- Automatic Main Menu Detection (Hide icon while in menu, show when entering game)
local player = Players.LocalPlayer
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then return end
	
	local function updateHUDVisibility()
		local mainMenu = playerGui:FindFirstChild("ScreenGui")
		if mainMenu and mainMenu.Enabled then
			gui.Enabled = false
		else
			gui.Enabled = true
		end
	end
	
	updateHUDVisibility()
	
	local mainMenu = playerGui:FindFirstChild("ScreenGui")
	if mainMenu then
		mainMenu:GetPropertyChangedSignal("Enabled"):Connect(updateHUDVisibility)
		mainMenu.Destroying:Connect(function()
			gui.Enabled = true
		end)
	end
	
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "ScreenGui" then
			child:GetPropertyChangedSignal("Enabled"):Connect(updateHUDVisibility)
			updateHUDVisibility()
		end
	end)
	playerGui.ChildRemoved:Connect(function(child)
		if child.Name == "ScreenGui" then
			updateHUDVisibility()
		end
	end)
end)
