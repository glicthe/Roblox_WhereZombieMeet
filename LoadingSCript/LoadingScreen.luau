local EXPECTED_LOCAL_SCRIPT_NAME = "LoadingScreen"
local EXPECTED_CONFIG_MODULE_NAME = "LoadingConfig"

if script.Name ~= EXPECTED_LOCAL_SCRIPT_NAME then
	warn(("[Crackline LoadingScreen] LocalScript name has been changed. Expected '%s', got '%s'. Script stopped."):format(EXPECTED_LOCAL_SCRIPT_NAME, script.Name))
	return
end

if not script:FindFirstChild(EXPECTED_CONFIG_MODULE_NAME) then
	warn(("[Crackline LoadingScreen] Config ModuleScript name must be '%s'. Script stopped."):format(EXPECTED_CONFIG_MODULE_NAME))
	return
end


local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Config = require(script:WaitForChild(EXPECTED_CONFIG_MODULE_NAME))

ReplicatedFirst:RemoveDefaultLoadingScreen()

local STYLE = Config.Style or {}
local WELCOME = Config.Welcome or {}
local SKIP = Config.Skip or {}
local SOUND = Config.SoundEffects or {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isRunning = true
local loadingFinished = false
local assetsReady = false

local screenGui
local root
local transitionFrame

local loadingGroup
local loadingScale
local loadingText
local percentText
local barFill

local playButton
local playScale
local playLine
local clickAnywhereButton

local skipButton
local skipScale
local skipLine
local skipRequested = false

local buttonClickSound
local buttonClickSoundId


local welcomeGroup
local welcomeScale
local welcomeLabel
local welcomeFullText = ""
local welcomeFadeItems = {}
local welcomeMoveItems = {}
local welcomeScaleItems = {}
local welcomeEffectRunning = false

local closeLoading

local function new(className, props, children)
	local object = Instance.new(className)

	for key, value in pairs(props or {}) do
		object[key] = value
	end

	for _, child in ipairs(children or {}) do
		child.Parent = object
	end

	return object
end

local function tween(object, time, props, style, direction)
	if not object then
		return nil
	end

	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)

	local newTween = TweenService:Create(object, info, props)
	newTween:Play()

	return newTween
end

local function normalizeSoundId(soundId)
	if typeof(soundId) == "number" then
		if soundId <= 0 then
			return nil
		end

		return "rbxassetid://" .. tostring(soundId)
	end

	if typeof(soundId) ~= "string" then
		return nil
	end

	soundId = soundId:gsub("%s+", "")

	if soundId == "" or soundId == "rbxassetid://" then
		return nil
	end

	local rbxAssetNumber = soundId:match("^rbxassetid://(%d+)$")
	local plainNumber = soundId:match("^%d+$")
	local numberId = rbxAssetNumber or plainNumber

	if numberId and tonumber(numberId) <= 0 then
		return nil
	end

	if plainNumber then
		return "rbxassetid://" .. soundId
	end

	return soundId
end

local function setupButtonClickSound()
	if SOUND.Enabled == false then
		return
	end

	local soundId = normalizeSoundId(SOUND.ButtonClickSoundId)
	if not soundId then
		return
	end

	if buttonClickSound and buttonClickSoundId == soundId then
		return
	end

	if buttonClickSound then
		buttonClickSound:Destroy()
		buttonClickSound = nil
	end

	buttonClickSoundId = soundId
	buttonClickSound = Instance.new("Sound")
	buttonClickSound.Name = "LoadingButtonClickSound"
	buttonClickSound.SoundId = soundId
	buttonClickSound.Volume = SOUND.Volume or 0.55
	buttonClickSound.PlaybackSpeed = SOUND.PlaybackSpeed or 1
	buttonClickSound.Looped = false
	buttonClickSound.Parent = SoundService

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ buttonClickSound })
		end)
	end)
end

local function playButtonClickSound()
	if SOUND.Enabled == false then
		return
	end

	local soundId = normalizeSoundId(SOUND.ButtonClickSoundId)
	if not soundId then
		return
	end

	if not buttonClickSound or buttonClickSoundId ~= soundId then
		setupButtonClickSound()
	end

	if not buttonClickSound then
		return
	end

	buttonClickSound.Volume = SOUND.Volume or 0.55
	buttonClickSound.PlaybackSpeed = SOUND.PlaybackSpeed or 1

	if buttonClickSound.IsPlaying then
		buttonClickSound:Stop()
	end

	pcall(function()
		buttonClickSound.TimePosition = 0
	end)

	buttonClickSound:Play()
end

setupButtonClickSound()

local function corner(parent, radius)
	return new("UICorner", {
		CornerRadius = radius or UDim.new(0, 8),
		Parent = parent
	})
end

local function stroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent
	})
end

local function easeInOutSine(alpha)
	return -(math.cos(math.pi * alpha) - 1) / 2
end

local function easeOutSine(alpha)
	return math.sin((alpha * math.pi) / 2)
