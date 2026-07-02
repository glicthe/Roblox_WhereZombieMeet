local Players = game:GetService("Players")

-- [Teleport Return Detection]
Players.PlayerAdded:Connect(function(player)
	local joinData = player:GetJoinData()
	if joinData and ((joinData.SourcePlaceId and joinData.SourcePlaceId ~= 0 and joinData.SourcePlaceId ~= game.PlaceId) or (joinData.TeleportData and type(joinData.TeleportData) == "table" and joinData.TeleportData.returningFromStage)) then
		player:SetAttribute("ReturningFromStage", true)
		print("[Lobby Server] Player returned from stage/raid via Teleport:", player.Name)
	end
end)
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
print("[QuestServer] QuestServer script loaded successfully! Starting initialization...")

local QuestData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestDataModule"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QuestDialogRemote = Remotes:WaitForChild("QuestDialogRemote")
local QuestOpenGUI = Remotes:WaitForChild("QuestOpenGUI")
local QuestAcceptRemote = Remotes:WaitForChild("QuestAcceptRemote")
local QuestClaimRemote = Remotes:WaitForChild("QuestClaimRemote")
local QuestProgressRemote = Remotes:WaitForChild("QuestProgressRemote")
local QuestCancelRemote = Remotes:WaitForChild("QuestCancelRemote")

-- DataStore
local questStore = DataStoreService:GetDataStore("PlayerQuestData_v1")

-- In-memory cache per player
local playerDataCache = {}

-- Default data structure
local function getDefaultData()
	return {
		acceptedQuests = {},
		progress = {},
		claimedQuests = {},
		coins = 0,
	}
end

-- Load player data from DataStore
local function loadPlayerData(player)
	local key = "player_" .. tostring(player.UserId)
	local success, data = pcall(function()
		return questStore:GetAsync(key)
	end)
	
	if success and data then
		-- Ensure all fields exist
		data.acceptedQuests = data.acceptedQuests or {}
		data.progress = data.progress or {}
		data.claimedQuests = data.claimedQuests or {}
		data.coins = data.coins or 0
		playerDataCache[player.UserId] = data
		print("[QuestServer] Loaded data for " .. player.Name)
	else
		playerDataCache[player.UserId] = getDefaultData()
		print("[QuestServer] Created new data for " .. player.Name)
	end
	
	QuestProgressRemote:FireClient(player, playerDataCache[player.UserId])
	return playerDataCache[player.UserId]
end

