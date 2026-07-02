local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local bg = script.Parent:WaitForChild("Background")
local statsPanel = bg:WaitForChild("StatsPanel")
local btnContainer = bg:WaitForChild("NextStageBtn")
local actionBtn = btnContainer:WaitForChild("ActionBtn")

local hoverSound = SoundService:FindFirstChild("hover") or script.Parent:FindFirstChild("hover")
local clickSound = SoundService:FindFirstChild("button") or script.Parent:FindFirstChild("button")

local LOBBY_PLACE_ID = 136387127409210

local BASE_COINS = 500
local isVisible = false
local hasClicked = false

bg.GroupTransparency = 1
bg.Visible = false

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

local event = ReplicatedStorage:WaitForChild("ShowRaidCleared", 5)

if event then
    event.OnClientEvent:Connect(function(timeTakenSeconds, playerDataTable)
        local timeStr = formatTime(timeTakenSeconds)
                local timeLbl = statsPanel:FindFirstChild("TimeElapsed")
        if timeLbl then timeLbl.Text = "TIME ELAPSED: " .. timeStr end
        
        local listF = statsPanel:FindFirstChild("PlayerListFrame")
        for _, child in ipairs(listF:GetChildren()) do
            if child.Name == "PlayerRow_Dynamic" then
                child:Destroy()
            end
        end
        
        local template = listF:FindFirstChild("PlayerRowTemplate")
        if template then
            template.Visible = false
            
            local pList = {}
            if type(playerDataTable) == "table" then
                for k, v in pairs(playerDataTable) do
                    if type(v) == "table" and v.damage then
                        table.insert(pList, {
                            userId = v.userId or 0,
                            name = v.name or "Player",
                            damage = tonumber(v.damage) or 0
                        })
                    elseif type(v) == "number" then
                        local pName = tostring(k)
                        local uId = tonumber(k) or 0
                        local plr = (uId > 0) and Players:GetPlayerByUserId(uId) or Players:FindFirstChild(pName)
                        if plr then
                            pName = plr.Name
                            uId = plr.UserId
                        end
                        table.insert(pList, {userId = uId, name = pName, damage = v})
                    end
                end
            end
            
            if #pList > 0 then
                table.sort(pList, function(a, b) return a.damage > b.damage end)
                local topDamage = pList[1].damage
                if topDamage <= 0 then topDamage = 1 end
                
                for i, pStat in ipairs(pList) do
                    local isMVP = (i == 1)
                    local bonus = 0
                    if timeTakenSeconds < 300 then
                        bonus = 500
                        if #pList == 1 and isMVP then bonus = bonus + 500 end
                    elseif timeTakenSeconds < 600 then
                        bonus = 200
                    end
                    
                    local totalCoins = BASE_COINS + bonus
                    
                    local newRow = template:Clone()
                    newRow.Name = "PlayerRow_Dynamic"
                    newRow.LayoutOrder = i
                    
                    local pn = newRow:FindFirstChild("PlayerName", true)
                    if pn then pn.Text = pStat.name end
                    
                    local cc = newRow:FindFirstChild("CoinContainer", true)
                    if cc and cc:FindFirstChild("Amount") then 
                        cc.Amount.Text = "+" .. tostring(totalCoins) 
                    end
                    
                    local pct = math.clamp(pStat.damage / topDamage, 0, 1)
                    local dc = newRow:FindFirstChild("DmgContainer", true)
                    if dc then
                        if dc:FindFirstChild("DmgBarBg") and dc.DmgBarBg:FindFirstChild("Fill") then
                            dc.DmgBarBg.Fill.Size = UDim2.new(pct, 0, 1, 0)
                        end
                        if dc:FindFirstChild("DmgText") then
                            dc.DmgText.Text = tostring(pStat.damage) .. " DMG"
                        end
                    end
                    
                    local mvpBadge = newRow:FindFirstChild("MVPBadge", true)
                    if isMVP and mvpBadge then
                        mvpBadge.Visible = true
                    end
                    
                    if i == #pList and newRow:FindFirstChild("Divider", true) then
                        newRow.Divider.Visible = false
                    end
                    
                                        local avatar = newRow:FindFirstChild("Avatar", true)
                    if avatar then
                        local aStroke = avatar:FindFirstChildOfClass("UIStroke")
                        if not aStroke then
                            aStroke = Instance.new("UIStroke")
                            aStroke.Thickness = 1.5
                            aStroke.Parent = avatar
                        end
                        if i == 1 then
                            aStroke.Color = Color3.fromRGB(255, 215, 0)
                        elseif i == 2 then
                            aStroke.Color = Color3.fromRGB(200, 200, 210)
                        elseif i == 3 then
                            aStroke.Color = Color3.fromRGB(200, 100, 50)
                        else
                            aStroke.Color = Color3.fromRGB(60, 60, 60)
                        end
                        
                        if pStat.userId > 0 then
                            task.spawn(function()
                                local success, img = pcall(function()
                                    return Players:GetUserThumbnailAsync(pStat.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                                end)
                                if success then avatar.Image = img end
                            end)
                        end
                    end
                    
                    newRow.Visible = true
                    newRow.Parent = listF
                end
                                -- DYNAMIC RESIZING (Min 280px tall, stretches for 3+ players)
                                statsPanel.Size = UDim2.new(0.55, 0, 0, math.clamp(90 + (#pList * 75), 320, 410))
                
                -- FIX SCROLLING BUG: 
                -- If players > 4, we must align to Top so AutoCanvas doesn't clip them out of bounds.
                -- If 1-4 players, we align Center for aesthetic beauty.
                local vLayout = listF:FindFirstChildOfClass("UIListLayout")
                if vLayout then
                    if #pList > 4 then
                        vLayout.VerticalAlignment = Enum.VerticalAlignment.Top
                    else
                        vLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                    end
                end

            else
                -- DEBUG DISPLAY IF IT FAILS
                local debugRow = template:Clone()
                debugRow.Name = "PlayerRow_Dynamic"
                debugRow.LayoutOrder = 1
                if debugRow:FindFirstChild("PlayerName", true) then
                    local dump = HttpService:JSONEncode(playerDataTable)
                    if string.len(dump) > 100 then dump = string.sub(dump, 1, 100) .. "..." end
                    debugRow.PlayerName.Text = "ERR: " .. dump
                    debugRow.PlayerName.Size = UDim2.new(0, 500, 0, 30)
                    debugRow.PlayerName.TextColor3 = Color3.fromRGB(255, 50, 50)
                end
                
                -- Hide other things in debug mode
                local dAv = debugRow:FindFirstChild("Avatar", true); if dAv then dAv.Visible = false end
                local dCo = debugRow:FindFirstChild("CoinContainer", true); if dCo then dCo.Visible = false end
                local dDm = debugRow:FindFirstChild("DmgContainer", true); if dDm then dDm.Visible = false end
                
                debugRow.Visible = true
                debugRow.Parent = listF
                -- statsPanel.Size removed to keep user's Edit layout
            end
        end
        
        hasClicked = false
        isVisible = true
        bg.Visible = true
        actionBtn.Text = "CLAIM AND RETURN TO LOBBY"
        TweenService:Create(bg, TweenInfo.new(1.5, Enum.EasingStyle.Cubic), {GroupTransparency = 0}):Play()
    end)
end

local hoverIn = TweenService:Create(btnContainer, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 10, 10)})
local hoverOut = TweenService:Create(btnContainer, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 0, 0)})