end

local function lerpNumber(a, b, alpha)
	return a + (b - a) * alpha
end

local function safeCoreGui(enabled)
	if not Config.HideCoreGuiDuringLoading then
		return
	end

	task.spawn(function()
		for _ = 1, 10 do
			local success = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
				-- Backpack has a custom replacement (HotbarController), keep it off always
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)

			if success then
				break
			end

			task.wait(0.15)
		end
	end)
end

local function removeOldGui()
	local names = {
		"CracklineSimpleLoadingScreen"
	}

	for _, name in ipairs(names) do
		local oldGui = playerGui:FindFirstChild(name)

		if oldGui then
			oldGui:Destroy()
		end
	end
end

local function getUIScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local reference = Config.UIReferenceSize or Vector2.new(1280, 720)

	local baseScale = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	local smallestSide = math.min(viewport.X, viewport.Y)
	local deviceMultiplier = 1

	if UserInputService.TouchEnabled and smallestSide <= 800 then
		deviceMultiplier = Config.MobileUIScaleMultiplier or 0.78
	elseif UserInputService.TouchEnabled then
		deviceMultiplier = Config.TabletUIScaleMultiplier or 0.88
	end

	return math.clamp(
		baseScale * deviceMultiplier,
		Config.MinUIScale or 0.52,
		Config.MaxUIScale or 1
	)
end

local function applyScale()
	local scale = getUIScale()

	if loadingScale then
		loadingScale.Scale = scale
	end

	if playScale then
		playScale.Scale = scale
	end


	if skipScale then
		skipScale.Scale = scale
	end

	if welcomeScale then
		welcomeScale.Scale = scale
	end
end

local function startScaleWatcher()
	task.spawn(function()
		while isRunning do
			applyScale()
			task.wait(0.2)
		end
	end)
end

local function createBackground()
	root = new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = STYLE.BackgroundColor,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = screenGui
	})

	if Config.BackgroundImage ~= "" then
		local background = new("ImageLabel", {
			Name = "Background",
			Size = UDim2.fromScale(1.05, 1.05),
			Position = UDim2.fromScale(-0.025, -0.025),
			BackgroundTransparency = 1,
			Image = Config.BackgroundImage,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 1,
			Parent = root
		})

		tween(background, Config.BackgroundZoomTime or 10, {
			Size = UDim2.fromScale(1.02, 1.02),
			Position = UDim2.fromScale(-0.01, -0.01)
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	else
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, STYLE.GradientTop),
				ColorSequenceKeypoint.new(0.5, STYLE.GradientMiddle),
				ColorSequenceKeypoint.new(1, STYLE.GradientBottom)
			}),
			Rotation = 90,
			Parent = root
		})
	end

	new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = STYLE.OverlayTransparency,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root
	})

	local bottomFade = new("Frame", {
		Name = "BottomFade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, STYLE.BottomFadeHeight),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = root
	})

	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.35),
			NumberSequenceKeypoint.new(1, 0.08)
		}),
		Rotation = 90,
		Parent = bottomFade
	})

	transitionFrame = new("Frame", {
		Name = "TransitionFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = true,
		ZIndex = 999999,
		Parent = screenGui
	})
end

local function addWelcomeFadeItem(object, property, finalValue)
	if not object then
		return
	end

	object[property] = 1
	table.insert(welcomeFadeItems, {
		Object = object,
		Property = property,
		FinalValue = finalValue
	})
end

local function addWelcomeMoveItem(object, finalPosition, startOffsetY)
	if not object then
		return
	end

	object.Position = finalPosition + UDim2.fromOffset(0, startOffsetY or 0)
	table.insert(welcomeMoveItems, {
		Object = object,
		FinalPosition = finalPosition
	})
end

local function addWelcomeScaleItem(scaleObject, finalScale, startScale)
	if not scaleObject then
		return
	end

	scaleObject.Scale = startScale or 0.96
	table.insert(welcomeScaleItems, {
		Object = scaleObject,
		FinalScale = finalScale or 1
	})
end

local function splitGraphemes(text)
	local chars = {}

	local success = pcall(function()
		for firstIndex, lastIndex in utf8.graphemes(text) do
			table.insert(chars, string.sub(text, firstIndex, lastIndex))
		end
	end)

	if success and #chars > 0 then
		return chars
	end

	for index = 1, #text do
		table.insert(chars, string.sub(text, index, index))
	end

	return chars
end

