--// TeleportGUI Controller — Dark Souls / Elden Ring Theme
--// Updated: Fixed Leave Portal styling, colors, sync, and teleport features

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer



-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ZoneEnterRemote    = Remotes:WaitForChild("ZoneEnterRemote")
local ZoneExitRemote     = Remotes:WaitForChild("ZoneExitRemote")
local ZoneStateRemote    = Remotes:WaitForChild("ZoneStateRemote")
local PlayerSelectRemote = Remotes:WaitForChild("PlayerSelectRemote")
local CancelQueueRemote  = Remotes:WaitForChild("CancelQueueRemote")

-- GUI refs
local ScreenGui       = script.Parent
local Overlay         = ScreenGui:WaitForChild("Overlay")
local MainFrame       = ScreenGui:WaitForChild("MainFrame")
local TitleLabel      = MainFrame:WaitForChild("TitleLabel")
local HLine           = MainFrame:WaitForChild("HLine")
local StateLabel      = MainFrame:WaitForChild("StateLabel")
local PlayerCountLabel = MainFrame:WaitForChild("PlayerCountLabel")
local CountdownLabel  = MainFrame:WaitForChild("CountdownLabel")
local BarBg           = MainFrame:WaitForChild("BarBg")
local BarFill         = BarBg:WaitForChild("BarFill")
local CtrlContainer   = MainFrame:WaitForChild("ControlContainer")
local MinusBtn        = CtrlContainer:WaitForChild("MinusBtn")
local PlusBtn         = CtrlContainer:WaitForChild("PlusBtn")
local NumLabel        = CtrlContainer:WaitForChild("NumLabel")
local ConfirmBtn      = MainFrame:WaitForChild("ConfirmButton")
local CancelButton    = MainFrame:WaitForChild("CancelButton")


-- State
local currentZone     = nil
local isHost          = false
local selectedAmount  = 1
local maxCountdown    = 20
local isCountingDown  = false
local guiVisible      = false
local savedExitCFrame = nil

-- Colors Base
local C_GOLD           = Color3.fromRGB(201, 155, 61)
local C_BRIGHT         = Color3.fromRGB(255, 220, 120)
local C_BTN_DEFAULT    = Color3.fromRGB(15, 15, 15)
local C_BTN_HOVER      = Color3.fromRGB(35, 35, 35)

