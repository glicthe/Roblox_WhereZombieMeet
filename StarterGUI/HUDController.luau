local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local player = Players.LocalPlayer
local sg = script.Parent
	sg.Enabled = true -- Auto-enable saat game dimulai
local M = sg:WaitForChild("HUD")

local vp = M:WaitForChild("CharViewport")
local dOuter = M:WaitForChild("DiamondOuter")

local hBg = M:WaitForChild("HealthBg")
local hFill = hBg:WaitForChild("HealthFill")
local hDmg = hBg:WaitForChild("HealthDmg")

local sBg = M:WaitForChild("StaminaBg")
local sFill = sBg:WaitForChild("StaminaFill")

local char, humanoid, prevHealth
local cWhite = Color3.fromRGB(255, 255, 255)
local cPulse = Color3.fromRGB(255, 30, 20)
local cBorderDark = Color3.fromRGB(60, 40, 20)

-- ============ PORTRAIT ============
local function updatePortrait()
    if not char then return end
    
    for _, c in ipairs(vp:GetChildren()) do
        c:Destroy()
    end
    
    char.Archivable = true
    local charClone = char:Clone()
    
    for _, child in ipairs(charClone:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Sound") or child:IsA("BillboardGui") then
            child:Destroy()
        end
    end
    
    local cloneHum = charClone:FindFirstChild("Humanoid")
    if cloneHum then
        cloneHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    
    local head = charClone:FindFirstChild("Head")
    if not head then return end
    
    charClone.Parent = vp
    
    local cam = Instance.new("Camera")
    
    -- ==========================================
    -- = PENGATURAN POSISI KAMERA (MANUAL) =
    -- ==========================================
    -- X: Kiri/Kanan (0 = Tengah)
    -- Y: Atas/Bawah (-1.0 berarti turun ke arah dada)
    -- Z: Jarak Kamera (-3.5 berarti mundur 3.5 stud dari kepala)
    
    local X = 0
    local Y = 0
    local Z = -4.5
    
    cam.CFrame = head.CFrame * CFrame.new(X, Y, Z) * CFrame.Angles(0, math.pi, math.rad(-45))
    cam.FieldOfView = 35
    cam.Parent = vp
    vp.CurrentCamera = cam
    
    vp.Ambient = Color3.fromRGB(150, 150, 150)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-0.5, -0.5, -1)
end

-- ============ BARS ============
local dmgTween = nil

local function updateHealth()
    if not humanoid then return end
    local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
    local prev = math.clamp(prevHealth / humanoid.MaxHealth, 0, 1)
    
    TweenService:Create(hFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    
    if pct < prev then
        hDmg.Size = UDim2.new(prev, 0, 1, 0)
        hDmg.BackgroundColor3 = cWhite
        hDmg.BackgroundTransparency = 0
        
        if dmgTween then dmgTween:Cancel() end
        task.delay(0.6, function()
            dmgTween = TweenService:Create(hDmg, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(pct, 0, 1, 0)})
            dmgTween:Play()
        end)
        
        local stk = dOuter:FindFirstChildOfClass("UIStroke")
        if stk then
            stk.Color = cPulse
            TweenService:Create(stk, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Color = cBorderDark}):Play()
        end
    elseif pct > prev then
        hDmg.Size = UDim2.new(pct, 0, 1, 0)
    end
    prevHealth = humanoid.Health
end

local DASH_COOLDOWN = 0.9
local function onDash()
    sFill.Size = UDim2.new(0, 0, 1, 0)
    TweenService:Create(sFill, TweenInfo.new(DASH_COOLDOWN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
end

-- ============ INIT ============
local function initChar(c)
    char = c
    humanoid = c:WaitForChild("Humanoid")
    prevHealth = humanoid.Health
    
    humanoid.HealthChanged:Connect(updateHealth)
    c:GetAttributeChangedSignal("IsDashing"):Connect(function()
        if c:GetAttribute("IsDashing") == true then
            onDash()
        end
    end)
    
    if not player:HasAppearanceLoaded() then
        player.CharacterAppearanceLoaded:Wait()
    end
    task.wait(1.5)
    updatePortrait()
    updateHealth()
    sFill.Size = UDim2.new(1,0,1,0)
end

if player.Character then
    task.spawn(function() initChar(player.Character) end)
end
player.CharacterAdded:Connect(initChar)