local function playWelcomeTypewriter()
	if not welcomeLabel then
		return
	end

	if WELCOME.TypewriterEnabled == false then
		welcomeLabel.Text = welcomeFullText
		return
	end

	local chars = splitGraphemes(welcomeFullText)
	local typeTime = math.max(WELCOME.TypewriterTime or 1.25, 0.05)
	local startDelay = math.max(WELCOME.TypewriterStartDelay or 0.08, 0)
	local delayPerChar = typeTime / math.max(#chars, 1)

	welcomeLabel.Text = ""
	task.wait(startDelay)

	for index = 1, #chars do
		if not welcomeGroup or not welcomeLabel then
			return
		end

		welcomeLabel.Text = table.concat(chars, "", 1, index)
		task.wait(delayPerChar)
	end

	if welcomeLabel then
		welcomeLabel.Text = welcomeFullText
	end
end

local function createWelcomeUI()
	if WELCOME.Enabled == false then
		return
	end

	welcomeLabel = nil
	welcomeFullText = ""
	welcomeFadeItems = {}
	welcomeMoveItems = {}
	welcomeScaleItems = {}
	welcomeEffectRunning = false

	welcomeGroup = new("Frame", {
		Name = "WelcomeScene",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.91),
		Size = UDim2.fromOffset(620, 125),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 150,
		Parent = root
	})

	welcomeScale = new("UIScale", {
		Scale = getUIScale(),
		Parent = welcomeGroup
	})

	local displayName = player.DisplayName
	if not displayName or displayName == "" then
		displayName = player.Name
	end

	local welcomeText = tostring(WELCOME.TextTemplate or WELCOME.Text or "Welcome, DisplayName to Crackline Studio")
	local displayNameTokens = {
		"{DisplayName}",
		"{displayname}",
		"{DISPLAYNAME}",
		"{Display Name}",
		"{display name}",
		"{DISPLAY NAME}",
		"DisplayName",
		"displayname",
		"DISPLAYNAME",
		"Display Name",
		"Display name",
		"display name",
		"DISPLAY NAME",
	}

	for _, token in ipairs(displayNameTokens) do
		welcomeText = string.gsub(welcomeText, token, displayName)
	end

	welcomeFullText = welcomeText

	local welcomeTextPosition = UDim2.fromScale(0.5, 0.64)
	local welcomeInitialText = ""

	if WELCOME.TypewriterEnabled == false then
		welcomeInitialText = welcomeFullText
	end

	welcomeLabel = new("TextLabel", {
		Name = "WelcomeText",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = welcomeTextPosition,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = welcomeInitialText,
		TextColor3 = STYLE.TextColor,
		TextSize = WELCOME.TextSize or STYLE.LoadingTextSize,
		Font = WELCOME.TextFont or Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeColor3 = WELCOME.TextStrokeColor or Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 1,
		TextTransparency = 1,
		ZIndex = 151,
		Parent = welcomeGroup
	})

	local welcomeTextScale = new("UIScale", {
		Scale = WELCOME.TextStartScale or 1,
		Parent = welcomeLabel
	})

	addWelcomeFadeItem(welcomeLabel, "TextTransparency", WELCOME.TextTransparency or 0)
	addWelcomeFadeItem(welcomeLabel, "TextStrokeTransparency", WELCOME.TextStrokeTransparency or STYLE.LoadingTextStrokeTransparency or 0.76)
	addWelcomeMoveItem(welcomeLabel, welcomeTextPosition, WELCOME.TextStartOffsetY or 0)
	addWelcomeScaleItem(welcomeTextScale, 1, WELCOME.TextStartScale or 1)
end