------------------------------------------------------
-- UTILS
------------------------------------------------------
local function tween(obj, props, t, style, dir)
    TweenService:Create(
        obj,
        TweenInfo.new(t or 0.3, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

local function tweenReturn(obj, props, t, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(t or 0.3, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

------------------------------------------------------
-- FORCE INIT CANCEL BUTTON STYLE
------------------------------------------------------
CancelButton.BackgroundColor3 = C_BTN_DEFAULT
CancelButton.BackgroundTransparency = 0
CancelButton.Size = UDim2.new(0, 240, 0, 35)
CancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)

local lStroke = CancelButton:FindFirstChildOfClass("UIStroke")
if not lStroke then
    lStroke = Instance.new("UIStroke")
    lStroke.Thickness = 2
    lStroke.Parent = CancelButton
end

-- Clear old diamonds
for _, c in ipairs(CancelButton:GetChildren()) do
    if c.Name == "Frame" then c:Destroy() end
end

local function addDiamond(btn, pos, anchor)
    local d = Instance.new("Frame")
    d.Name = "Frame"
    d.Size = UDim2.new(0, 10, 0, 10)
    d.Position = pos
    d.AnchorPoint = anchor
    d.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
    d.Rotation = 45
    d.BorderSizePixel = 0
    d.Parent = btn
end
addDiamond(CancelButton, UDim2.new(0, -5, 0, -5), Vector2.new(0.5, 0.5))
addDiamond(CancelButton, UDim2.new(1, 5, 0, -5), Vector2.new(0.5, 0.5))
addDiamond(CancelButton, UDim2.new(0, -5, 1, 5), Vector2.new(0.5, 0.5))
addDiamond(CancelButton, UDim2.new(1, 5, 1, 5), Vector2.new(0.5, 0.5))


------------------------------------------------------
-- CANCEL BUTTON (LEAVE PORTAL)
------------------------------------------------------
local function showCancelBtn()
    CancelButton.Visible = true
    CancelButton.BackgroundTransparency = 0
    tween(CancelButton, {TextTransparency = 0}, 0.4)
    local s = CancelButton:FindFirstChildOfClass("UIStroke")
    if s then s.Transparency = 0 end
    for _, c in ipairs(CancelButton:GetChildren()) do
        if c.Name == "Frame" then c.BackgroundTransparency = 0 end
    end
end

local function hideCancelBtn()
    tween(CancelButton, {TextTransparency = 1}, 0.25)
    local s = CancelButton:FindFirstChildOfClass("UIStroke")
    if s then tween(s, {Transparency = 1}, 0.25) end
    for _, c in ipairs(CancelButton:GetChildren()) do
        if c.Name == "Frame" then tween(c, {BackgroundTransparency = 1}, 0.25) end
    end
    task.delay(0.3, function() CancelButton.Visible = false end)
end

CancelButton.MouseEnter:Connect(function() 
    tween(CancelButton, {TextColor3 = Color3.fromRGB(255, 50, 50), BackgroundColor3 = C_BTN_HOVER}, 0.15) 
end)
CancelButton.MouseLeave:Connect(function() 
    tween(CancelButton, {TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = C_BTN_DEFAULT}, 0.15) 
end)

CancelButton.MouseButton1Down:Connect(function()
    tween(CancelButton, {Size = UDim2.new(0, 230, 0, 32)}, 0.05)
end)
CancelButton.MouseButton1Up:Connect(function()
    tween(CancelButton, {Size = UDim2.new(0, 240, 0, 35)}, 0.1)
end)

CancelButton.MouseButton1Click:Connect(function()
    if not currentZone then return end
    CancelQueueRemote:FireServer(currentZone)
    
    
    hideGUI(function()
        currentZone    = nil
        isCountingDown = false
    end)
end)


------------------------------------------------------
-- CONTROLS ( +/- & CONFIRM )
------------------------------------------------------
local function updateNumLabel()
    NumLabel.Text = tostring(selectedAmount)
    tween(NumLabel, {TextSize = 50, TextColor3 = C_BRIGHT}, 0.1)
    task.delay(0.1, function()
        tween(NumLabel, {TextSize = 45, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
    end)
end

local function setControlsActive(active)
    MinusBtn.Active = active
    PlusBtn.Active = active
    ConfirmBtn.Active = active
    
    local targetTrans = active and 0 or 0.7
    tween(MinusBtn, {BackgroundTransparency = targetTrans, TextTransparency = targetTrans}, 0.3)
    tween(PlusBtn, {BackgroundTransparency = targetTrans, TextTransparency = targetTrans}, 0.3)
    tween(ConfirmBtn, {BackgroundTransparency = targetTrans, TextTransparency = targetTrans}, 0.3)
    tween(NumLabel, {TextTransparency = targetTrans}, 0.3)
    
    local mStroke = MinusBtn:FindFirstChildOfClass('UIStroke')
    local pStroke = PlusBtn:FindFirstChildOfClass('UIStroke')
    local cStroke = ConfirmBtn:FindFirstChildOfClass('UIStroke')
    if mStroke then tween(mStroke, {Transparency = targetTrans}, 0.3) end
    if pStroke then tween(pStroke, {Transparency = targetTrans}, 0.3) end
    if cStroke then tween(cStroke, {Transparency = targetTrans}, 0.3) end
end

local function bindHover(btn)
    btn.MouseEnter:Connect(function()
        if not btn.Active then return end
        tween(btn, {BackgroundColor3 = C_BTN_HOVER}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, {BackgroundColor3 = C_BTN_DEFAULT}, 0.15)
    end)
end

bindHover(MinusBtn)
bindHover(PlusBtn)

-- Confirm Hover/Click
ConfirmBtn.MouseEnter:Connect(function()
    if not ConfirmBtn.Active then return end
    local baseColor = ConfirmBtn:GetAttribute("BaseColor") or Color3.fromRGB(80, 20, 20)
    tween(ConfirmBtn, {BackgroundColor3 = baseColor}, 0.15)
end)
ConfirmBtn.MouseLeave:Connect(function()
    tween(ConfirmBtn, {BackgroundColor3 = C_BTN_DEFAULT}, 0.15)
end)
ConfirmBtn.MouseButton1Down:Connect(function()
    if not ConfirmBtn.Active then return end
    tween(ConfirmBtn, {Size = UDim2.new(0, 230, 0, 32)}, 0.05)
end)
ConfirmBtn.MouseButton1Up:Connect(function()
    tween(ConfirmBtn, {Size = UDim2.new(0, 240, 0, 35)}, 0.1)
end)

MinusBtn.MouseButton1Click:Connect(function()
    if not isHost or isCountingDown or not MinusBtn.Active then return end
    if selectedAmount > 1 then
        selectedAmount = selectedAmount - 1
        updateNumLabel()
    end
end)

PlusBtn.MouseButton1Click:Connect(function()
    if not isHost or isCountingDown or not PlusBtn.Active then return end
    if selectedAmount < 6 then
        selectedAmount = selectedAmount + 1
        updateNumLabel()
    end
end)

ConfirmBtn.MouseButton1Click:Connect(function()
    if not isHost or isCountingDown or not currentZone or not ConfirmBtn.Active then return end
    isCountingDown = true
    
    tween(ConfirmBtn, {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}, 0.1)
    
    PlayerSelectRemote:FireServer(currentZone, selectedAmount)
    
    task.delay(0.3, function()
        setControlsActive(false)
        StateLabel.Text = 'The pact is sealed...'
        tween(ConfirmBtn, {BackgroundColor3 = C_BTN_DEFAULT}, 0.2)
    end)
end)

------------------------------------------------------
-- BAR UPDATE
------------------------------------------------------
local function updateBar(timeLeft, maxTime)
    local ratio = math.clamp(timeLeft / math.max(maxTime, 1), 0, 1)
    tween(BarFill, {Size = UDim2.new(ratio, 0, 1, 0)}, 0.85, Enum.EasingStyle.Linear)
end

------------------------------------------------------
-- SHOW / HIDE
------------------------------------------------------
local function showGUI()
    if guiVisible then return end
    guiVisible = true
    Overlay.Visible   = true
    MainFrame.Visible = true
    MainFrame.BackgroundTransparency = 1
    Overlay.BackgroundTransparency  = 1

    -- Animasi muncul dari scale kecil
    MainFrame.Size = UDim2.new(0, 500, 0, 350)
    tween(MainFrame, {Size = UDim2.new(0, 600, 0, 420), BackgroundTransparency = 0}, 0.55, Enum.EasingStyle.Back)
    tween(Overlay, {BackgroundTransparency = 0.75}, 0.55)

    showCancelBtn()
end

local function hideGUI(callback)
    if not guiVisible then
        if callback then callback() end
        return
    end
    hideCancelBtn()
    tween(Overlay, {BackgroundTransparency = 1}, 0.4)
    local tw = tweenReturn(MainFrame, {BackgroundTransparency = 1, Size = UDim2.new(0, 500, 0, 350)}, 0.4)
    tw.Completed:Connect(function()
        guiVisible = false
        MainFrame.Visible = false
        Overlay.Visible   = false
        if callback then callback() end
    end)
end

------------------------------------------------------
-- SETUP ZONE
------------------------------------------------------
local function setupZone(zoneName, hostMode)
    currentZone     = zoneName
    isHost          = hostMode
    selectedAmount  = 1
    isCountingDown  = false
    maxCountdown    = 20
    
    updateNumLabel()

    local titleText   = 'CHOOSE THY FATE'
    local accentColor = Color3.fromRGB(80, 20, 20)
    
    if zoneName:find('Campaign') then
        titleText   = 'CAMPAIGN MODE'
        accentColor = Color3.fromRGB(35, 120, 65)
    elseif zoneName:find('Raid') then
        titleText   = 'RAID MODE'
        accentColor = Color3.fromRGB(20, 60, 120)
    end

    TitleLabel.Text = titleText
    HLine.BackgroundColor3 = accentColor
    BarFill.BackgroundColor3 = accentColor
    
    -- COLORING CONFIRM BTN
    local cStroke = ConfirmBtn:FindFirstChildOfClass("UIStroke")
    if cStroke then cStroke.Color = accentColor end
    for _, child in ipairs(ConfirmBtn:GetChildren()) do
        if child.Name == "Frame" then child.BackgroundColor3 = accentColor end
    end
    ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ConfirmBtn.BackgroundColor3 = C_BTN_DEFAULT
    ConfirmBtn.BackgroundTransparency = 0
    ConfirmBtn:SetAttribute("BaseColor", accentColor)
    
    -- COLORING CANCEL BTN
    local lStroke = CancelButton:FindFirstChildOfClass("UIStroke")
    if lStroke then lStroke.Color = accentColor end
    for _, child in ipairs(CancelButton:GetChildren()) do
        if child.Name == "Frame" then child.BackgroundColor3 = accentColor end
    end
    CancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelButton.BackgroundColor3 = C_BTN_DEFAULT
    CancelButton.BackgroundTransparency = 0
    CancelButton:SetAttribute("BaseColor", accentColor)

    PlayerCountLabel.Text = 'Players Joined: 0 / 6'
    StateLabel.Text       = 'Awaiting the chosen...'
    CountdownLabel.Text   = ''
    BarFill.Size          = UDim2.new(1, 0, 1, 0)

    if hostMode then
        StateLabel.Text    = 'Waiting your choice'
        setControlsActive(true)
    else
        StateLabel.Text    = 'Another has entered the rift...'
        setControlsActive(false)
    end

    showGUI()
end

------------------------------------------------------
-- REMOTE EVENTS
------------------------------------------------------
ZoneEnterRemote.OnClientEvent:Connect(function(zoneName, hostMode)
    if not savedExitCFrame then
        local char = LocalPlayer.Character
        if char and char.PrimaryPart then
            -- MURNI teleport ke TENGAN JALAN ASPAL (Road_02_A)
            -- X = -445 adalah titik tengah jalan aspal lurus.
            -- Z = 1030 adalah jarak aman di belakang lengkungan portal.
            local aspalPos = Vector3.new(-445, char.PrimaryPart.Position.Y, 1030)
            
            -- Menghadap ke Z positif (kembali menghadap arah portal/papan informasi)
            savedExitCFrame = CFrame.new(aspalPos, aspalPos + Vector3.new(0, 0, 1))
        end
    end
    setupZone(zoneName, hostMode)
end)





ZoneExitRemote.OnClientEvent:Connect(function(zoneName)
    if zoneName == currentZone then
        hideGUI(function()
            currentZone    = nil
            isCountingDown = false
            savedExitCFrame = nil
        end)
    end
end)


ZoneStateRemote.OnClientEvent:Connect(function(zoneName, currentCount, maxCount, timeLeft, state)
    if zoneName ~= currentZone then return end

    PlayerCountLabel.Text = 'Players Joined: ' .. currentCount .. ' / 6'

    if state == 'countdown' then
        if timeLeft > maxCountdown then maxCountdown = timeLeft end
        updateBar(timeLeft, maxCountdown)

        if timeLeft <= 3 then
            CountdownLabel.Text = 'DEPARTING NOW...'
            tween(CountdownLabel, {TextColor3 = Color3.fromRGB(220, 60, 20)}, 0.2)
        else
            CountdownLabel.Text = 'Departing in ' .. timeLeft .. '...'
            tween(CountdownLabel, {TextColor3 = C_GOLD}, 0.2)
        end
    elseif state == 'teleporting' then
        CountdownLabel.Text = 'The rift consumes thy soul...'
        tween(CountdownLabel, {TextColor3 = Color3.fromRGB(255, 200, 80)}, 0.3)
        task.delay(2, function() hideGUI() end)
    elseif state == 'waiting' then
        CountdownLabel.Text = ''
        tween(BarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.5)
    end
end)
