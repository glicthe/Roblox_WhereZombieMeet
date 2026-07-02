local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local statsFolder = ReplicatedStorage:WaitForChild("StageStats")
local killsFolder = statsFolder:WaitForChild("Kills")
local coinsFolder = statsFolder:WaitForChild("Coins")
local stageTime = statsFolder:WaitForChild("StageTime")
local stageNumber = statsFolder:WaitForChild("StageNumber")

local globalKillCount = ReplicatedStorage:WaitForChild("GlobalKillCount")
local bossKillCount = ReplicatedStorage:WaitForChild("BossKillCount")
local nextLevelEvent = ReplicatedStorage:WaitForChild("NextLevelEvent")
local showStageCleared = ReplicatedStorage:WaitForChild("ShowStageCleared")

local stageActive = true

local LAST_STAGE = 3
local KILLS_REQUIRED = 25
local BOSS_KILLS_REQUIRED = 1


-- Timer logic
task.spawn(function()
	while true do
		task.wait(1)
		if stageActive then
			stageTime.Value += 1
		end
	end
end)

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

local function triggerStageCleared()
	stageActive = false -- Stop timer

	-- Compile player stats
	local playerStats = {}
	for _, killValue in ipairs(killsFolder:GetChildren()) do
		local pName = killValue.Name
		local pKills = killValue.Value
		local pCoins = 0
		if coinsFolder:FindFirstChild(pName) then
			pCoins = coinsFolder[pName].Value
		end
		table.insert(playerStats, {name = pName, kills = pKills, coins = pCoins})
	end

	local timeStr = formatTime(stageTime.Value)
	showStageCleared:FireAllClients(stageNumber.Value, timeStr, playerStats)
end

local function checkStageClear()
	if not stageActive then return end

	local killsOk = globalKillCount.Value >= KILLS_REQUIRED

	if stageNumber.Value >= LAST_STAGE then
		-- Last stage: also require the boss to be dead
		local bossOk = bossKillCount.Value >= BOSS_KILLS_REQUIRED
		if killsOk and bossOk then
			triggerStageCleared()
		end
	else
		-- Normal stage: just the kill count
		if killsOk then
			triggerStageCleared()
		end
	end
end

-- Listen for both kill counters, since either could be the "last" condition to complete
globalKillCount.Changed:Connect(checkStageClear)
bossKillCount.Changed:Connect(checkStageClear)

-- When next level is requested
stageNumber.Changed:Connect(function(newVal)
	if newVal > 3 then return end
	-- Reset stats for the new round
	stageTime.Value = 0
	killsFolder:ClearAllChildren()
	coinsFolder:ClearAllChildren()
	stageActive = true
end)