local function runWelcomeScene()
	if WELCOME.Enabled == false or not welcomeGroup then
		if loadingGroup then
			loadingGroup.Visible = true
		end

		return
	end

	if loadingGroup then
		loadingGroup.Visible = false
	end

	welcomeGroup.Visible = true
	applyScale()

	local fallbackDuration = (WELCOME.FadeInTime or 0.45) + (WELCOME.HoldTime or 1.25) + (WELCOME.FadeOutTime or 0.75)
	local totalDuration = math.max(WELCOME.Duration or fallbackDuration, 0.2)
	local fadeInTime = math.min(WELCOME.FadeInTime or 0.45, totalDuration)
	local fadeOutTime = math.min(WELCOME.FadeOutTime or 0.75, math.max(totalDuration - fadeInTime, 0.05))
	local visibleBeforeFadeOut = math.max(totalDuration - fadeOutTime, fadeInTime)
	local fadeOutOffsetY = WELCOME.FadeOutOffsetY or 0

	for _, item in ipairs(welcomeFadeItems) do
		tween(item.Object, fadeInTime, {
			[item.Property] = item.FinalValue
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end

	for _, item in ipairs(welcomeMoveItems) do
		tween(item.Object, fadeInTime, {
			Position = item.FinalPosition
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end

	for _, item in ipairs(welcomeScaleItems) do
		tween(item.Object, fadeInTime, {
			Scale = item.FinalScale
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end

	task.spawn(playWelcomeTypewriter)
	task.wait(visibleBeforeFadeOut)

	for _, item in ipairs(welcomeFadeItems) do
		tween(item.Object, fadeOutTime, {
			[item.Property] = 1
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end

	if welcomeLabel and fadeOutOffsetY ~= 0 then
		tween(welcomeLabel, fadeOutTime, {
			Position = welcomeLabel.Position + UDim2.fromOffset(0, fadeOutOffsetY)
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end

	task.wait(fadeOutTime)

	welcomeEffectRunning = false

	if welcomeGroup then
		welcomeGroup:Destroy()
		welcomeGroup = nil
	end

	if loadingGroup then
		loadingGroup.Visible = true
	end
end

local function createLoadingUI()
	loadingGroup = new("Frame", {
		Name = "LoadingGroup",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.91),
		Size = UDim2.fromOffset(620, 125),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Parent = root
	})

	loadingScale = new("UIScale", {
		Scale = getUIScale(),
		Parent = loadingGroup
	})

	loadingText = new("TextLabel", {
		Name = "LoadingText",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = Config.LoadingTexts[1] or "Loading",
		TextColor3 = STYLE.TextColor,
		TextSize = STYLE.LoadingTextSize,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = STYLE.LoadingTextStrokeTransparency,
		ZIndex = 101,
		Parent = loadingGroup
	})

	percentText = new("TextLabel", {
		Name = "PercentText",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "0.00%",
		TextColor3 = STYLE.TextColor,
		TextSize = STYLE.PercentTextSize,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = STYLE.PercentTextStrokeTransparency,
		ZIndex = 101,
		Parent = loadingGroup
	})

	local barHolder = new("Frame", {
		Name = "BarHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(STYLE.BarWidth + 36, 32),
		BackgroundTransparency = 1,
		ZIndex = 101,
		Parent = loadingGroup
	})

	local barBack = new("Frame", {
		Name = "BarBack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STYLE.BarWidth, STYLE.BarHeight),
		BackgroundColor3 = STYLE.TextColor,
		BackgroundTransparency = STYLE.BarBackgroundTransparency,
		BorderSizePixel = 0,
		ZIndex = 101,
		Parent = barHolder
	})

	corner(barBack, UDim.new(1, 0))
	stroke(barBack, STYLE.TextColor, STYLE.BarStrokeTransparency, 1)

	barFill = new("Frame", {
		Name = "BarFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = STYLE.TextColor,
		BackgroundTransparency = STYLE.BarFillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 102,
		Parent = barBack
	})

	corner(barFill, UDim.new(1, 0))

	local shine = new("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(0.22, 1),
		Position = UDim2.fromScale(-0.25, 0),
		BackgroundColor3 = STYLE.TextColor,
		BackgroundTransparency = STYLE.BarShineTransparency,
		BorderSizePixel = 0,
		ZIndex = 103,
		Parent = barFill
	})

	corner(shine, UDim.new(1, 0))

	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(1, 1)
		}),
		Rotation = 0,
		Parent = shine
	})

	task.spawn(function()
		while isRunning and shine.Parent do
			shine.Position = UDim2.fromScale(-0.25, 0)

			tween(shine, 1.25, {
				Position = UDim2.fromScale(1.05, 0)
			}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

			task.wait(1.6)
		end
	end)

	for _, data in ipairs({
		{ "LeftCap", 0 },
		{ "RightCap", 1 }
		}) do
		local cap = new("Frame", {
			Name = data[1],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(data[2], 0.5),
			Size = UDim2.fromOffset(STYLE.BarCapSize, STYLE.BarCapSize),
			Rotation = 45,
			BackgroundColor3 = STYLE.TextColor,
			BackgroundTransparency = STYLE.BarCapTransparency,
			BorderSizePixel = 0,
			ZIndex = 103,
			Parent = barHolder
		})

		corner(cap, UDim.new(0, 2))
	end

end

local function setSkipVisible(visible)
	if not skipButton then
		return
	end

	if visible then
		skipButton.Visible = true
		skipButton.Active = true
		skipButton.TextTransparency = 1

		if skipLine then
			skipLine.BackgroundTransparency = 1
			skipLine.Size = UDim2.fromOffset(0, SKIP.LineHeight or 2)
		end

		tween(skipButton, SKIP.FadeTime or 0.25, {
			TextTransparency = SKIP.TextTransparency or 0.28
		})

		if skipLine then
			tween(skipLine, SKIP.FadeTime or 0.25, {
				Size = UDim2.fromOffset(SKIP.LineWidth or 58, SKIP.LineHeight or 2),
				BackgroundTransparency = SKIP.LineTransparency or 0.62
			})
		end
	else
		skipButton.Active = false

		tween(skipButton, SKIP.FadeTime or 0.2, {
			TextTransparency = 1
		})

		if skipLine then
			tween(skipLine, SKIP.FadeTime or 0.2, {
				Size = UDim2.fromOffset(0, SKIP.LineHeight or 2),
				BackgroundTransparency = 1
			})
		end

		task.delay(SKIP.FadeTime or 0.2, function()
			if skipButton and not skipButton.Active then
				skipButton.Visible = false
			end
		end)
	end
end

local function createSkipButton()
	if SKIP.Enabled == false then
		return
	end

	skipButton = new("TextButton", {
		Name = "SkipButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -(SKIP.RightPadding or 28), 1, -(SKIP.BottomPadding or 22)),
		Size = UDim2.fromOffset(SKIP.Width or 180, SKIP.Height or 32),
		BackgroundTransparency = 1,
		Text = SKIP.Text or "SKIP",
		TextColor3 = STYLE.TextColor,
		TextSize = SKIP.TextSize or 22,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
		AutoButtonColor = false,
		Active = false,
		Visible = false,
		ZIndex = 101,
		Parent = root
	})

	skipScale = new("UIScale", {
		Scale = getUIScale(),
		Parent = skipButton
	})

	skipLine = new("Frame", {
		Name = "SkipLine",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0.83),
		Size = UDim2.fromOffset(0, SKIP.LineHeight or 2),
		BackgroundColor3 = STYLE.TextColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = skipButton
	})

	corner(skipLine, UDim.new(1, 0))

	skipButton.MouseEnter:Connect(function()
		if not skipButton.Active then
			return
		end

		tween(skipButton, 0.16, {
			TextTransparency = SKIP.HoverTextTransparency or 0
		})

		if skipLine then
			tween(skipLine, 0.16, {
				BackgroundTransparency = SKIP.HoverLineTransparency or 0.05,
				Size = UDim2.fromOffset((SKIP.LineWidth or 58) + 10, SKIP.LineHeight or 2)
			})
		end
	end)

	skipButton.MouseLeave:Connect(function()
		if not skipButton.Active then
			return
		end

		tween(skipButton, 0.16, {
			TextTransparency = SKIP.TextTransparency or 0.28
		})

		if skipLine then
			tween(skipLine, 0.16, {
				BackgroundTransparency = SKIP.LineTransparency or 0.62,
				Size = UDim2.fromOffset(SKIP.LineWidth or 58, SKIP.LineHeight or 2)
			})
		end
	end)

	skipButton.MouseButton1Click:Connect(function()
		if loadingFinished or skipRequested then
			return
		end

		skipRequested = true
		playButtonClickSound()
		skipButton.Text = "SKIPPING"
		setSkipVisible(false)
	end)
end

local function startSkipButtonTimer()
	if SKIP.Enabled == false or not skipButton then
		return
	end

	task.spawn(function()
		local loadingDuration = math.max(Config.LoadingDuration or 4, 0.1)
		local showAtSecond = SKIP.ShowAtSecond

		if showAtSecond == nil then
			showAtSecond = SKIP.ShowDelay or 0.75
		end

		showAtSecond = math.clamp(showAtSecond, 0, math.max(loadingDuration - 0.1, 0))
		task.wait(showAtSecond)

		if isRunning and not loadingFinished and not skipRequested then
			setSkipVisible(true)
		end
	end)
end

local function createPlayButton()
	clickAnywhereButton = new("TextButton", {
		Name = "ClickAnywhereButton",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Visible = false,
		ZIndex = 149,
		Parent = root
	})

	playButton = new("TextButton", {
		Name = "PlayButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.91),
		Size = UDim2.fromOffset(240, 78),
		BackgroundTransparency = 1,
		Text = Config.PlayText,
		TextColor3 = STYLE.TextColor,
		TextSize = STYLE.PlayTextSize,
		Font = Enum.Font.GothamBold,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = STYLE.PlayTextStrokeTransparency,
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 150,
		Parent = root
	})

	playScale = new("UIScale", {
		Scale = getUIScale(),
		Parent = playButton
	})

	playLine = new("Frame", {
		Name = "PlayLine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromOffset(0, 3),
		BackgroundColor3 = STYLE.TextColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 151,
		Parent = playButton
	})

	corner(playLine, UDim.new(1, 0))

	playButton.MouseEnter:Connect(function()
		tween(playButton, 0.18, {
			TextTransparency = 0,
			TextSize = STYLE.PlayTextSize + 2
		})

		tween(playLine, 0.18, {
			Size = UDim2.fromOffset(135, 3),
			BackgroundTransparency = STYLE.PlayLineHoverTransparency
		})
	end)

	playButton.MouseLeave:Connect(function()
		tween(playButton, 0.18, {
			TextTransparency = 0,
			TextSize = STYLE.PlayTextSize
		})

		tween(playLine, 0.18, {
			Size = UDim2.fromOffset(105, 3),
			BackgroundTransparency = STYLE.PlayLineDefaultTransparency
		})
	end)

	local clicked = false

	local function requestPlay()
		if clicked then
			return
		end

		clicked = true
		playButtonClickSound()

		if closeLoading then
			closeLoading()
		end
	end

	playButton.MouseButton1Click:Connect(requestPlay)
	clickAnywhereButton.MouseButton1Click:Connect(requestPlay)
end

local function setProgress(value)
	local progress = math.clamp(value, 0, 1)

	tween(barFill, 0.08, {
		Size = UDim2.fromScale(progress, 1)
	}, Enum.EasingStyle.Linear)

	percentText.Text = string.format("%.2f%%", progress * 100)

	local hideAtProgress = SKIP.HideAtProgress
	if hideAtProgress and skipButton and skipButton.Visible and skipButton.Active and progress >= hideAtProgress then
		setSkipVisible(false)
	end
end

local function startTextLoop()
	task.spawn(function()
		local index = 1

		while isRunning and not loadingFinished do
			task.wait(STYLE.TextChangeDelay)

			index += 1

			if index > #Config.LoadingTexts then
				index = 1
			end

			tween(loadingText, 0.2, {
				TextTransparency = 1
			})

			task.wait(0.2)

			if isRunning and not loadingFinished then
				loadingText.Text = Config.LoadingTexts[index]
			end

			tween(loadingText, 0.25, {
				TextTransparency = 0
			})
		end
	end)
end

local function isPreloadAsset(object)
	return object:IsA("Decal")
		or object:IsA("Texture")
		or object:IsA("ImageLabel")
		or object:IsA("ImageButton")
		or object:IsA("MeshPart")
		or object:IsA("SpecialMesh")
		or object:IsA("Sound")
		or object:IsA("Animation")
		or object:IsA("VideoFrame")
		or object:IsA("ParticleEmitter")
		or object:IsA("Beam")
		or object:IsA("Trail")
end

local function startPreload()
	task.spawn(function()
		local assets = {}
		local maxAssets = Config.MaxPreloadAssets or 300

		-- 1. Mengumpulkan semua aset di dalam game
		for _, container in ipairs({ workspace, ReplicatedStorage, SoundService }) do
			for _, object in ipairs(container:GetDescendants()) do
				if isPreloadAsset(object) then
					table.insert(assets, object)

					if #assets >= maxAssets then
						break
					end
				end
			end
			if #assets >= maxAssets then
				break
			end
		end

		local totalAssets = #assets
		local loadedAssets = 0

		-- 2. Memuat aset secara nyata dan memperbarui progress bar
		if totalAssets > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(assets, function()
					loadedAssets += 1
					local progress = loadedAssets / totalAssets
					setProgress(progress) -- Ini akan langsung menggerakkan bar dan mengubah % sesuai aset yang selesai!
				end)
			end)
		else
			setProgress(1)
		end

		if not game:IsLoaded() then
			game.Loaded:Wait()
		end

		assetsReady = true
	end)
end

local function runLoadingTimer()
	-- Kita tidak lagi menggunakan perhitungan waktu (os.clock). 
	-- Script hanya akan menunggu sampai semua aset selesai (assetsReady) atau tombol Skip ditekan.
	while isRunning and not loadingFinished and not skipRequested do
		if assetsReady then
			break
		end
		RunService.RenderStepped:Wait()
	end

	if skipRequested then
		return
	end

	setProgress(1)
end

local function getCharacterParts()
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", Config.CameraWaitTime or 4)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", Config.CameraWaitTime or 4)

	if not rootPart or not humanoid then
		return nil
	end

	return character, rootPart, humanoid
end

local function getCameraPreset()
	if not Config.EnableIntroCamera or Config.CameraMode == "None" then
		return nil, nil
	end

	local modeName = Config.CameraMode or "OrbitBehind"
	local presets = Config.CameraPresets or {}
	local preset = presets[modeName] or presets.OrbitBehind

	return modeName, preset
end

local function getFocus(rootPart, preset)
	local offset = preset.LookAtOffset or Config.CameraLookAtOffset or Vector3.new(0, 1.65, 0)
	return rootPart.Position + offset
end

local function getOffsetCFrame(rootPart, offset, preset)
	local cameraPosition = (rootPart.CFrame * CFrame.new(offset)).Position
	return CFrame.lookAt(cameraPosition, getFocus(rootPart, preset))
end

local function getOrbitCFrame(rootPart, angle, preset)
	local radius = preset.OrbitRadius or 20
	local height = preset.OrbitHeight or 6

	local radians = math.rad(angle)
	local position = rootPart.Position + Vector3.new(
		math.sin(radians) * radius,
		height,
		math.cos(radians) * radius
	)

	return CFrame.lookAt(position, getFocus(rootPart, preset))
end

local function getPathCFrame(rootPart, alpha, preset)
	local startCFrame = getOffsetCFrame(rootPart, preset.StartOffset, preset)
	local midCFrame = getOffsetCFrame(rootPart, preset.MidOffset or preset.EndOffset, preset)
	local endCFrame = getOffsetCFrame(rootPart, preset.EndOffset, preset)

	local first = startCFrame:Lerp(midCFrame, alpha)
	local second = midCFrame:Lerp(endCFrame, alpha)

	return first:Lerp(second, alpha)
end

local function getCameraDuration(modeName, preset)
	if not preset then
		return 0
	end

	if modeName == "OrbitBehind" then
		return (preset.OrbitTime or 4.6) + (preset.BehindTime or 2.2)
	end

	return preset.MoveTime or 5
end

local function runOrbitBehind(camera, rootPart, preset, isCancelled)
	local orbitTime = math.max(preset.OrbitTime or 4.6, 0.1)
	local behindTime = math.max(preset.BehindTime or 2.2, 0.1)

	local startAngle = preset.OrbitStartAngle or -150
	local endAngle = preset.OrbitEndAngle or 205

	camera.CFrame = getOrbitCFrame(rootPart, startAngle, preset)
	camera.FieldOfView = preset.FOVStart or 48

	local orbitStart = os.clock()

	while not isCancelled() and rootPart.Parent do
		local alpha = math.clamp((os.clock() - orbitStart) / orbitTime, 0, 1)
		local eased = easeInOutSine(alpha)
		local angle = lerpNumber(startAngle, endAngle, eased)

		camera.CFrame = getOrbitCFrame(rootPart, angle, preset)
		camera.FieldOfView = preset.FOVStart or 48

		if alpha >= 1 then
			break
		end

		RunService.RenderStepped:Wait()
	end

	local fromCFrame = camera.CFrame
	local behindStart = os.clock()

	while not isCancelled() and rootPart.Parent do
		local alpha = math.clamp((os.clock() - behindStart) / behindTime, 0, 1)
		local eased = easeOutSine(alpha)

		camera.CFrame = fromCFrame:Lerp(getOffsetCFrame(rootPart, preset.EndOffset, preset), eased)
		camera.FieldOfView = lerpNumber(preset.FOVStart or 48, preset.FOVEnd or 70, eased)

		if alpha >= 1 then
			break
		end

		RunService.RenderStepped:Wait()
	end
end

local function runNamedCamera(modeName, camera, rootPart, preset, isCancelled)
	if modeName == "OrbitBehind" then
		runOrbitBehind(camera, rootPart, preset, isCancelled)
		return
	end

	local moveTime = math.max(preset.MoveTime or 5, 0.1)

	camera.CFrame = getPathCFrame(rootPart, 0, preset)
	camera.FieldOfView = preset.FOVStart or 48

	local moveStart = os.clock()

	while not isCancelled() and rootPart.Parent do
		local alpha = math.clamp((os.clock() - moveStart) / moveTime, 0, 1)
		local eased = easeInOutSine(alpha)

		camera.CFrame = getPathCFrame(rootPart, eased, preset)
		camera.FieldOfView = lerpNumber(preset.FOVStart or 48, preset.FOVEnd or 70, eased)

		if alpha >= 1 then
			break
		end

		RunService.RenderStepped:Wait()
	end
end

local function playIntroCamera()
	local modeName, preset = getCameraPreset()

	if not preset then
		return nil
	end

	local camera = Workspace.CurrentCamera
	local _, rootPart, humanoid = getCharacterParts()

	if not camera or not rootPart or not humanoid then
		return nil
	end

	local oldMinZoom = player.CameraMinZoomDistance
	local oldMaxZoom = player.CameraMaxZoomDistance
	local oldFOV = camera.FieldOfView

	local cancelled = false
	local duration = getCameraDuration(modeName, preset)

	if Config.LockCameraZoomAfterIntro then
		local zoomDistance = preset.RestoreZoomDistance or 10

		pcall(function()
			player.CameraMinZoomDistance = zoomDistance
			player.CameraMaxZoomDistance = zoomDistance
		end)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil

	task.spawn(function()
		runNamedCamera(modeName, camera, rootPart, preset, function()
			return cancelled
		end)

		if rootPart.Parent and not cancelled then
			camera.CFrame = getOffsetCFrame(rootPart, preset.EndOffset, preset)
			camera.FieldOfView = preset.FOVEnd or 70
		end
	end)

	local function restore()
		cancelled = true

		local finalCFrame = camera.CFrame
		local finalFOV = preset.FOVEnd or oldFOV

		if rootPart.Parent then
			finalCFrame = getOffsetCFrame(rootPart, preset.EndOffset, preset)
			camera.CFrame = finalCFrame
		end

		camera.FieldOfView = finalFOV
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom

		if Config.SmoothCameraHandoff then
			local bindName = "CracklineLoadingSmoothHandoff_" .. tostring(player.UserId)
			local handoffTime = math.max(Config.SmoothCameraHandoffTime or 0.8, 0.05)
			local elapsed = 0
			local finished = false

			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)

			RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
				if finished then
					return
				end

				elapsed += deltaTime

				local alpha = math.clamp(elapsed / handoffTime, 0, 1)
				local eased = easeInOutSine(alpha)

				local targetCFrame = camera.CFrame
				local targetFOV = camera.FieldOfView

				camera.CFrame = finalCFrame:Lerp(targetCFrame, eased)
				camera.FieldOfView = lerpNumber(finalFOV, targetFOV, eased)

				if alpha >= 1 then
					finished = true

					pcall(function()
						RunService:UnbindFromRenderStep(bindName)
					end)
				end
			end)

			while not finished do
				RunService.RenderStepped:Wait()
			end
		end

		if Config.LockCameraZoomAfterIntro and Config.RestoreZoomLimitsAfterIntro then
			task.delay(Config.CameraZoomRestoreDelay or 1.2, function()
				pcall(function()
					player.CameraMinZoomDistance = oldMinZoom
					player.CameraMaxZoomDistance = oldMaxZoom
					camera.FieldOfView = oldFOV
				end)
			end)
		end
	end

	return {
		Duration = duration,
		Restore = restore
	}
