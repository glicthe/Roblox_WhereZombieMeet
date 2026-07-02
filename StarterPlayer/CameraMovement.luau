local players = game:GetService("Players")
local player = players.LocalPlayer
local RunSer = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera

-- Cek apakah pemain kembali dari Raid / Campaign
local isReturningFromStage = false
if player:GetAttribute("ReturningFromStage") == true then
	isReturningFromStage = true
else
	local pcallSuccess, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if pcallSuccess and joinData then
		if joinData.SourcePlaceId and joinData.SourcePlaceId ~= 0 and joinData.SourcePlaceId ~= game.PlaceId then
			isReturningFromStage = true
		end
		if joinData.TeleportData and type(joinData.TeleportData) == "table" and joinData.TeleportData.returningFromStage then
			isReturningFromStage = true
		end
	end
end

-- 1. Persiapkan CamPart
local CamPart = RepStorage:WaitForChild("CameraPart"):Clone()
CamPart.Parent = workspace

local cameraPoint = workspace:WaitForChild("CameraPoint")
CamPart.CFrame = cameraPoint.CFrame 

local moveFactor = 0.0005
local PreviousMouseX, PreviousMouseY = nil, nil
local MaxPosition = 0.5

local OriginalCFrame = CamPart.CFrame 
local targetCFrame = OriginalCFrame
local moving = false

local cameraActive = false
if not isReturningFromStage then
	-- 2. Kunci kamera detik itu juga agar tidak sempat melihat karakter saat di Main Menu
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CamPart.CFrame 
	cameraActive = true
else
	-- Jika kembali dari Raid, matikan efek kamera menu & langsung ke karakter
	cameraActive = false
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end)
end

local MenuEvent = RepStorage:WaitForChild("Event")

local function ToggleCamera(value) -- true = On, false = Off
	if value == true then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CamPart.CFrame
	else
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		camera.CameraSubject = humanoid
	end
end

RunSer.RenderStepped:Connect(function()
	if not cameraActive then return end

	local mouse = player:GetMouse()

	local ScreenX = camera.ViewportSize.X
	local ScreenY = camera.ViewportSize.Y

	local leftoverScreenX = ScreenX - mouse.X
	local leftoverScreenY = ScreenY - mouse.Y

	local distanceFromOriginX = (ScreenX/2) - leftoverScreenX
	local distanceFromOriginY = leftoverScreenY - (ScreenY/2)

	local ClampedX = math.clamp(distanceFromOriginX * moveFactor, -MaxPosition, MaxPosition)
	local ClampedY = math.clamp(distanceFromOriginY * moveFactor, -MaxPosition, MaxPosition)

	if PreviousMouseX and PreviousMouseY then
		local mouseMoved = (distanceFromOriginX ~= PreviousMouseX) or (distanceFromOriginY ~= PreviousMouseY)
		if mouseMoved then
			moving = true
			targetCFrame = OriginalCFrame * CFrame.new(ClampedX, ClampedY, 0)
		else
			moving = false
		end
	end

	if moving then
		CamPart.CFrame = CamPart.CFrame:Lerp(targetCFrame, 0.1)
	end

	camera.CFrame = CamPart.CFrame

	PreviousMouseX = distanceFromOriginX
	PreviousMouseY = distanceFromOriginY
end)

MenuEvent.Event:Connect(function(Value)
	if Value == false then
		cameraActive = false
		ToggleCamera(false)
	else
		cameraActive = true
		ToggleCamera(true)
	end
end)