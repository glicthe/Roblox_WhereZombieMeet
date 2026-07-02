local RepStorage = game:GetService("ReplicatedStorage")
local animsFolder = RepStorage:WaitForChild("Animations")
local MenuEvent = RepStorage:WaitForChild("Event")

-- Fungsi pembantu untuk mencari Dummy (di Workspace atau di dalam folder COPY_THIS_TO_WZM)
local function getDummy(name)
	local dummy = workspace:FindFirstChild(name)
	if not dummy then
		local folder = workspace:FindFirstChild("COPY_THIS_TO_WZM")
		if folder then
			dummy = folder:WaitForChild(name, 10)
		end
	end
	if not dummy then
		dummy = workspace:WaitForChild(name, 10)
	end
	return dummy
end

-- 1. Setup Variabel Karakter Pertama (MenuDummy)
local dummy1 = getDummy("MenuDummy")
local animator1 = dummy1 and dummy1:WaitForChild("Humanoid"):WaitForChild("Animator")
local anim1 = animsFolder:WaitForChild("Idle_V1")
local currentTrack1 = nil

-- 2. Setup Variabel Karakter Kedua (MenuDummy1)
local dummy2 = getDummy("MenuDummy1")
local animator2 = dummy2 and dummy2:WaitForChild("Humanoid"):WaitForChild("Animator")
local anim2 = animsFolder:WaitForChild("Idle_V2")
local currentTrack2 = nil

-- 3. Setup Variabel Karakter Ketiga (MenuDummy2)
local dummy3 = getDummy("MenuDummy2")
local animator3 = dummy3 and dummy3:WaitForChild("Humanoid"):WaitForChild("Animator")
local anim3 = animsFolder:WaitForChild("Idle_V3")
local currentTrack3 = nil

-- 4. Menjalankan Event On/Off untuk Ketiga Karakter
MenuEvent.Event:Connect(function(Value)
	if Value == true then -- ON (Saat Menu Terbuka)
		if animator1 then
			currentTrack1 = animator1:LoadAnimation(anim1)
			currentTrack1.Looped = true
			currentTrack1:Play(0.5)
		end
		if animator2 then
			currentTrack2 = animator2:LoadAnimation(anim2)
			currentTrack2.Looped = true
			currentTrack2:Play(0.5)
		end
		if animator3 then
			currentTrack3 = animator3:LoadAnimation(anim3)
			currentTrack3.Looped = true
			currentTrack3:Play(0.5)
		end
	else -- OFF (Saat Menu Tertutup / Tombol Play Ditekan)
		if currentTrack1 then currentTrack1:Stop(0.5); currentTrack1 = nil end
		if currentTrack2 then currentTrack2:Stop(0.5); currentTrack2 = nil end
		if currentTrack3 then currentTrack3:Stop(0.5); currentTrack3 = nil end
	end
end)