end

local function checkIsReturning()
	local TeleportService = game:GetService("TeleportService")
	local teleportData = nil
	pcall(function()
		teleportData = TeleportService:GetLocalPlayerTeleportData()
	end)
	if teleportData and type(teleportData) == "table" and (teleportData.returningFromStage or teleportData.mode) then
		return true
	end
	if Players.LocalPlayer:GetAttribute("ReturningFromStage") == true then
		return true
	end
	return false
end

local function fadeLoadingToPlay()
	loadingFinished = true
	loadingText.Text = Config.LoadCompleteText
	percentText.Text = "100.00%"

	task.wait(0.28)

	for _, object in ipairs(loadingGroup:GetDescendants()) do
		if object:IsA("TextLabel") then
			tween(object, STYLE.LoadingFadeTime, {
				TextTransparency = 1
			})
		elseif object:IsA("Frame") then
			tween(object, STYLE.LoadingFadeTime, {
				BackgroundTransparency = 1
			})
		elseif object:IsA("UIStroke") then
			tween(object, STYLE.LoadingFadeTime, {
				Transparency = 1
			})
		end
	end

	task.wait(STYLE.LoadingFadeTime)

	loadingGroup.Visible = false
	setSkipVisible(false)

	if Config.ShowPlayButtonAfterLoading and not checkIsReturning() then
		playButton.Visible = true

		if clickAnywhereButton then
			clickAnywhereButton.Visible = Config.ClickAnywhereToPlay == true
			clickAnywhereButton.Active = Config.ClickAnywhereToPlay == true
		end

		applyScale()

		tween(playButton, STYLE.PlayFadeTime, {
			TextTransparency = 0
		})

		tween(playLine, STYLE.PlayFadeTime, {
			Size = UDim2.fromOffset(105, 3),
			BackgroundTransparency = STYLE.PlayLineDefaultTransparency
		})
	else
		closeLoading()
	end
