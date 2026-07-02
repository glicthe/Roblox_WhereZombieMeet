--[[
    Crouch Script - Compatible with Clash System
    Place wherever your current crouch script is located
]]

local plr = game.Players.LocalPlayer
local Character = plr.Character or plr.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

----------------- { CONFIGURATION } ---------------------

local config = {
	CrouchButtons = Enum.KeyCode.C,
	CrouchingCooldown = 0.1,
	Speed = 8,
	DefaultFieldOfView = 70,
	CrouchFieldOfView = 60,
	CameraFOVCrouchTime = 0.5,
	CameraFOVResetTime = 1,
	CameraOffset = -1,
	MinCameraDistance = 0.5,
	MaxCameraDistance = 10,
	CrouchEnabled = true,
	DustEnabled = true,
	DynamicDustColor = true,
	DustSpawnRate = 0.15,
	MaxFreefallDuration = 0.35,
	StopOnLanding = true,
	CrouchInAir = false,
	RunningEnabled = true,
	CrouchWalkAnimSpeed = 1.5
}

---------------------------------------------------------

local Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)
local CrouchIdleAnim = Animator:LoadAnimation(script:WaitForChild("Crouching"))
local CrouchWalkAnim = Animator:LoadAnimation(script:WaitForChild("CrouchWalk"))

local CrouchSound = script:FindFirstChild("Crouch")
local GetUpSound = script:FindFirstChild("GetUp")
local originalSpeed = Humanoid.WalkSpeed
local originalMinCameraDistance = plr.CameraMinZoomDistance
local originalMaxCameraDistance = plr.CameraMaxZoomDistance
local dustDebounce = true
local notMoving = true
local crouchDebounce = true
local isOnGround = true
local freefallTimer = 0
local currentCrouchAnim = nil
local isCrouching = false
local fovTween = nil
local lastFOV = config.DefaultFieldOfView

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local runEvent = ReplicatedStorage:WaitForChild("UpdateRunningState")

Camera.FieldOfView = config.DefaultFieldOfView
lastFOV = config.DefaultFieldOfView

if RootPart:GetAttribute("IsCrouching") == nil then
	RootPart:SetAttribute("IsCrouching", false)
end

if RootPart:GetAttribute("CrouchEnabled") == nil then
	if config.CrouchEnabled == true then
		RootPart:SetAttribute("CrouchEnabled", true)
	else
		RootPart:SetAttribute("CrouchEnabled", false)
	end
end

-- Helper function to check if player can crouch
local function canCrouch()
	-- Check for clash state
	local isInClash = Character:FindFirstChild("IsInClash")
	if isInClash and isInClash.Value == true then
		return false
	end

	-- Check for stun state (no crouching while stunned)
	local isStunned = Character:FindFirstChild("IsStunned")
	if isStunned and isStunned.Value == true then
		return false
	end

	-- Check for guard broken state
	local isGuardBroken = Character:FindFirstChild("IsGuardBroken")
	if isGuardBroken and isGuardBroken.Value == true then
		return false
	end

	return true
end

local function crouchKey(input)
	local crouchKeys = (typeof(config.CrouchButtons) == "table") and config.CrouchButtons or {config.CrouchButtons}
	for _, key in ipairs(crouchKeys) do
		if input.KeyCode == key then
			return true
		end
	end
	return false
end

local function IsObstructed()
	local head = Character:FindFirstChild("Head")
	if head then
		local rayStart = head.Position
		local rayDirection = head.CFrame.UpVector * 1.5
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {Character}
		local raycastResult = workspace:Raycast(rayStart, rayDirection, raycastParams)
		return raycastResult ~= nil
	end
	return false
end

local function HandleCrouchAnimations()
	if notMoving and isCrouching then
		if currentCrouchAnim == CrouchWalkAnim then
			CrouchWalkAnim:Stop()
		end
		if not CrouchIdleAnim.IsPlaying then
			CrouchIdleAnim:Play()
			currentCrouchAnim = CrouchIdleAnim
		end
	elseif not notMoving and isCrouching then
		if currentCrouchAnim == CrouchIdleAnim then
			CrouchIdleAnim:Stop()
		end
		if not CrouchWalkAnim.IsPlaying then
			CrouchWalkAnim:Play()
			CrouchWalkAnim:AdjustSpeed(config.CrouchWalkAnimSpeed)
			currentCrouchAnim = CrouchWalkAnim
		end
	end
end

local function SmoothFOV(targetFOV, duration)
	if fovTween then
		fovTween:Cancel()
		fovTween = nil
	end

	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	fovTween = TweenService:Create(Camera, tweenInfo, {FieldOfView = targetFOV})
	fovTween:Play()
	lastFOV = targetFOV
end

