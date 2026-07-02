--[[
	CameraZoomMode - Shortcut tombol V untuk mengubah mode kamera
	Mode: Tengah (default) -> Jauh -> Dekat -> Tengah (loop)
	Scroll manual tetap berfungsi normal
	
	Cara kerja:
	- Menekan V akan mengganti mode kamera (Tengah -> Jauh -> Dekat -> loop)
	- Setelah snap ke mode tertentu, scroll mouse tetap bisa mengubah zoom
	- Menggunakan RenderStepped untuk memastikan zoom teraplikasi setelah script lain
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ============================
-- KONFIGURASI MODE KAMERA
-- ============================
local CAMERA_MODES = {
	{ name = "Tengah",  zoomDistance = 12 },  -- Default (seperti gambar kamera 2)
	{ name = "Jauh",    zoomDistance = 24 },  -- Kamera jauh
	{ name = "Dekat",   zoomDistance = 6  },  -- Kamera dekat
}

-- Batas normal zoom (agar scroll tetap bisa digunakan)
local NORMAL_MIN_ZOOM = 0.5
local NORMAL_MAX_ZOOM = 128

-- Durasi snap zoom (berapa lama zoom dikunci ke target)
local SNAP_DURATION = 0.4

-- ============================
-- STATE
-- ============================
local currentModeIndex = 1 -- Mulai dari mode "Tengah"
local isSnapping = false
local snapEndTime = 0
local snapTargetDistance = CAMERA_MODES[1].zoomDistance
local isChatting = false

-- ============================
-- FUNGSI
-- ============================

local function cycleMode()
	if isSnapping then return end
	
	currentModeIndex = (currentModeIndex % #CAMERA_MODES) + 1
	local mode = CAMERA_MODES[currentModeIndex]
	
	-- Aktifkan snap mode
	isSnapping = true
	snapTargetDistance = mode.zoomDistance
	snapEndTime = tick() + SNAP_DURATION
end

-- ============================
-- RENDER STEP - Jalankan SETELAH script kamera lain
-- ============================
-- Menggunakan prioritas Camera.Value + 1 agar berjalan setelah Bobbing Camera & Dynamic Camera
RunService:BindToRenderStep("CameraZoomMode", Enum.RenderPriority.Camera.Value + 2, function()
	if isSnapping then
		-- Paksa zoom ke target distance (override script lain)
		player.CameraMinZoomDistance = snapTargetDistance
		player.CameraMaxZoomDistance = snapTargetDistance
		
		-- Cek apakah durasi snap sudah selesai
		if tick() >= snapEndTime then
			isSnapping = false
			-- Kembalikan range zoom normal agar scroll tetap berfungsi
			player.CameraMinZoomDistance = NORMAL_MIN_ZOOM
			player.CameraMaxZoomDistance = NORMAL_MAX_ZOOM
		end
	end
end)

-- ============================
-- DETEKSI CHAT AKTIF
-- ============================
local textChatService = game:GetService("TextChatService")
if textChatService then
	local chatInputBarConfiguration = textChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if chatInputBarConfiguration then
		local ok, _ = pcall(function()
			chatInputBarConfiguration:GetPropertyChangedSignal("IsFocused"):Connect(function()
				isChatting = chatInputBarConfiguration.IsFocused
			end)
		end)
	end
end

UserInputService.TextBoxFocused:Connect(function()
	isChatting = true
end)

UserInputService.TextBoxFocusReleased:Connect(function()
	isChatting = false
end)

-- ============================
-- INPUT HANDLER
-- ============================
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if isChatting then return end
	
	if input.KeyCode == Enum.KeyCode.V then
		cycleMode()
	end
end)

-- ============================
-- INISIALISASI
-- ============================
print("[CameraZoomMode] Loaded! Tekan V untuk mengubah mode kamera.")
print("[CameraZoomMode] Mode saat ini: " .. CAMERA_MODES[currentModeIndex].name)