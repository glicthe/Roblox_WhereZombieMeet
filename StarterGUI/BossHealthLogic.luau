local TweenService = game:GetService("TweenService")
local container = script.Parent:WaitForChild("BossBarContainer")
local damageBar = container:WaitForChild("DamageBar")
local fillBar = container:WaitForChild("Fill")
local nameLabel = container:WaitForChild("BossName")
local hpLabel = container:WaitForChild("HPLabel")

container.Visible = false
local boss = workspace:WaitForChild("HADES", 10)
if not boss then return end
local humanoid = boss:WaitForChild("Humanoid", 10)
if not humanoid then return end

local rs = game:GetService("ReplicatedStorage")
local stats = rs:WaitForChild("StageStats")
local aggroVal = stats:WaitForChild("BossAggroed")

local isDead = false

local function updateUI()
    if isDead then return end
    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    if maxHealth < health then maxHealth = health end
    
    local hpInt = math.max(0, math.floor(health))
    local maxInt = math.floor(maxHealth)
    hpLabel.Text = tostring(hpInt) .. " / " .. tostring(maxInt)
    
    local pct = 0
    if maxHealth > 0 then pct = math.clamp(health / maxHealth, 0, 1) end
    
    TweenService:Create(fillBar, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    task.delay(0.5, function()
        if humanoid.Health == health and not isDead then
            TweenService:Create(damageBar, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
        end
    end)
    
    if health <= 0 then
        isDead = true
        task.delay(1, function()
            for _, v in ipairs(container:GetDescendants()) do
                if v:IsA("Frame") then
                    TweenService:Create(v, TweenInfo.new(2), {BackgroundTransparency = 1}):Play()
                elseif v:IsA("TextLabel") then
                    TweenService:Create(v, TweenInfo.new(2), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
                elseif v:IsA("UIStroke") then
                    TweenService:Create(v, TweenInfo.new(2), {Transparency = 1}):Play()
                end
            end
            task.delay(2, function() script.Parent:Destroy() end)
        end)
    end
end

updateUI()
humanoid.HealthChanged:Connect(updateUI)
humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateUI)

-- Pure Fade In Reveal (Tanpa mengubah size!)
local originalTrans = {}
for _, v in ipairs(container:GetDescendants()) do
    if v:IsA("Frame") then
        originalTrans[v] = {bg = v.BackgroundTransparency}
        v.BackgroundTransparency = 1
    elseif v:IsA("TextLabel") then
        originalTrans[v] = {bg = v.BackgroundTransparency, txt = v.TextTransparency, stroke = v.TextStrokeTransparency}
        v.BackgroundTransparency = 1
        v.TextTransparency = 1
        v.TextStrokeTransparency = 1
    elseif v:IsA("UIStroke") then
        originalTrans[v] = {strokeTrans = v.Transparency}
        v.Transparency = 1
    end
end
originalTrans[container] = {bg = container.BackgroundTransparency}
container.BackgroundTransparency = 1

local function doReveal()
    if not aggroVal.Value then return end
    container.Visible = true
    
    for obj, props in pairs(originalTrans) do
        if obj:IsA("Frame") then
            TweenService:Create(obj, TweenInfo.new(2, Enum.EasingStyle.Sine), {BackgroundTransparency = props.bg}):Play()
        elseif obj:IsA("TextLabel") then
            TweenService:Create(obj, TweenInfo.new(2, Enum.EasingStyle.Sine), {BackgroundTransparency = props.bg, TextTransparency = props.txt, TextStrokeTransparency = props.stroke}):Play()
        elseif obj:IsA("UIStroke") then
            TweenService:Create(obj, TweenInfo.new(2, Enum.EasingStyle.Sine), {Transparency = props.strokeTrans}):Play()
        end
    end
end

if aggroVal.Value then
    doReveal()
else
    aggroVal.Changed:Connect(function(val)
        if val then doReveal() end
    end)
end