-- Save player data to DataStore
local function savePlayerData(player)
	local data = playerDataCache[player.UserId]
	if not data then return end
	
	local key = "player_" .. tostring(player.UserId)
	local success, err = pcall(function()
		questStore:SetAsync(key, data)
	end)
	
	if success then
		print("[QuestServer] Saved data for " .. player.Name)
	else
		warn("[QuestServer] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Find quest definition by id
local function findQuest(questId)
	for _, quest in ipairs(QuestData.Quests) do
		if quest.id == questId then
			return quest
		end
	end
	return nil
end

-- Check if quest is in a list
local function isInList(list, value)
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

-- ========== NPC ProximityPrompt Setup (Robust Retry Loop) ==========
task.spawn(function()
	local connected = false
	local attempts = 0
	while not connected and attempts < 60 do
		attempts = attempts + 1
		local npc = workspace:FindFirstChild("NPC Quest")
		if npc then
			local prompt = npc:FindFirstChild("QuestPrompt", true)
			if not prompt then
				local torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
				if torso then
					prompt = torso:FindFirstChild("QuestPrompt") or torso:WaitForChild("QuestPrompt", 2)
				end
			end
			if prompt then
				local targetParent = npc:FindFirstChild("Torso") or npc:FindFirstChild("Head") or prompt.Parent
				if targetParent and prompt.Parent ~= targetParent then
					prompt.Parent = targetParent
				end
				prompt.MaxActivationDistance = 25
				prompt.RequiresLineOfSight = false
				prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
				prompt.Enabled = true
				
				prompt.Triggered:Connect(function(player)
					print("[QuestServer] " .. player.Name .. " interacted with Junaedi (Prompt Triggered)")
					
					if not playerDataCache[player.UserId] then
						loadPlayerData(player)
					end
					
					QuestDialogRemote:FireClient(player, QuestData.Dialogs)
				end)
				connected = true
				print("[QuestServer] ProximityPrompt successfully connected and configured after " .. attempts .. " attempt(s)!")
				break
			end
		end
		task.wait(1)
	end
	if not connected then
		warn("[QuestServer] FAILED to connect ProximityPrompt on NPC Quest after 60 seconds!")
	end
end)
-- ========== Dialog complete -> Send quest data ==========
QuestDialogRemote.OnServerEvent:Connect(function(player, action)
	if action == "requestQuests" then
		local data = playerDataCache[player.UserId]
		if not data then
			data = loadPlayerData(player)
		end
		QuestOpenGUI:FireClient(player, data)
	end
end)

-- ========== Accept Quest ==========
QuestAcceptRemote.OnServerEvent:Connect(function(player, questId)
	local data = playerDataCache[player.UserId]
	if not data then return end
	
	local quest = findQuest(questId)
	if not quest then
		warn("[QuestServer] Quest not found: " .. tostring(questId))
		return
	end
	
	-- Check if already accepted or claimed
	if isInList(data.acceptedQuests, questId) then return end
	if isInList(data.claimedQuests, questId) then return end
	
	-- Accept quest
	table.insert(data.acceptedQuests, questId)
	data.progress[questId] = data.progress[questId] or 0
	print("[QuestServer] " .. player.Name .. " accepted quest: " .. quest.title)
	
	-- INSTANT REAL-TIME UPDATE TO CLIENT BEFORE SAVE:
	QuestProgressRemote:FireClient(player, data)
	
	task.spawn(function()
		savePlayerData(player)
	end)
end)
QuestCancelRemote.OnServerEvent:Connect(function(player, questId)
	local data = playerDataCache[player.UserId]
	if not data then return end
	
	local quest = findQuest(questId)
	if not quest then return end
	
	-- Remove from acceptedQuests
	local removed = false
	for i, id in ipairs(data.acceptedQuests) do
		if id == questId then
			table.remove(data.acceptedQuests, i)
			removed = true
			break
		end
	end
	
	if removed then
		print("[QuestServer] " .. player.Name .. " canceled quest: " .. quest.title)
		-- INSTANT REAL-TIME UPDATE TO CLIENT BEFORE SAVE:
		QuestProgressRemote:FireClient(player, data)
		task.spawn(function()
			savePlayerData(player)
		end)
	end
end)
QuestClaimRemote.OnServerEvent:Connect(function(player, questId)
	local data = playerDataCache[player.UserId]
	if not data then return end
	
	local quest = findQuest(questId)
	if not quest then return end
	
	-- Must be accepted
	if not isInList(data.acceptedQuests, questId) then return end
	-- Must not be already claimed
	if isInList(data.claimedQuests, questId) then return end
	
	-- Check progress
	local progress = data.progress[questId] or 0
	if progress < quest.goal then
		warn("[QuestServer] " .. player.Name .. " tried to claim incomplete quest: " .. questId)
		return
	end
	
	-- Grant reward
	data.coins = (data.coins or 0) + quest.reward
	
	-- Move to claimed
	table.insert(data.claimedQuests, questId)
	
	-- Remove from accepted
	for i, id in ipairs(data.acceptedQuests) do
		if id == questId then
			table.remove(data.acceptedQuests, i)
			break
		end
	end
	
	print("[QuestServer] " .. player.Name .. " claimed quest: " .. quest.title .. " | Reward: " .. quest.reward .. " coins | Total: " .. data.coins)
	-- INSTANT REAL-TIME UPDATE TO CLIENT BEFORE SAVE:
	QuestProgressRemote:FireClient(player, data)
	
	task.spawn(function()
		savePlayerData(player)
	end)
end)
local subscribeSuccess, subscribeErr = pcall(function()
	MessagingService:SubscribeAsync("QuestProgress", function(message)
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(message.Data)
		end)
		
		if not success or not decoded then return end
		
		local playerId = decoded.playerId
		local progressType = decoded.type
		local amount = decoded.amount or 1
		
		print("[QuestServer] Received cross-place progress: Player " .. tostring(playerId) .. " | Type: " .. tostring(progressType) .. " | Amount: " .. tostring(amount))
		
		-- Find the player if they're in this server
		local player = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == playerId then
				player = p
				break
			end
		end
		
		-- Update their data (either in cache or reload)
		local data = playerDataCache[playerId]
		if not data then
			-- Player not in server, update DataStore directly
			local key = "player_" .. tostring(playerId)
			local storeSuccess, storeData = pcall(function()
				return questStore:GetAsync(key)
			end)
			
			if storeSuccess and storeData then
				data = storeData
			else
				return -- Can't update, player data doesn't exist
			end
		end
		
		-- Update progress for matching quests
		for _, quest in ipairs(QuestData.Quests) do
			if quest.progressType == progressType and isInList(data.acceptedQuests, quest.id) then
				data.progress[quest.id] = (data.progress[quest.id] or 0) + amount
				print("[QuestServer] Updated quest " .. quest.id .. " progress to " .. data.progress[quest.id])
			end
		end
		
		-- Save updated data
		if player then
			playerDataCache[player.UserId] = data
			QuestProgressRemote:FireClient(player, data)
			task.spawn(function() savePlayerData(player) end)
		else
			-- Save directly to DataStore
			local key = "player_" .. tostring(playerId)
			pcall(function() questStore:SetAsync(key, data) end)
		end
	end)
end)

if subscribeSuccess then
	print("[QuestServer] MessagingService subscribed to QuestProgress")
else
	warn("[QuestServer] Failed to subscribe MessagingService: " .. tostring(subscribeErr))
end

-- ========== Player Joining / Leaving ==========
Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)
end)

-- Load data for players already in game (in case script starts late)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadPlayerData(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	task.spawn(function()
		savePlayerData(player)
		playerDataCache[player.UserId] = nil
	end)
end)

-- Save all on shutdown
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		pcall(function()
			savePlayerData(player)
		end)
	end
end)

print("[QuestServer] Initialized successfully")