local function Crouch()
	if not crouchDebounce or not RootPart:GetAttribute("CrouchEnabled") then return end
	if not config.CrouchInAir and not isOnGround then return end
	if isCrouching then return end
	if not canCrouch() then return end -- NEW: Check if player can crouch

	crouchDebounce = false
	isCrouching = true
	RootPart:SetAttribute("IsCrouching", true)

	HandleCrouchAnimations()

	if CrouchSound then
		CrouchSound:Play()
	end

	Humanoid.WalkSpeed = config.Speed

	plr.CameraMinZoomDistance = config.MinCameraDistance
	plr.CameraMaxZoomDistance = config.MaxCameraDistance
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	SmoothFOV(config.CrouchFieldOfView, config.CameraFOVCrouchTime)

	local CAMgoal1 = { CameraOffset = Vector3.new(0, config.CameraOffset, 0) }
	local CAMinfo1 = TweenInfo.new(
		0.3,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local CAMtween1 = TweenService:Create(Humanoid, CAMinfo1, CAMgoal1)
	CAMtween1:Play()

	task.delay(config.CrouchingCooldown, function()
		crouchDebounce = true
	end)
end

local function Stop()
	if not IsObstructed() then
		if isCrouching then
			isCrouching = false
			RootPart:SetAttribute("IsCrouching", false)

			CrouchIdleAnim:Stop()
			CrouchWalkAnim:Stop()
			currentCrouchAnim = nil

			if GetUpSound then
				GetUpSound:Play()
			end

			Humanoid.WalkSpeed = originalSpeed

			plr.CameraMinZoomDistance = originalMinCameraDistance
			plr.CameraMaxZoomDistance = originalMaxCameraDistance
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

			SmoothFOV(config.DefaultFieldOfView, config.CameraFOVResetTime)

			local CAMgoal2 = { CameraOffset = Vector3.new(0, 0, 0) }
			local CAMinfo2 = TweenInfo.new(
				0.3,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out,
				0,
				false,
				0
			)
			local CAMtween2 = TweenService:Create(Humanoid, CAMinfo2, CAMgoal2)
			CAMtween2:Play()
		end
	end
end

UIS.InputBegan:Connect(function(input, isTyping)
	if isTyping then return end

	if crouchKey(input) then
		if not isCrouching then
			Crouch()
		else
			Stop()
		end
	end
end)

local function onStateChanged(_, newState)
	if isCrouching then
		if (newState == Enum.HumanoidStateType.Landed and config.StopOnLanding ~= false)
			or newState == Enum.HumanoidStateType.Dead
			or newState == Enum.HumanoidStateType.Climbing
			or newState == Enum.HumanoidStateType.Swimming
			or newState == Enum.HumanoidStateType.Seated
			or newState == Enum.HumanoidStateType.Physics then
			Stop()
		end
	end
end

RunService.Heartbeat:Connect(function()

	notMoving = Humanoid.MoveDirection.Magnitude == 0

	HandleCrouchAnimations()

	if isCrouching then
		-- NEW: Check if player entered clash/stun state while crouching
		if not canCrouch() then
			Stop()
			return
		end

		Humanoid.WalkSpeed = config.Speed

		if fovTween == nil and math.abs(Camera.FieldOfView - config.CrouchFieldOfView) > 0.5 then
			Camera.FieldOfView = config.CrouchFieldOfView
		end
	end

	if isCrouching and not RootPart:GetAttribute("CrouchEnabled") then
		Stop()
	end

	isOnGround = Humanoid.FloorMaterial ~= Enum.Material.Air

	if config.DustEnabled and isOnGround and isCrouching and dustDebounce and not notMoving then
		dustDebounce = false

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {Character}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local rayResult = workspace:Raycast(
			RootPart.Position + Vector3.new(0, 1, 0), 
			Vector3.new(0, -4.5, 0), 
			rayParams
		)

		local dustTemplate = game.ReplicatedStorage:FindFirstChild("VFX") and game.ReplicatedStorage.VFX:FindFirstChild("Dust")
		if dustTemplate then
			local dust = game.ReplicatedStorage.VFX.Dust:Clone()
			dust.Position = RootPart.Position + Vector3.new(0, -2.5, 0)
			dust.Parent = workspace.FX
			dust.Name = "CrouchDust"

			if config.DynamicDustColor then
				if rayResult then
					local hitPart = rayResult.Instance
					if hitPart and hitPart:IsA("BasePart") then
						dust.Attachment.Dust.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, hitPart.Color),
							ColorSequenceKeypoint.new(1, hitPart.Color)
						}
					end
				end
			else
				dust.Attachment.Dust.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
			end

			dust.Attachment.Dust:Emit(1)
			game.Debris:AddItem(dust, 0.8)

			task.wait(config.DustSpawnRate)
			dustDebounce = true
		end
	end

	if not isOnGround and isCrouching then
		freefallTimer = freefallTimer + RunService.Heartbeat:Wait()
		if freefallTimer >= config.MaxFreefallDuration then
			Stop()
		end
	else
		freefallTimer = 0
	end
end)

RunService.Heartbeat:Connect(function()
	if isCrouching and fovTween == nil then
		if math.abs(Camera.FieldOfView - config.CrouchFieldOfView) > 0.5 then
			Camera.FieldOfView = config.CrouchFieldOfView
		end
	end
end)

Humanoid.StateChanged:Connect(onStateChanged)

plr.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")
	Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)

	CrouchIdleAnim = Animator:LoadAnimation(script:WaitForChild("Crouching"))
	CrouchWalkAnim = Animator:LoadAnimation(script:WaitForChild("CrouchWalk"))

	currentCrouchAnim = nil
	dustDebounce = true
	notMoving = true
	crouchDebounce = true
	isOnGround = true
	freefallTimer = 0
	isCrouching = false
	originalSpeed = Humanoid.WalkSpeed
	fovTween = nil
	lastFOV = config.DefaultFieldOfView

	if RootPart:GetAttribute("IsCrouching") == nil then
		RootPart:SetAttribute("IsCrouching", false)
	end

	if RootPart:GetAttribute("CrouchEnabled") == nil then
		if config.CrouchEnabled == true then
			RootPart:SetAttribute("CrouchEnabled", true)
		else
			RootPart:SetAttribute("CrouchEnabled", false)
		end
	end

	Humanoid.StateChanged:Connect(onStateChanged)
end)

print("Crouch Script loaded with Clash compatibility!")