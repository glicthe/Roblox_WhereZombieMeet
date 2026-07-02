local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local player = Players.LocalPlayer
local sg = script.Parent
local hotbar = sg:WaitForChild("Hotbar")
local slot1 = hotbar:WaitForChild("Slot1")
local slot2 = hotbar:WaitForChild("Slot2")

local slots = {slot1, slot2}
local tools = {nil, nil} -- Max 2 tools

local cBorderDark = Color3.fromRGB(60, 40, 20)
local cEquipped = Color3.fromRGB(200, 150, 50) -- Bright gold when equipped

local function updateUI()
    for i = 1, 2 do
        local tool = tools[i]
        local slot = slots[i]
        local icon = slot:FindFirstChild("Icon")
        local nameLbl = slot:FindFirstChild("ToolName")
        local stroke = slot:FindFirstChildOfClass("UIStroke")
        
        if tool then
            if tool.TextureId and tool.TextureId ~= "" then
                icon.Image = tool.TextureId
                nameLbl.Text = ""
            else
                icon.Image = ""
                nameLbl.Text = tool.Name
            end
            
            -- Check if equipped
            if tool.Parent == player.Character then
                if stroke then stroke.Color = cEquipped end
            else
                if stroke then stroke.Color = cBorderDark end
            end
        else
            icon.Image = ""
            nameLbl.Text = ""
            if stroke then stroke.Color = cBorderDark end
        end
    end
end

local function onToolAdded(tool)
    if not tool:IsA("Tool") then return end
    
    -- Check if already in slots
    for i = 1, 2 do
        if tools[i] == tool then
            updateUI()
            return
        end
    end
    
    -- Add to first empty slot
    for i = 1, 2 do
        if not tools[i] then
            tools[i] = tool
            updateUI()
            return
        end
    end
end

local function onToolRemoved(tool)
    -- Wait a frame to see if it just moved between Backpack and Character
    task.wait()
    if tool.Parent == player.Character or (player:FindFirstChild("Backpack") and tool.Parent == player.Backpack) then
        updateUI()
        return
    end
    
    -- Actually removed from player
    for i = 1, 2 do
        if tools[i] == tool then
            tools[i] = nil
        end
    end
    updateUI()
end

local function setupCharacter(char)
    local backpack = player:WaitForChild("Backpack")
    
    -- Clear current slots
    tools = {nil, nil}
    
    -- Existing tools
    for _, item in ipairs(backpack:GetChildren()) do
        onToolAdded(item)
    end
    for _, item in ipairs(char:GetChildren()) do
        onToolAdded(item)
    end
    
    -- Listeners
    backpack.ChildAdded:Connect(onToolAdded)
    backpack.ChildRemoved:Connect(onToolRemoved)
    char.ChildAdded:Connect(onToolAdded)
    char.ChildRemoved:Connect(onToolRemoved)
    
    updateUI()
end

if player.Character then
    task.spawn(function() setupCharacter(player.Character) end)
end
player.CharacterAdded:Connect(setupCharacter)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local idx = nil
    if input.KeyCode == Enum.KeyCode.One then idx = 1 end
    if input.KeyCode == Enum.KeyCode.Two then idx = 2 end
    
    if idx and tools[idx] then
        local tool = tools[idx]
        if tool.Parent == char then
            -- Unequip
            hum:UnequipTools()
        else
            -- Equip
            hum:EquipTool(tool)
        end
    end
end)
