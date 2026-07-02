local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

pcall(function()
    PhysicsService:RegisterCollisionGroup("ZombiesGroup")
    PhysicsService:CollisionGroupSetCollidable("ZombiesGroup", "ZombiesGroup", false)
end)



local ATTACK_RANGE  = 5
local ATTACK_DAMAGE = 5
local ATTACK_CD     = 2.0
local LEASH_RANGE   = 100

local function nearestPlayer(fromPos)
    local closest, closestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local d = (root.Position - fromPos).Magnitude
                if d < closestDist then
                    closest, closestDist = root, d
                end
            end
        end
    end
    return closest, closestDist
end

local function hasLineOfSight(from, to, ignoreList)
    local dir = (to - from)
    local ray = Ray.new(from, dir)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
    return hit == nil
end

local function setupZombie(model)
    local hum  = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    -- Disable jumping
    hum.JumpPower = 0
    hum.JumpHeight = 0
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "ZombiesGroup"
            pcall(function() part:SetNetworkOwner(nil) end)
        end
    end

    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.HealthDisplayType   = Enum.HumanoidHealthDisplayType.AlwaysOff

    local alive = true
    local spawnPos = root.Position

    -- Give each zombie slightly different personality
    local chaseSpeed = 9 + math.random() * 3       -- 9~12
    local pathInterval = 0.8 + math.random() * 0.6  -- 0.8~1.4s between recomputes
    local waypointReach = 2.5 + math.random()       -- 2.5~3.5 studs to consider "arrived"

    local path = PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentHeight = 5,
        AgentCanJump = false,
        WaypointSpacing = 3
    })

    -- Attack Animation
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
        local attackAnim = Instance.new("Animation")
	attackAnim.AnimationId = "rbxassetid://78908878649486"
    local attackTrack = animator:LoadAnimation(attackAnim)
    attackTrack.Priority = Enum.AnimationPriority.Action
    attackTrack.Looped = false
    
    local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://86023348614572"
    local idleTrack = animator:LoadAnimation(idleAnim)
    idleTrack.Priority = Enum.AnimationPriority.Idle
    idleTrack.Looped = true
    idleTrack:Play()
    
    local hitAnim = Instance.new("Animation")
	hitAnim.AnimationId = "rbxassetid://111531309371001"
    local hitTrack = animator:LoadAnimation(hitAnim)
    hitTrack.Priority = Enum.AnimationPriority.Action
    hitTrack.Looped = false


    local function aiLoop()
        local lastAttack = 0
        local lastPathTime = 0
        local waypoints = {}
        local wpIndex = 1
        local lastTargetPos = Vector3.zero
        local stuckTimer = 0
        local lastPos = root.Position

        while alive and model.Parent do
            if hum.Health <= 0 then
                alive = false
                break
            end

            local dt = task.wait(0.1)

            if model:FindFirstChild("stunned") then
                hum:MoveTo(root.Position)
                continue
            end

            local target, dist = nearestPlayer(root.Position)
            local distFromSpawn = target and (target.Position - spawnPos).Magnitude or 0

            -- LEASH: return home if player too far
            if not target or dist > 80 or distFromSpawn > LEASH_RANGE then
                model:SetAttribute("IsChasing", false)
                hum.WalkSpeed = chaseSpeed
                local distHome = (root.Position - spawnPos).Magnitude
                if distHome > 5 then
                    hum:MoveTo(spawnPos)
                end
                waypoints = {}
                wpIndex = 1
                continue
            end

            model:SetAttribute("IsChasing", true)
            hum.WalkSpeed = chaseSpeed

            -- ATTACK: only with clear line of sight
            local los = hasLineOfSight(root.Position, target.Position, {model, target.Parent})
            if los and dist <= ATTACK_RANGE then
                hum:MoveTo(root.Position)
                local now = tick()
                if now - lastAttack >= ATTACK_CD then
                    lastAttack = now

                    attackTrack:Play()


                    local th = target.Parent:FindFirstChildOfClass("Humanoid")
                    if th and th.Health > 0 then
                        th:TakeDamage(ATTACK_DAMAGE)
                    end
                end
                continue
            end

            -- STUCK DETECTION: if barely moved in a while, force recompute
            local movedDist = (root.Position - lastPos).Magnitude
            lastPos = root.Position
            if movedDist < 0.3 then
                stuckTimer = stuckTimer + dt
            else
                stuckTimer = 0
            end

            -- PATH RECOMPUTE: when needed
            local now = tick()
            local targetMoved = (target.Position - lastTargetPos).Magnitude
            local needsRecompute = false

            if now - lastPathTime >= pathInterval then needsRecompute = true end
            if targetMoved > 6 then needsRecompute = true end
            if wpIndex > #waypoints then needsRecompute = true end
            if stuckTimer > 1.0 then needsRecompute = true; stuckTimer = 0 end

            if needsRecompute then
                lastPathTime = now
                lastTargetPos = target.Position

                local s = pcall(function()
                    path:ComputeAsync(root.Position, target.Position)
                end)

                if s and path.Status == Enum.PathStatus.Success then
                    waypoints = path:GetWaypoints()
                    wpIndex = 2  -- skip start
                else
                    waypoints = {}
                    wpIndex = 1
                end
            end

            -- FOLLOW WAYPOINTS: smooth, non-blocking
            if #waypoints > 0 and wpIndex <= #waypoints then
                local wp = waypoints[wpIndex]
                hum:MoveTo(wp.Position)

                -- Advance to next waypoint when close enough
                local d2d = ((root.Position - wp.Position) * Vector3.new(1, 0, 1)).Magnitude
                if d2d < waypointReach then
                    wpIndex = wpIndex + 1
                end
            elseif los then
                -- Clear path with LOS, just walk toward them directly
                hum:MoveTo(target.Position)
            end
        end
    end

    task.spawn(aiLoop)

            local oldHealth = hum.Health
        hum.HealthChanged:Connect(function(health)
            if health < oldHealth then
                hitTrack:Play()
            end
            oldHealth = health
        end)

    hum.Died:Connect(function()
        alive = false
    end)
end

local enemyFolder = workspace:FindFirstChild('Enemies')
if not enemyFolder then enemyFolder = Instance.new('Folder'); enemyFolder.Name = 'Enemies'; enemyFolder.Parent = workspace end

for _, child in ipairs(enemyFolder:GetChildren()) do
    if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
        setupZombie(child)
    end
end

enemyFolder.ChildAdded:Connect(function(child)
    if child:IsA("Model") then
        task.wait(0.1)
        if child:FindFirstChildOfClass("Humanoid") then
            setupZombie(child)
        end
    end
end)
