-- ============================================================
-- MovementController (Clean Version: Only Dash on Space)
-- ============================================================
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local DebrisService = game:GetService("Debris")
local TweenService  = game:GetService("TweenService")
local Players       = game:GetService("Players")

local Config       = require(script:WaitForChild("MovementConfig"))
local stateManager = require(script:WaitForChild("StateManager"))
local vfxHandler   = require(script:WaitForChild("VFXHandler"))

-- -- Character Refs -----------------------------------------
local player        = Players.LocalPlayer
local char          = script.Parent
local humanoid      = char:WaitForChild("Humanoid")
local hrp           = char:WaitForChild("HumanoidRootPart")
local animator      = humanoid:WaitForChild("Animator")
local playerGui     = player:WaitForChild("PlayerGui")

-- ============================================================
-- [PROPERTI MUTLAK] MENGAKTIFKAN NO-JUMP SYSTEM
-- ============================================================
humanoid.JumpPower = 0
humanoid.UseJumpPower = true
humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

-- -- Mobile UI ----------------------------------------------
local DashGui    = playerGui:WaitForChild("MobileDashGui", 10)
local DashButton = DashGui and DashGui:WaitForChild("Frame"):WaitForChild("Botton2") or nil
if DashGui then DashGui.Enabled = true end

local cfgDash         = Config.Dash
local DASH_SPEED      = cfgDash.SPEED
local DASH_TIME       = cfgDash.TIME
local BACK_DASH_TIME  = cfgDash.BACK_TIME
local DASH_COOLDOWN   = cfgDash.COOLDOWN

-- Parameter filter deteksi tabrakan dinding saat Dash
local wallParams = RaycastParams.new()
wallParams.FilterDescendantsInstances = {char}
wallParams.FilterType = Enum.RaycastFilterType.Exclude

-- -- Animations ---------------------------------------------
local function loadAnim(name, priority)
	local obj = script.Animations:FindFirstChild(name)
	if not obj then return nil end
	local track = animator:LoadAnimation(obj)
	if priority then track.Priority = priority end
	return track
end

local anim = {
	BackDash    = loadAnim("BackDash",  Enum.AnimationPriority.Action4),
	LeftDash    = loadAnim("LeftDash",  Enum.AnimationPriority.Action4),
	RightDash   = loadAnim("RightDash", Enum.AnimationPriority.Action4),
}

local forwardAnims = {}
for _, obj in ipairs(script.Animations:GetChildren()) do
	if obj.Name:find("ForwardDash") then
		local t = animator:LoadAnimation(obj)
		t.Priority = Enum.AnimationPriority.Action4
		forwardAnims[#forwardAnims + 1] = t
	end
end

-- -- Sounds -------------------------------------------------
local snd = {
	Dash     = script.Sounds:FindFirstChild("Dash"),
	DashBack = script.Sounds:FindFirstChild("DashBack"),
}

local function playSound3D(obj)
	if not obj then return end
	local s = obj:Clone()
	s.Parent             = hrp
	s.RollOffMaxDistance = 100
	s.RollOffMinDistance = 10
	s.RollOffMode        = Enum.RollOffMode.Inverse
	s.Looped             = false
	s:Play()
	DebrisService:AddItem(s, s.TimeLength + 0.1)
	return s
end

-- -- Variables ----------------------------------------------
local DashDeb   = false
local DashEvent = script:WaitForChild("Event")

-- ============================================================
-- MECHANIC: DASH SYSTEM
-- ============================================================
local function performDash()
	if not Config.Enabled.Dash then return end
	if DashDeb or char:GetAttribute("IsDashing") then return end

	DashDeb = true
	char:SetAttribute("IsDashing", true)

	local moveDir   = humanoid.MoveDirection
	local dashDir   = moveDir.Magnitude > 0 and moveDir or hrp.CFrame.LookVector
	local rel       = hrp.CFrame:VectorToObjectSpace(dashDir)
	local isBack    = rel.Z > 0.5
	local dashTime  = isBack and BACK_DASH_TIME or DASH_TIME

	local dashAnim, animSpd
	if isBack then
		dashAnim = anim.BackDash;  animSpd = cfgDash.ANIM_SPEED_BACK
	elseif rel.X > 0.5 then
		dashAnim = anim.RightDash; animSpd = cfgDash.ANIM_SPEED_RIGHT
	elseif rel.X < -0.5 then
		dashAnim = anim.LeftDash;  animSpd = cfgDash.ANIM_SPEED_LEFT
	else
		dashAnim = #forwardAnims > 0 and forwardAnims[math.random(#forwardAnims)] or nil
		animSpd  = cfgDash.ANIM_SPEED_FORWARD
	end
	if dashAnim then dashAnim:Play(0.15, 1, animSpd) end

	local dashSnd = isBack and snd.DashBack or snd.Dash
	if dashSnd then playSound3D(dashSnd) end
	if DashEvent then DashEvent:FireServer("Dash") end

	-- Pemanggilan VFX Framework secara aman
	pcall(function()
		vfxHandler.SendVFX("Dash",       "All", char, {dashDir})
		vfxHandler.SendVFX("BodyTrail",  "All", char, {dashTime, "BodyTrail1"})
		vfxHandler.SendVFX("BodyColour", "All", char, {0.3, Color3.fromRGB(255,255,255)})
	end)

	local att = Instance.new("Attachment")
	att.Name   = "DashAttachment"
	att.Parent = hrp

	local lv = Instance.new("LinearVelocity")
	lv.MaxForce    = 1e5
	lv.Attachment0 = att
	lv.Parent      = att
	DebrisService:AddItem(att, dashTime + 0.1)

	local startT   = os.clock()
	local prevPos  = hrp.Position
	local hrpSizeZ = hrp.Size.Z

	task.spawn(function()
		while os.clock() - startT < dashTime do
			local cur = hrp.Position
			if (cur - prevPos).Magnitude > 0.01 then
				if workspace:Raycast(hrp.Position, dashDir * (hrpSizeZ + 1.2), wallParams) then
					if lv.Parent then lv.VectorVelocity = Vector3.zero end
					break
				end
			end
			prevPos = cur

			local nd = humanoid.MoveDirection
			if nd.Magnitude > 0 then dashDir = nd end

			local alpha = (os.clock() - startT) / dashTime
			if lv.Parent then
				lv.VectorVelocity = dashDir * (DASH_SPEED * (1.2 - alpha * 0.7))
			else break end

			RunService.Heartbeat:Wait()
		end

		if dashAnim then dashAnim:Stop(0.2) end
		char:SetAttribute("IsDashing", false)
		if att.Parent then att:Destroy() end
	end)

	if DashButton then DashButton.ImageColor3 = Color3.fromRGB(100,100,100) end
	task.delay(DASH_COOLDOWN, function()
		if DashButton then DashButton.ImageColor3 = Color3.fromRGB(255,255,255) end
		DashDeb = false
	end)
end

-- ============================================================
-- INPUT BINDING (SPACE TO DASH ONLY)
-- ============================================================
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local kc = input.KeyCode

	-- Mengunci tombol Space / Tombol A Gamepad murni hanya untuk melakukan Dash
	if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.ButtonA then
		performDash()
	end
end)

if DashButton then DashButton.Activated:Connect(performDash) end