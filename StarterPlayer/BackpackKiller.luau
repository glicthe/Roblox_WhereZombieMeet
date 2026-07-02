local StarterGui = game:GetService("StarterGui")

task.spawn(function()
    while true do
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end)
        task.wait(0.5) -- Terus pastikan mati setiap setengah detik
    end
end)