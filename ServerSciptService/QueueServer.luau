--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

--// Modules
local ZoneModule = require(ReplicatedStorage.Modules.Zone)
local SafeTeleport = require(ReplicatedStorage.Modules.SafeTeleport)

--// Objects
local TeleportZones = game.Workspace.TeleportZones
local Configuration = TeleportZones.Configuration
local QueueRemote = ReplicatedStorage.Remotes.QueueRemote

--// Variables
local ZoneData = {}

function SafeDisconnect(conn)
	if conn and conn.Connected then
		conn:Disconnect()
	end
end

function CreateParty(Plr, TpZones, MaxPlayer)
	ZoneData[TpZones]["IsReady"] = true
	ZoneData[TpZones]["MaxPlayers"] = MaxPlayer
	TpZones.BillboardGui.PlayerCount.Text = #ZoneData[TpZones]["Players"].."/"..ZoneData[TpZones]["MaxPlayers"]

	task.spawn(function()
		-- Mengambil waktu tunggu standar dari folder Configuration
		local timeLeft = Configuration.Countdown.Value

		-- Loop dinamis yang mengecek kondisi setiap detik
		while timeLeft > 0 do
			if ZoneData[TpZones]["IsReady"] == false then break end -- Berhenti jika semua pemain keluar

			local jumlahPemain = #ZoneData[TpZones]["Players"]

			-- // FITUR DYNAMIC TIMER //
			if jumlahPemain == 1 and timeLeft > 10 then
				timeLeft = 10 -- Jika sendirian, potong waktu jadi maksimal 10 detik
			elseif jumlahPemain == MaxPlayer and timeLeft > 2 then
				timeLeft = 2 -- Jika antrean sudah penuh, langsung gas di 2 detik
			end

			TpZones.BillboardGui.StateLabel.Text = "Starting in " .. timeLeft
			task.wait(1)
			timeLeft = timeLeft - 1
		end

		if ZoneData[TpZones]["IsReady"] == false then return end

		-- Waktu habis, eksekusi Teleport!
		TpZones.BillboardGui.StateLabel.Text = "Teleporting..."
		local TeleportOptions = Instance.new("TeleportOptions")
		TeleportOptions.ShouldReserveServer = false 

		-- Membaca TargetPlaceId yang sudah kita tanam di setiap kotak pijakan
		SafeTeleport(TpZones.TargetPlaceId.Value, ZoneData[TpZones]["Players"], TeleportOptions)
	end)
end

function JoinParty(Plr, ZoneContainer, TpZones, IsHost)
	-- Tambahkan pemain ke dalam daftar
	table.insert(ZoneData[TpZones]["Players"], Plr)

	-- Mengambil batas maksimal pemain dari Configuration
	local MaxPlayer = Configuration.HighestPlayer.Value

	if IsHost then
		ZoneData[TpZones]["MaxPlayers"] = MaxPlayer
	end

	TpZones.BillboardGui.PlayerCount.Text = #ZoneData[TpZones]["Players"].."/"..ZoneData[TpZones]["MaxPlayers"]

	-- AUTO-QUEUE: Jika dia host (pemain pertama), langsung mulai hitungan mundur
	if IsHost == true then
		CreateParty(Plr, TpZones, MaxPlayer)
	end

	-- Pindahkan fisik karakter pemain ke tengah kotak
	local Char = Plr.Character
	if not Char then return end
	local RootPart = Char:FindFirstChild("HumanoidRootPart")
	RootPart.CFrame = ZoneContainer.CFrame
end

function LeaveParty(Plr, TpZones)
	-- Cari pemain di dalam daftar dan hapus
	local playerIndex = table.find(ZoneData[TpZones]["Players"], Plr)
	if playerIndex then
		table.remove(ZoneData[TpZones]["Players"], playerIndex)
	end

	-- Perbarui UI Teks
	if ZoneData[TpZones]["MaxPlayers"] > 0 then
		TpZones.BillboardGui.PlayerCount.Text = #ZoneData[TpZones]["Players"].."/"..ZoneData[TpZones]["MaxPlayers"]
	end

	-- Jika pemain terakhir keluar, kembalikan kotak ke kondisi awal
	if #ZoneData[TpZones]["Players"] == 0 then
		ZoneData[TpZones] = {
			["IsReady"] = false,
			["MaxPlayers"] = 0,
			["Players"] = {},
		}
		TpZones.BillboardGui.PlayerCount.Text = "0/4"
		TpZones.BillboardGui.StateLabel.Text = "Waiting for players..."
	end

	-- Tendang fisik karakter pemain keluar dari kotak ke LobbyPos
	local Char = Plr.Character
	if not Char then return end
	local RootPart = Char:FindFirstChild("HumanoidRootPart")
	if TeleportZones:FindFirstChild("LobbyPos") then
		RootPart.CFrame = TeleportZones.LobbyPos.CFrame
	end
end

-- Deteksi interaksi masuk dan keluar area kotak menggunakan ZonePlus
for _, TpZones in pairs(TeleportZones:GetChildren()) do

	if TpZones:IsA("Model") then

		ZoneData[TpZones] = {
			["IsReady"] = false,
			["MaxPlayers"] = 0,
			["Players"] = {},
		}

		local ZoneContainer = TpZones.ZoneContainer
		local Zone = ZoneModule.new(ZoneContainer)

		Zone.playerEntered:Connect(function(Plr)
			if #ZoneData[TpZones]["Players"] == 0 then
				JoinParty(Plr, ZoneContainer, TpZones, true) -- Masuk sebagai Host
			elseif #ZoneData[TpZones]["Players"] > 0 
				and ZoneData[TpZones]["IsReady"] == true
				and #ZoneData[TpZones]["Players"] < ZoneData[TpZones]["MaxPlayers"]
			then 
				JoinParty(Plr, ZoneContainer, TpZones, false) -- Masuk sebagai Anggota tambahan
			end
		end)

		Zone.playerExited:Connect(function(Plr)
			-- Jika pemain berjalan keluar dari kotak, sistem otomatis membatalkan antrean mereka
			if table.find(ZoneData[TpZones]["Players"], Plr) then
				LeaveParty(Plr, TpZones)
			end
		end)
	end
end

-- Cegah error jika pemain tiba-tiba keluar dari game saat sedang antre
game:GetService("Players").PlayerRemoving:Connect(function(Plr)
	for _, TpZones in pairs(TeleportZones:GetChildren()) do
		if ZoneData[TpZones] and table.find(ZoneData[TpZones]["Players"], Plr) then
			LeaveParty(Plr, TpZones)
		end
	end
end)