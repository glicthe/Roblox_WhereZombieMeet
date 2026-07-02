local TeleportService = game:GetService("TeleportService")
local TARGET_PLACE_ID = 136387127409210


local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup("EnemyZombies")
PhysicsService:CollisionGroupSetCollidable("EnemyZombies", "EnemyZombies", false)

local nextLevelEvent = ReplicatedStorage:WaitForChild("NextLevelEvent")


local POOL_1WAY = ServerStorage:WaitForChild("1_Way")
local POOL_2WAY = ServerStorage:WaitForChild("2_Way")
local POOL_3WAY = ServerStorage:WaitForChild("3_Way")
local POOL_4WAY = ServerStorage:WaitForChild("4_Way")

local roadTemplate   = ServerStorage:WaitForChild("RoadSegment")
local spawnTemplate  = ServerStorage:WaitForChild("SpawnPlace")
local endCapTemplate = ServerStorage:WaitForChild("EndCap")
local zombiePool     = ServerStorage:WaitForChild("ZombiePool")
local bossTemplate = ServerStorage:WaitForChild("BossZombie")
local stageStats = ReplicatedStorage:WaitForChild("StageStats")
local stageNumber = stageStats:WaitForChild("StageNumber")
local killsFolder = stageStats:WaitForChild("Kills")
local killCount = ReplicatedStorage:WaitForChild("GlobalKillCount")
local bossKillCount = ReplicatedStorage:WaitForChild("BossKillCount")

local currentLevel = stageNumber.Value
local MAX_LEVELS = 3

local function getAttachments(model)
	local attachments = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Attachment") then
			table.insert(attachments, desc)
		end
	end
	return attachments
end

local function getAlignedCFrame(targetSocket, incomingSocket, newModel)
	local targetWorldCFrame = targetSocket.WorldCFrame * CFrame.Angles(0, math.pi, 0)
	local currentSocketWorld = incomingSocket.WorldCFrame
	local offsetToPivot = currentSocketWorld:Inverse() * newModel:GetPivot()
	return targetWorldCFrame * offsetToPivot
end

local function getPrimaryBox(model)
	local primary = model.PrimaryPart
	if primary then return primary.CFrame, primary.Size end
	local cf, size = model:GetBoundingBox()
	return cf, Vector3.new(
		math.max(0.1, size.X - 4), 
		math.max(0.1, size.Y - 0.5), 
		math.max(0.1, size.Z - 4)
	)
end

local function isSpaceOccupied(cf, size, container, ignoreModel)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {container}
	overlapParams.FilterType = Enum.RaycastFilterType.Include

	local parts = game.Workspace:GetPartBoundsInBox(cf, size, overlapParams)
	for _, part in ipairs(parts) do
		if ignoreModel == nil or not part:IsDescendantOf(ignoreModel) then 
			return true 
		end
	end
	return false
end