actionBtn.MouseEnter:Connect(function() 
    if isVisible and not hasClicked then hoverIn:Play(); if hoverSound then hoverSound:Play() end end 
end)
actionBtn.MouseLeave:Connect(function() 
    if isVisible and not hasClicked then hoverOut:Play() end 
end)
actionBtn.MouseButton1Click:Connect(function()
    if isVisible and not hasClicked then
        hasClicked = true
        if clickSound then clickSound:Play() end
        actionBtn.Text = "RETURNING TO LOBBY..."
        
        -- [Smooth Instant Transition Overlay to mask networking delay]
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local transGui = Instance.new("ScreenGui")
        transGui.Name = "TeleportTransitionGui"
        transGui.DisplayOrder = 100000
        transGui.IgnoreGuiInset = true
        transGui.Parent = playerGui
        
        local blackFrame = Instance.new("Frame")
        blackFrame.Size = UDim2.new(1, 0, 1, 0)
        blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        blackFrame.BackgroundTransparency = 1
        blackFrame.Parent = transGui
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 0, 50)
        textLabel.Position = UDim2.new(0, 0, 0.5, -25)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "RETURNING TO LOBBY..."
        textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 24
        textLabel.TextTransparency = 1
        textLabel.Parent = blackFrame
        
        TweenService:Create(blackFrame, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()
        TweenService:Create(textLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
        
        task.spawn(function()
            local teleportData = { returningFromStage = true, mode = "Raid" }
            local success, err = pcall(function() TeleportService:Teleport(LOBBY_PLACE_ID, Players.LocalPlayer, teleportData) end)
            if not success then
                warn("Failed to teleport: " .. tostring(err))
                TweenService:Create(blackFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
                TweenService:Create(textLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
                task.wait(0.5)
                transGui:Destroy()
                actionBtn.Text = "TELEPORT FAILED"
                task.wait(2)
                hasClicked = false
                actionBtn.Text = "CLAIM AND RETURN TO LOBBY"
            end
        end)
    end
end)
