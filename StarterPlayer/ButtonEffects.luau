local TS = game:GetService("TweenService")
local MenuGui = game.Players.LocalPlayer.PlayerGui:WaitForChild("ScreenGui")
local MainFrame = MenuGui:WaitForChild("Frame")

local ButtonDefaultSize = UDim2.new(1, 0,0.22, 0)
local ButtonBigSize = ButtonDefaultSize + UDim2.new(0.1,0,0.025,0)
local ButtonSmallSize = ButtonDefaultSize - UDim2.new(0.1,0,0.024,0)

local HoverSound = MainFrame:WaitForChild("hover Sound")
local HoldSound = MainFrame:WaitForChild("HoldSound")
local ReleaseSound = MainFrame:WaitForChild("Release Sound")

-- Functions:

local function MouseHover(button : GuiButton)
	TS:Create(button, TweenInfo.new(.15), {Size = ButtonBigSize}):Play()
	HoverSound:Play()
end

local function MouseLeave(button : GuiButton)
	TS:Create(button, TweenInfo.new(.15), {Size = ButtonDefaultSize}):Play()
end

local function MouseHold(button : GuiButton)
	TS:Create(button, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = ButtonSmallSize}):Play()
	HoldSound:Play()
end

local function MouseRelease(button : GuiButton)
	TS:Create(button, TweenInfo.new(.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = ButtonDefaultSize}):Play()
	ReleaseSound:Play()
end

-- Connections:

for _, v in pairs(MainFrame:GetChildren()) do
	if v:IsA("GuiButton") then
		v.MouseEnter:Connect(function()
			MouseHover(v)
		end)
		v.MouseLeave:Connect(function()
			MouseLeave(v)
		end)
		v.MouseButton1Down:Connect(function()
			MouseHold(v)
		end)
		v.MouseButton1Up:Connect(function()
			MouseRelease(v)
		end)
	end
end