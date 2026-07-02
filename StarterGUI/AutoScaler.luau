local gui = script.Parent
local camera = workspace.CurrentCamera

local BASE_HEIGHT = 1080

local function applyScale()
    local hudFrame = gui:FindFirstChild("HUD")
    local hotbarFrame = gui:FindFirstChild("Hotbar")
    local skillBarFrame = gui:FindFirstChild("SkillBar")
    
    if hudFrame and not hudFrame:FindFirstChild("UIScale") then Instance.new("UIScale", hudFrame) end
    if hotbarFrame and not hotbarFrame:FindFirstChild("UIScale") then Instance.new("UIScale", hotbarFrame) end
    if skillBarFrame and not skillBarFrame:FindFirstChild("UIScale") then Instance.new("UIScale", skillBarFrame) end
    
    local viewport = camera.ViewportSize
    if viewport.Y < 100 then return end
    
    local ratio = viewport.Y / BASE_HEIGHT
    ratio = math.clamp(ratio, 0.3, 1.5)
    
    if hudFrame and hudFrame:FindFirstChild("UIScale") then hudFrame.UIScale.Scale = ratio end
    if hotbarFrame and hotbarFrame:FindFirstChild("UIScale") then hotbarFrame.UIScale.Scale = ratio * 1.2 end
    if skillBarFrame and skillBarFrame:FindFirstChild("UIScale") then skillBarFrame.UIScale.Scale = ratio * 1.5 end
end

camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
gui.DescendantAdded:Connect(function() applyScale() end)

applyScale()
