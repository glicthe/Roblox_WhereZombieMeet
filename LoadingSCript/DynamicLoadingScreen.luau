local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local imageIds = {
	"rbxthumb://type=Asset&id=115591909421248&w=768&h=432",
	"rbxthumb://type=Asset&id=98779330362185&w=768&h=432",
	"rbxthumb://type=Asset&id=127919046023749&w=768&h=432",
	"rbxthumb://type=Asset&id=78027781823023&w=768&h=432",
	"rbxthumb://type=Asset&id=98869751195270&w=768&h=432"
}

-- =========================================================
-- 1. BUAT UI & TEKS (MENGGUNAKAN FONT BAWAAN YANG AMAN)
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "CampaignLoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local bg = Instance.new("ImageLabel")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bg.Image = imageIds[math.random(1, #imageIds)]
bg.ScaleType = Enum.ScaleType.Crop
bg.ImageTransparency = 1 
bg.Parent = gui

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(1, 1)
container.Position = UDim2.new(0.97, 0, 0.95, 0)
container.Size = UDim2.new(0, 320, 0, 60)
container.BackgroundTransparency = 1
container.Parent = gui 

local loadingText = Instance.new("TextLabel")
loadingText.Text = "Loading"
loadingText.Font = Enum.Font.Oswald -- Font tipis dan aman (bawaan)
loadingText.TextSize = 42 
loadingText.TextColor3 = Color3.fromRGB(230, 230, 230) 
loadingText.TextStrokeTransparency = 1 
loadingText.BackgroundTransparency = 1
loadingText.Size = UDim2.new(0, 220, 1, 0)
loadingText.Position = UDim2.new(0, 0, 0, 0)
loadingText.TextXAlignment = Enum.TextXAlignment.Right
loadingText.Parent = container

local dots = {}
for i = 1, 3 do
	local dot = Instance.new("TextLabel")
	dot.Text = "."
	dot.Font = Enum.Font.Oswald
	dot.TextSize = 42
	dot.TextColor3 = Color3.fromRGB(230, 230, 230)
	dot.TextStrokeTransparency = 1
	dot.BackgroundTransparency = 1
	dot.Size = UDim2.new(0, 15, 1, 0)
	dot.Position = UDim2.new(0, 220 + (i * 15), 0, 0)
	dot.Parent = container
	table.insert(dots, dot)
end

local skipBtn = Instance.new("TextButton")
skipBtn.Text = "SKIP >>"
skipBtn.Font = Enum.Font.Oswald
skipBtn.TextSize = 18
skipBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
skipBtn.TextStrokeTransparency = 1
skipBtn.BackgroundTransparency = 1
skipBtn.AnchorPoint = Vector2.new(1, 1)
skipBtn.Position = UDim2.new(0.97, 0, 0.88, 0) 
skipBtn.Size = UDim2.new(0, 100, 0, 30)
skipBtn.TextXAlignment = Enum.TextXAlignment.Right
skipBtn.TextTransparency = 1 
skipBtn.Active = false
skipBtn.Parent = gui

-- =========================================================
-- 2. ANIMASI TITIK MELOMPAT
-- =========================================================
local isAnimating = true
task.spawn(function()
	local timePassed = 0
	while isAnimating do
		timePassed += RunService.RenderStepped:Wait()
		for i, dot in ipairs(dots) do
			local yOffset = math.sin(timePassed * 6 + (i * 1.2)) * 6 
			dot.Position = UDim2.new(0, 220 + (i * 15), 0, yOffset)
		end
	end
end)

-- =========================================================
-- 3. PROSES LOADING
-- =========================================================
local assetsReady = false
local skipRequested = false

skipBtn.MouseButton1Click:Connect(function()
	skipRequested = true
	skipBtn.Text = "SKIPPING..."
end)

task.delay(6, function()
	if not assetsReady and not skipRequested then
		skipBtn.Active = true
		TweenService:Create(skipBtn, TweenInfo.new(1.5), {TextTransparency = 0.3}):Play()
	end
end)

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({bg})
	end)

	TweenService:Create(bg, TweenInfo.new(1.5), {ImageTransparency = 0}):Play()

	pcall(function()
		ContentProvider:PreloadAsync({workspace, game:GetService("ReplicatedStorage")})
	end)

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	assetsReady = true
end)

while not assetsReady and not skipRequested do
	RunService.RenderStepped:Wait()
end

-- =========================================================
-- 4. TRANSISI KELUAR
-- =========================================================
isAnimating = false 
for _, dot in ipairs(dots) do 
	dot.Visible = false 
end

local fadeOut = TweenService:Create(bg, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageTransparency = 1, BackgroundTransparency = 1})
local fadeText = TweenService:Create(loadingText, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 1})
local fadeSkip = TweenService:Create(skipBtn, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 1})

fadeOut:Play()
fadeText:Play()
fadeSkip:Play()

fadeOut.Completed:Wait()
gui:Destroy()