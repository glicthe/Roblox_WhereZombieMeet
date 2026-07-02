local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local base = script.Parent:WaitForChild("MedievalTimerContainer"):WaitForChild("BasePlate")
local timerLabel = base:WaitForChild("TimeText")

local stageStats = ReplicatedStorage:WaitForChild("StageStats")
local stageTime = stageStats:WaitForChild("StageTime")
local aggroVal = stageStats:WaitForChild("BossAggroed")

script.Parent.Enabled = false

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end
timerLabel.Text = formatTime(stageTime.Value)
stageTime.Changed:Connect(function(val)
    timerLabel.Text = formatTime(val)
end)

-- Kumpulkan original transparency untuk Fade In
local originalTrans = {}
for _, v in ipairs(script.Parent:GetDescendants()) do
    if v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel") then
        originalTrans[v] = {
            bg = v.BackgroundTransparency,
            txt = (v:IsA("TextLabel") and v.TextTransparency) or 1,
            stroke = (v:IsA("TextLabel") and v.TextStrokeTransparency) or 1
        }
        v.BackgroundTransparency = 1
        if v:IsA("TextLabel") then
            v.TextTransparency = 1
            v.TextStrokeTransparency = 1
        end
    elseif v:IsA("UIStroke") then
        originalTrans[v] = { strokeTrans = v.Transparency }
        v.Transparency = 1
    end
end

local hasFadedIn = false

task.spawn(function()
    while true do
        task.wait(0.2)
        local boss = workspace:FindFirstChild("HADES")
        if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
            if aggroVal.Value == true then
                if not hasFadedIn then
                    script.Parent.Enabled = true
                    hasFadedIn = true
                    -- Jalankan animasi Fade In
                    for obj, props in pairs(originalTrans) do
                        if obj:IsA("Frame") or obj:IsA("ImageLabel") then
                            TweenService:Create(obj, TweenInfo.new(1.5), {BackgroundTransparency = props.bg}):Play()
                        elseif obj:IsA("TextLabel") then
                            TweenService:Create(obj, TweenInfo.new(1.5), {BackgroundTransparency = props.bg, TextTransparency = props.txt, TextStrokeTransparency = props.stroke}):Play()
                        elseif obj:IsA("UIStroke") then
                            TweenService:Create(obj, TweenInfo.new(1.5), {Transparency = props.strokeTrans}):Play()
                        end
                    end
                end
            end
        else
            if hasFadedIn then
                hasFadedIn = false
                -- Fade out when boss dies
                for obj, _ in pairs(originalTrans) do
                    if obj:IsA("Frame") or obj:IsA("ImageLabel") then
                        TweenService:Create(obj, TweenInfo.new(1.5), {BackgroundTransparency = 1}):Play()
                    elseif obj:IsA("TextLabel") then
                        TweenService:Create(obj, TweenInfo.new(1.5), {BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1}):Play()
                    elseif obj:IsA("UIStroke") then
                        TweenService:Create(obj, TweenInfo.new(1.5), {Transparency = 1}):Play()
                    end
                end
                task.delay(1.5, function() script.Parent.Enabled = false end)
            end
        end
    end
end)