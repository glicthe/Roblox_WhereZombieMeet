local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService") -- Menambahkan animasi mulus
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local MenuEvent = ReplicatedStorage:WaitForChild("Event")

local MenuGui = Player.PlayerGui:WaitForChild("ScreenGui")
local FullScreenGui = Player.PlayerGui:WaitForChild("FullScreenGui")
local MainFrame = MenuGui:WaitForChild("Frame")
local DarkScreen = FullScreenGui:WaitForChild("DarkScreen")

local ActiveMenu = true
local firsSession = true

FullScreenGui.Enabled = true

-- functions:

local function Toggleinteractability(ToggleState) -- false means "non-interactable", true "interactable"
	for _, v in pairs(MainFrame:GetChildren()) do
		if v:IsA("GuiButton") then
			v.Interactable = ToggleState
		end
	end
end

local function ToggleDarkScreen(ToggleState) 
	-- Mengatur durasi pudar (2 detik agar perlahan dan tidak bocor)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	if ToggleState == false then
		-- FADE OUT: Layar hitam memudar jadi transparan
		local fadeOut = TweenService:Create(DarkScreen, tweenInfo, {BackgroundTransparency = 1})
		fadeOut:Play()
		fadeOut.Completed:Wait() -- Menunggu sampai animasi pudar benar-benar selesai
		if FullScreenGui then
			FullScreenGui.Enabled = false
		end
	else
		if FullScreenGui then
			FullScreenGui.Enabled = true
		end
		if firsSession then
			-- Jika baru pertama masuk, pastikan langsung pekat tanpa animasi
			DarkScreen.BackgroundTransparency = 0
		else
			-- FADE IN: Layar kembali menghitam saat pindah menu
			local fadeIn = TweenService:Create(DarkScreen, tweenInfo, {BackgroundTransparency = 0})
			fadeIn:Play()
			fadeIn.Completed:Wait()
		end
	end
end
local function MenuSetUp(value)
	-- MENU "ON"
	if value == true then
		ActiveMenu = true
		Toggleinteractability(false)

		ToggleDarkScreen(true) -- Pastikan layar hitam

		MenuGui.Enabled = true
		local trackerGui = Player.PlayerGui:FindFirstChild("ActiveQuestTrackerHUD")
		if trackerGui then trackerGui.Enabled = false end
		MenuEvent:Fire(true) -- Mengaktifkan kamera menu

		-- Waktu tahan layar pekat khusus saat pertama kali join (biar aman)
		if firsSession then
			task.wait(1.5)
		end

		ToggleDarkScreen(false) -- Mulai memudarkan layar hitamnya secara perlahan
		Toggleinteractability(true)

		-- MENU OFF
	else
		if firsSession then
			firsSession = false
		end

		ActiveMenu = false
		Toggleinteractability(false)

		ToggleDarkScreen(true) -- Menghitamkan layar sebelum menghilang
		MenuGui.Enabled = false
		local trackerGui = Player.PlayerGui:FindFirstChild("ActiveQuestTrackerHUD")
		if trackerGui then trackerGui.Enabled = true end

		task.wait(0.5)

		MenuEvent:Fire(false)
		ToggleDarkScreen(false)
	end
end

local function clickButton(button)
	if button.Name == "PlayButton" then
		MenuSetUp(false)
	end
end

-- Menu Setup (Intelligent Teleport Detection):
local TeleportService = game:GetService("TeleportService")
local teleportData = nil
pcall(function()
	teleportData = TeleportService:GetLocalPlayerTeleportData()
end)

local isReturningFromStage = false
if teleportData and type(teleportData) == "table" and (teleportData.returningFromStage or teleportData.mode) then
	isReturningFromStage = true
end

if not isReturningFromStage then
	-- [KASUS A] MASUK DARI AWAL GAME / ROBLOX APP -> Tampilkan Main Menu
	MenuSetUp(true)
else
	-- [KASUS B] KEMBALI DARI CAMPAIGN / RAID -> SKIP MAIN MENU & LANGSUNG SUMMON!
	print("[Lobby WZM] Pemain kembali dari Campaign/Raid! Melewati Main Menu & langsung summon...")
	firsSession = false
	ActiveMenu = false
	MenuGui.Enabled = false
	
	-- Matikan musik main menu jika aktif
	local SoundService = game:GetService("SoundService")
	local mainMenuMusic = SoundService:FindFirstChild("MainMenuMusic")
	if mainMenuMusic then mainMenuMusic:Stop() end
	
	-- Tahan layar gelap sejenak selagi ReplicatedFirst.LoadingScreen berjalan
	ToggleDarkScreen(true)
	
	task.spawn(function()
		local character = Player.Character or Player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		
		-- Pindahkan kamera ke karakter pemain
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		workspace.CurrentCamera.CameraSubject = humanoid
		
		-- Beritahu server bahwa menu utama mati
		MenuEvent:Fire(false)
		
		-- Aktifkan HUD Quest Tracker
		local trackerGui = Player.PlayerGui:FindFirstChild("ActiveQuestTrackerHUD")
		if trackerGui then trackerGui.Enabled = true end
		
		-- Berikan waktu tunggu singkat agar loading screen mulus
		task.wait(2.5)
		ToggleDarkScreen(false)
		print("[Lobby WZM] Berhasil summon langsung ke lobby tanpa menu utama!")
	end)
end



-- Connections:
for _, v in pairs(MainFrame:GetChildren()) do
	if v:IsA("GuiButton") and not v:IsA("TextBox") then
		v.MouseButton1Click:Connect(function()
			clickButton(v)
		end)
	end
end