end

local function fadeTransitionTo(transparency, duration)
	transitionFrame.Visible = true

	tween(transitionFrame, duration, {
		BackgroundTransparency = transparency
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	task.wait(duration)
end

closeLoading = function()
	if not isRunning then
		return
	end

	isRunning = false
	loadingFinished = true

	playButton.Active = false
	playButton.AutoButtonColor = false
	playButton.Selectable = false

	if clickAnywhereButton then
		clickAnywhereButton.Active = false
		clickAnywhereButton.Visible = false
	end

	setSkipVisible(false)

	tween(playButton, 0.06, {
		TextTransparency = 1
	})

	tween(playLine, 0.06, {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 3)
	})

	transitionFrame.BackgroundTransparency = 0
	transitionFrame.Visible = true

	task.wait(Config.PlayTransitionHoldTime or 0.08)

	if root then
		root.Visible = false
	end

	local introData = not checkIsReturning() and playIntroCamera() or nil
	safeCoreGui(true)

	local openingFadeTime = Config.PlayTransitionFadeOutTime or 1.05
	fadeTransitionTo(1, openingFadeTime)
	transitionFrame.Visible = false

	if introData then
		local waitTime = math.max((introData.Duration or 0) - openingFadeTime, 0)

		if waitTime > 0 then
			task.wait(waitTime)
		end

		if Config.HideCameraHandoffWithFade then
			transitionFrame.BackgroundTransparency = 1
			transitionFrame.Visible = true

			fadeTransitionTo(0, Config.HandoffFadeInTime or 0.12)
			task.wait(Config.HandoffHoldTime or 0.05)

			introData.Restore()

			fadeTransitionTo(1, Config.HandoffFadeOutTime or 0.35)
			transitionFrame.Visible = false
		else
			introData.Restore()
		end
	end

	if screenGui then
		screenGui:Destroy()
	end
end

local function initialize()
	removeOldGui()
	safeCoreGui(false)

	screenGui = new("ScreenGui", {
		Name = "CracklineSimpleLoadingScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		Parent = playerGui
	})

	createBackground()
	createWelcomeUI()
	createLoadingUI()
	createSkipButton()
	createPlayButton()
	applyScale()
	startScaleWatcher()
	runWelcomeScene()
	startSkipButtonTimer()
	startTextLoop()

	startPreload()
	runLoadingTimer()

	if skipRequested then
		closeLoading()
		return
	end

	if not isRunning then
		return
	end

	fadeLoadingToPlay()
	
	
end

initialize()