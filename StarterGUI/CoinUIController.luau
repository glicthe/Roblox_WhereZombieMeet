local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local coinBg = gui:WaitForChild("HUD"):WaitForChild("CoinBg")
local amtLbl = coinBg:WaitForChild("Amount")
local circle = coinBg:WaitForChild("IconWrap"):WaitForChild("CoinCircle")

local function formatNumberWithCommas(amount)
    local formatted = amount
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

local function getCoins()
    local ls = player:WaitForChild("leaderstats", 10)
    if ls then return ls:WaitForChild("Coins", 5) end
    return nil
end

task.spawn(function()
    local coins = getCoins()
    if not coins then return end
    amtLbl.Text = formatNumberWithCommas(tostring(coins.Value))
    
    coins.Changed:Connect(function(newVal)
        amtLbl.Text = formatNumberWithCommas(tostring(newVal))
        
        local origSize = UDim2.new(0, 16, 0, 16)
        local pulseSize = UDim2.new(0, 24, 0, 24)
        
        circle.Size = pulseSize
        TweenService:Create(circle, TweenInfo.new(0.3, Enum.EasingStyle.Bounce), {Size = origSize}):Play()
        
        local origColor = amtLbl.TextColor3
        amtLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        TweenService:Create(amtLbl, TweenInfo.new(0.3), {TextColor3 = origColor}):Play()
    end)
end)
