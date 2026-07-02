local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local RunService = game:GetService("RunService")

local function createTrail(part, isR6)
    -- Tentukan posisi pusat di mana jejak akan keluar
    -- Jika R6 (Left Arm), ketiak ada di atas (+1) dan ujung tangan (kepalan) ada di bawah (-1)
    -- Jika R15 (LeftHand), tengahnya adalah 0
    local centerY = isR6 and -0.9 or 0
    
    -- Jarak antara titik atas dan bawah diperkecil agar trails jauh lebih tipis (0.15 dari pusat)
    local a0 = Instance.new("Attachment")
    a0.Name = "TrailTop"
    a0.Position = Vector3.new(0, centerY + 0.15, 0)
    a0.Parent = part
    
    local a1 = Instance.new("Attachment")
    a1.Name = "TrailBot"
    a1.Position = Vector3.new(0, centerY - 0.15, 0)
    a1.Parent = part
    
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = 0.2
    trail.MinLength = 0.1
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0)
    })
    
    trail.LightEmission = 0.8
    trail.Enabled = false
    trail.Parent = part
    
    return trail
end

local trails = {}

local function setupArms()
    local leftR15 = char:FindFirstChild("LeftHand")
    local rightR15 = char:FindFirstChild("RightHand")
    local leftR6 = char:FindFirstChild("Left Arm")
    local rightR6 = char:FindFirstChild("Right Arm")
    
    if leftR15 then table.insert(trails, createTrail(leftR15, false)) end
    if rightR15 then table.insert(trails, createTrail(rightR15, false)) end
    if leftR6 then table.insert(trails, createTrail(leftR6, true)) end
    if rightR6 then table.insert(trails, createTrail(rightR6, true)) end
end

setupArms()

RunService.Heartbeat:Connect(function()
    if not root then return end
    local vel = root.Velocity
    local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    
    local isRunning = speed > 18
    
    for _, trail in ipairs(trails) do
        if trail.Enabled ~= isRunning then
            trail.Enabled = isRunning
        end
    end
end)
