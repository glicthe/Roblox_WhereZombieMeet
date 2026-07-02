local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local gui = script.Parent
local overlay = gui:WaitForChild("Overlay")
local dialogFrame = gui:WaitForChild("DialogFrame")
local nameLabel = dialogFrame:WaitForChild("NameLabel")
local dialogText = dialogFrame:WaitForChild("DialogText")
local continueHint = dialogFrame:WaitForChild("ContinueHint")
local clickBtn = dialogFrame:WaitForChild("ClickBtn")
local clickSound = gui:WaitForChild("button")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QuestDialogRemote = Remotes:WaitForChild("QuestDialogRemote")
local QuestOpenGUI = Remotes:WaitForChild("QuestOpenGUI")

local isActive = false
local currentDialogIndex = 0
local dialogs = {}
local typewriterThread = nil
local isTyping = false
local fullText = ""

-- Typewriter effect
local function typewrite(text, label)
	isTyping = true
	fullText = text
	label.Text = ""
	continueHint.Visible = false
	label.TextTransparency = 0
	
	for i = 1, #text do
		if not isTyping then
			label.Text = text
			break
		end
		label.Text = string.sub(text, 1, i)
		task.wait(0.03)
	end
	
	isTyping = false
	continueHint.Visible = true
end

-- Show dialog GUI with fade in
local function showDialog(dialogList)
	dialogs = dialogList
	currentDialogIndex = 0
	isActive = true
	
	-- Reset
	dialogText.Text = ""
	continueHint.Visible = false
	-- Set transparency for fade-in
	overlay.BackgroundTransparency = 1
	dialogFrame.BackgroundTransparency = 1
	for _, child in ipairs(dialogFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			child.TextTransparency = 1
		end
		if child:IsA("UIStroke") then
			child.Transparency = 1
		end
		if child:IsA("Frame") then
			if child:FindFirstChild("Stroke") then
				child.Stroke.Transparency = 1
			end
		end
	end
	
	local topLine = dialogFrame:FindFirstChild("TopLine")
	if topLine then topLine.BackgroundTransparency = 1 end
	
	gui.Enabled = true
	
	-- Fade in
	local fadeTime = 0.4
	TweenService:Create(overlay, TweenInfo.new(fadeTime), {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(dialogFrame, TweenInfo.new(fadeTime), {BackgroundTransparency = 0.1}):Play()
	
	local outerStroke = dialogFrame:FindFirstChild("OuterStroke")
	if outerStroke then
		TweenService:Create(outerStroke, TweenInfo.new(fadeTime), {Transparency = 0}):Play()
	end
	
	local innerBorder = dialogFrame:FindFirstChild("InnerBorder")
	if innerBorder and innerBorder:FindFirstChild("Stroke") then
		TweenService:Create(innerBorder.Stroke, TweenInfo.new(fadeTime), {Transparency = 0.3}):Play()
	end
	
	if topLine then
		TweenService:Create(topLine, TweenInfo.new(fadeTime), {BackgroundTransparency = 0}):Play()
	end
	
	TweenService:Create(nameLabel, TweenInfo.new(fadeTime), {TextTransparency = 0}):Play()
	TweenService:Create(continueHint, TweenInfo.new(fadeTime), {TextTransparency = 0}):Play()
	dialogText.TextTransparency = 0
	
	task.wait(fadeTime)
	
	-- Start first dialog
	nextDialog()
end

-- Advance to next dialog
function nextDialog()
	currentDialogIndex = currentDialogIndex + 1
	
	if currentDialogIndex > #dialogs then
		-- All dialogs done, close and open quest board
		closeDialog()
		-- Request quest data from server
		QuestDialogRemote:FireServer("requestQuests")
		return
	end
	
	-- Type out the next dialog
	typewrite(dialogs[currentDialogIndex], dialogText)
end

-- Close dialog GUI
function closeDialog()
	isActive = false
	local fadeTime = 0.3
	
	TweenService:Create(overlay, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
	TweenService:Create(dialogFrame, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
	TweenService:Create(nameLabel, TweenInfo.new(fadeTime), {TextTransparency = 1}):Play()
	TweenService:Create(dialogText, TweenInfo.new(fadeTime), {TextTransparency = 1}):Play()
	TweenService:Create(continueHint, TweenInfo.new(fadeTime), {TextTransparency = 1}):Play()
	
	local outerStroke = dialogFrame:FindFirstChild("OuterStroke")
	if outerStroke then
		TweenService:Create(outerStroke, TweenInfo.new(fadeTime), {Transparency = 1}):Play()
	end
	
	local topLine = dialogFrame:FindFirstChild("TopLine")
	if topLine then
		TweenService:Create(topLine, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
	end
	
	task.wait(fadeTime)
	gui.Enabled = false
end

-- Click handler
clickBtn.MouseButton1Click:Connect(function()
	if not isActive then return end
	
	if isTyping then
		-- Skip typewriter, show full text
		isTyping = false
	else
		-- Advance to next
		clickSound:Play()
		nextDialog()
	end
end)

-- Listen for server to trigger dialog
QuestDialogRemote.OnClientEvent:Connect(function(dialogList)
	print("[QuestDialogController] Received dialog list from server! Showing dialog HUD...")
	if type(dialogList) == "table" then
		-- Pastikan FullScreenGui tidak menghalangi jika aktif secara tidak sengaja
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			local fullScreen = playerGui:FindFirstChild("FullScreenGui")
			if fullScreen then
				fullScreen.Enabled = false
			end
		end
		showDialog(dialogList)
	end
end)