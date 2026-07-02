local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local skillBar = gui:WaitForChild("SkillBar")

-- Set initial transparency
for _, desc in ipairs(skillBar:GetDescendants()) do
    if desc:IsA("Frame") or desc:IsA("ImageLabel") or desc:IsA("TextLabel") then
        desc.BackgroundTransparency = 1
        if desc:IsA("TextLabel") and desc.Name ~= "CooldownText" then desc.TextTransparency = 1 end
        if desc:IsA("ImageLabel") then desc.ImageTransparency = 1 end
    end
    if desc:IsA("UIStroke") then desc.Transparency = 1 end
end

local function setVisibility(visible)
    local targetTrans = visible and 0 or 1
    
    for _, desc in ipairs(skillBar:GetDescendants()) do
        if desc:IsA("Frame") and desc.Name ~= "Skill1" and desc.Name ~= "Skill2" and desc.Name ~= "Skill3" and desc.Name ~= "CooldownOverlay" then
            TweenService:Create(desc, TweenInfo.new(0.3), {BackgroundTransparency = targetTrans}):Play()
        end
        if desc:IsA("TextLabel") and desc.Name ~= "CooldownText" then
            TweenService:Create(desc, TweenInfo.new(0.3), {TextTransparency = targetTrans}):Play()
        end
        if desc:IsA("ImageLabel") then
            TweenService:Create(desc, TweenInfo.new(0.3), {ImageTransparency = targetTrans}):Play()
        end
        if desc:IsA("UIStroke") then
            TweenService:Create(desc, TweenInfo.new(0.3), {Transparency = targetTrans}):Play()
        end
    end
end

local function checkEquipped()
    local char = player.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        setVisibility(true)
    else
        setVisibility(false)
    end
end

local function onCharacterAdded(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then checkEquipped() end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then checkEquipped() end
    end)
    checkEquipped()
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