local function pickFrom(folder)
	local models = folder:GetChildren()
	if #models == 0 then return nil end
	return models[math.random(1, #models)]:Clone()
end

local function buildCandidateList(poolsPlaced, lastPoolType, slotsLeft)
	local candidates = {}
	local allowDeadEnd = poolsPlaced >= 1
	if poolsPlaced > 3 then allowDeadEnd = true else allowDeadEnd = false end
	if slotsLeft == 1 then return {POOL_1WAY} end
	if allowDeadEnd then table.insert(candidates, POOL_1WAY) end
	if lastPoolType ~= POOL_2WAY then table.insert(candidates, POOL_2WAY) end
	table.insert(candidates, POOL_3WAY)
	table.insert(candidates, POOL_4WAY)
	if #candidates == 0 then candidates = {POOL_3WAY, POOL_4WAY} end
	return candidates
end

local function getRandomModel(poolsPlaced, lastPoolType, slotsLeft)
	local candidates = buildCandidateList(poolsPlaced, lastPoolType, slotsLeft)
	local folder = candidates[math.random(1, #candidates)]
	local model  = pickFrom(folder)
	return model, folder
end

local function spawnZombiesPerWay(placedWays, amountPerWay)
	local enemyFolder = Workspace:FindFirstChild("Enemies")
	if not enemyFolder then
		enemyFolder = Instance.new("Folder")
		enemyFolder.Name = "Enemies"
		enemyFolder.Parent = Workspace
	end

	local availableZombies = zombiePool:GetChildren()
	if #availableZombies == 0 or #placedWays == 0 then return end

	local MIN_DISTANCE = 6 
	
	local totalSpawned = 0

	for _, wayModel in ipairs(placedWays) do
		local cf, size = getPrimaryBox(wayModel)
		local localPositions = {} 

		local zombiesInThisWay = 0
		local spawnAttempts = 0
		local MAX_ATTEMPTS = 200 

		while zombiesInThisWay < amountPerWay and spawnAttempts < MAX_ATTEMPTS do
			spawnAttempts += 1
			-- Dividing by 4 restricts the spawn area to the inner 50% of the room.
			-- Increase this number (e.g., 5 or 6) to make the grouping even tighter.
			local boundX = math.floor(size.X / 4)
			local boundZ = math.floor(size.Z / 4)

			local randX = math.random(-boundX, boundX)
			local randZ = math.random(-boundZ, boundZ)
			local startPos = (cf * CFrame.new(randX, size.Y + 15, randZ)).Position

			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {wayModel}
			rayParams.FilterType = Enum.RaycastFilterType.Include

			local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -(size.Y * 2 + 30), 0), rayParams)

			if rayResult then
				local tooClose = false
				for _, p in ipairs(localPositions) do
					if (p - rayResult.Position).Magnitude < MIN_DISTANCE then 
						tooClose = true 
						break 
					end
				end

				if not tooClose and rayResult.Normal.Y > 0.8 then
					local zombieTemplate = availableZombies[math.random(1, #availableZombies)]
					local zombie = zombieTemplate:Clone()

					local spawnCFrame = CFrame.new(rayResult.Position + Vector3.new(0, 3, 0))
					zombie:PivotTo(spawnCFrame)
					for _, descendant in ipairs(zombie:GetDescendants()) do
						if descendant:IsA("BasePart") then
							descendant.CollisionGroup = "EnemyZombies"
						end
					end

					-- Disable Jump Pathing
					local humanoid = zombie:FindFirstChildWhichIsA("Humanoid")
					if humanoid then
						humanoid.JumpPower = 0
						humanoid.JumpHeight = 0
					end

					zombie.Parent = enemyFolder

					game:GetService("CollectionService"):AddTag(zombie, "Zombie")

					table.insert(localPositions, rayResult.Position)
					zombiesInThisWay += 1
					totalSpawned += 1
				end
			end
		end
	end
	print("[ProceduralGenerate] Spawned exactly " .. totalSpawned .. " zombies across " .. #placedWays .. " structures.")
end

local function spawnBoss(placedWays, level)
	-- Only execute on Stage 3
	if level ~= 3 or #placedWays == 0 then return end

	local enemyFolder = Workspace:FindFirstChild("Enemies")
	if not enemyFolder then return end

	local farthestWay = nil
	local maxDistance = -1

	-- Find the farthest building
	for _, way in ipairs(placedWays) do
		local distance = way:GetPivot().Position.Magnitude
		if distance > maxDistance then
			maxDistance = distance
			farthestWay = way
		end
	end

	-- Spawn the boss
	if farthestWay then
		local cf, size = getPrimaryBox(farthestWay)

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {farthestWay}
		rayParams.FilterType = Enum.RaycastFilterType.Include

		local startPos = (cf * CFrame.new(0, size.Y + 15, 0)).Position
		local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -(size.Y * 2 + 30), 0), rayParams)

		local boss = bossTemplate:Clone()
		local spawnPos = rayResult and rayResult.Position or cf.Position

		boss:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))

		for _, descendant in ipairs(boss:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "EnemyZombies"
			end
		end

		local humanoid = boss:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
			
			humanoid.Died:Connect(function()
				bossKillCount.Value += 1
			end)
		end

		boss.Parent = enemyFolder
		game:GetService("CollectionService"):AddTag(boss, "BossZombie")
		print("[ProceduralGenerate] Boss spawned at distance: " .. math.floor(maxDistance))
	end
end

local function generateStage()
	killCount.Value = 0
	bossKillCount.Value = 0
	stageNumber.Value = currentLevel
	local oldMap = Workspace:FindFirstChild("MapContainer")
	if oldMap then oldMap:Destroy() end

	local mapContainer = Instance.new("Folder")
	mapContainer.Name   = "MapContainer"
	mapContainer.Parent = Workspace

	local enemyFolder = Workspace:FindFirstChild("Enemies")
	if enemyFolder then
		enemyFolder:ClearAllChildren()
	else
		enemyFolder = Instance.new("Folder")
		enemyFolder.Name = "Enemies"
		enemyFolder.Parent = Workspace
	end

	local killCount = ReplicatedStorage:FindFirstChild("GlobalKillCount")
	if killCount then killCount.Value = 0 end

	local MAX_POOLS      = 5
	local poolsPlaced    = 0
	local lastPoolType   = nil
	local pendingSockets = {}
	local unconnected    = {}
	local placedWays     = {} 

	local rootModel = spawnTemplate:Clone()
	rootModel.Parent = mapContainer
	rootModel:PivotTo(CFrame.new(0, 0, 0))

	for _, att in ipairs(getAttachments(rootModel)) do table.insert(pendingSockets, att) end

	local MAX_RETRIES = 15

	while poolsPlaced < MAX_POOLS and #pendingSockets > 0 do
		local targetSocket = table.remove(pendingSockets, 1)
		local ownerModel   = targetSocket:FindFirstAncestorWhichIsA("Model")

		local roadBridge  = roadTemplate:Clone()
		local roadSockets = getAttachments(roadBridge)
		roadBridge:PivotTo(getAlignedCFrame(targetSocket, roadSockets[1], roadBridge))
		local bCF, bSz = getPrimaryBox(roadBridge)

		local placed = false
		if not isSpaceOccupied(bCF, bSz, mapContainer, ownerModel) then
			local slotsLeft = MAX_POOLS - poolsPlaced
			for attempt = 1, MAX_RETRIES do
				local newModel, chosenPool = getRandomModel(poolsPlaced, lastPoolType, slotsLeft)
				if not newModel then break end

				local incomingSockets = getAttachments(newModel)
				local modelPlaced = false

				for _, incomingSocket in ipairs(incomingSockets) do
					newModel:PivotTo(getAlignedCFrame(roadSockets[2], incomingSocket, newModel))
					local mCF, mSz = getPrimaryBox(newModel)

					if not isSpaceOccupied(mCF, mSz, mapContainer, roadBridge) then
						roadBridge.Parent = mapContainer
						newModel.Parent   = mapContainer

						table.insert(placedWays, newModel)

						poolsPlaced += 1
						lastPoolType = chosenPool

						for _, att in ipairs(incomingSockets) do
							if att ~= incomingSocket then table.insert(pendingSockets, att) end
						end

						modelPlaced = true
						placed      = true
						break
					end
				end

				if modelPlaced then break end
				newModel:Destroy()
			end
		end

		if not placed then
			roadBridge:Destroy()
			table.insert(unconnected, targetSocket)
		end
	end

	for _, att in ipairs(pendingSockets) do table.insert(unconnected, att) end
	for _, socket in ipairs(unconnected) do
		local cap = endCapTemplate:Clone()
		local capSockets = getAttachments(cap)
		if #capSockets > 0 then
			cap:PivotTo(getAlignedCFrame(socket, capSockets[1], cap))
			cap.Parent = mapContainer
		else
			cap:Destroy()
		end
	end

	spawnZombiesPerWay(placedWays, 5)
	spawnBoss(placedWays, currentLevel)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local spawnPad = rootModel:FindFirstChildWhichIsA("SpawnLocation")
			if spawnPad then
				player.Character:PivotTo(spawnPad.CFrame * CFrame.new(0, 5, 0))
			end
		end
	end
end

generateStage()

local syncReadyEvent = ReplicatedStorage:WaitForChild("SyncReadyCount")
local readyPlayers = {}
local isGenerating = false

local function checkReadiness()
	if isGenerating then return end

	local currentPlayers = Players:GetPlayers()
	local totalCount = #currentPlayers
	if totalCount == 0 then return end

	local readyCount = 0

	-- Count how many players have clicked ready
	for _, p in ipairs(currentPlayers) do
		if readyPlayers[p.UserId] then
			readyCount += 1
		end
	end

	-- Broadcast the current count to all players
	syncReadyEvent:FireAllClients(readyCount, totalCount)

	-- If everyone is ready, proceed
	if readyCount >= totalCount then
		isGenerating = true
		readyPlayers = {} 

		-- If max level is reached, teleport players instead of generating
		if currentLevel >= MAX_LEVELS then
			local success, errorMessage = pcall(function()
				TeleportService:TeleportAsync(TARGET_PLACE_ID, currentPlayers)
			end)

			if not success then
				warn("Teleport failed: " .. tostring(errorMessage))
				isGenerating = false -- Reset so they can try again
			end
			return
		end

		-- Standard generation for non-final stages
		currentLevel += 1
		generateStage()

		task.wait(3)
		isGenerating = false
	end
end

nextLevelEvent.OnServerEvent:Connect(function(player)
	if isGenerating then return end
	readyPlayers[player.UserId] = true
	checkReadiness()
end)

Players.PlayerRemoving:Connect(function(player)
	readyPlayers[player.UserId] = nil
	checkReadiness()
end)