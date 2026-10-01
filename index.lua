local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

-- Confirms the queued script actually started executing on the new
-- server at all, before anything else has a chance to error out.
print("[Sell Lemons] Script starting (post-hop or fresh run)...")

-- FIX: at ~1 minute hop intervals, the queued script frequently ran
-- WHILE the new server was still loading (character not spawned,
-- workspace/tycoons not replicated yet, etc). Any error thrown
-- during that window used to kill the whole script permanently and
-- silently - which is exactly "fails to auto execute" with no clue
-- why. Everything below is now wrapped in main() and retried with
-- pcall instead of being allowed to die on the first bad attempt.

if not game:IsLoaded() then
	print("[Sell Lemons] Waiting for game:IsLoaded()...")
	game.Loaded:Wait()
end

local function main()

	-- FIX: queued scripts often run very early during the new server's
	-- load - sometimes before Players.LocalPlayer even exists yet. If
	-- LocalPlayer is nil here, the next line (player:WaitForChild) would
	-- throw immediately and silently kill the whole script with nothing
	-- visibly printed, which looks exactly like "no script ran".
	local player = Players.LocalPlayer

	if not player then
		print("[Sell Lemons] LocalPlayer not ready yet, waiting...")
		player = Players.PlayerAdded:Wait()
		print("[Sell Lemons] LocalPlayer acquired:", player.Name)
	end

	-- The character/HumanoidRootPart isn't guaranteed to exist yet
	-- either, and several things below (dragging math aside) assume
	-- the player is basically settled in. Give it a moment and a
	-- real wait rather than guessing with task.wait(n).
	if not player.Character then
		print("[Sell Lemons] Waiting for character to load...")
		player.CharacterAdded:Wait()
		task.wait(0.5)
	end

--==================================================
-- SETTINGS
--==================================================

local TREE_SCAN_DELAY = 1
local TREE_STOP_TIME = 0.025
local CLICK_DELAY = 0.005

-- Enabled by default
local enabled = true
local antiAFKEnabled = true

-- 1 minute
local SERVER_HOP_INTERVAL = 60

-- Replace with the raw link to wherever you host THIS file
-- (e.g. a GitHub raw URL, same as your OpenESP example). This must
-- be the exact loadstring(game:HttpGet(...)) target.
local HOSTED_URL = "https://raw.githubusercontent.com/<you>/<repo>/<branch>/index.lua"



--==================================================
-- COLORS
--==================================================

local BLACK = Color3.fromRGB(12, 12, 12)
local SIDEBAR_BLACK = Color3.fromRGB(9, 9, 9)
local CARD_BLACK = Color3.fromRGB(22, 22, 22)

local WHITE = Color3.fromRGB(245, 245, 245)
local GREY_TEXT = Color3.fromRGB(115, 115, 115)

local TOGGLE_OFF = Color3.fromRGB(78, 78, 78)

--==================================================
-- ACCENTS
--==================================================

local ACCENTS = {
	Purple = Color3.fromRGB(168, 85, 247),
	Green = Color3.fromRGB(45, 205, 95),
	Blue = Color3.fromRGB(65, 145, 255),
	Red = Color3.fromRGB(240, 70, 70),
	Orange = Color3.fromRGB(255, 145, 45),
	Pink = Color3.fromRGB(255, 90, 170)
}

local currentAccent = "Green"
local TOGGLE_ON = ACCENTS[currentAccent]

--==================================================
-- GUI
--==================================================

local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("SellLemonsGUI")

if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "SellLemonsGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(560, 350)
main.Position = UDim2.new(0.5, -280, 0.5, -175)
main.BackgroundColor3 = BLACK
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

--==================================================
-- SIDEBAR
--==================================================

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.fromOffset(150, 350)
sidebar.BackgroundColor3 = SIDEBAR_BLACK
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 14)
sidebarCorner.Parent = sidebar

local sidebarFill = Instance.new("Frame")
sidebarFill.Position = UDim2.new(1, -14, 0, 0)
sidebarFill.Size = UDim2.new(0, 14, 1, 0)
sidebarFill.BackgroundColor3 = SIDEBAR_BLACK
sidebarFill.BorderSizePixel = 0
sidebarFill.Parent = sidebar

--==================================================
-- TITLE
--==================================================

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(20, 22)
title.Size = UDim2.new(1, -30, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Sell Lemons 🍋"
title.TextColor3 = WHITE
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = sidebar

--==================================================
-- TABS
--==================================================

local function makeTab(text, y)
	local button = Instance.new("TextButton")

	button.Position = UDim2.fromOffset(12, y)
	button.Size = UDim2.new(1, -24, 0, 40)

	button.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
	button.BackgroundTransparency = 1

	button.BorderSizePixel = 0

	button.Text = text
	button.TextColor3 = Color3.fromRGB(150, 150, 150)
	button.TextSize = 12
	button.Font = Enum.Font.GothamMedium

	button.TextXAlignment = Enum.TextXAlignment.Left
	button.AutoButtonColor = false

	button.Parent = sidebar

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	return button
end

local mainTab = makeTab("Main", 75)
local settingsTab = makeTab("Settings", 120)

mainTab.BackgroundTransparency = 0
mainTab.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
mainTab.TextColor3 = WHITE

--==================================================
-- CONTENT
--==================================================

local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(150, 0)
content.Size = UDim2.new(1, -150, 1, 0)
content.BackgroundTransparency = 1
content.Parent = main

--==================================================
-- MAIN PAGE
--==================================================

local mainPage = Instance.new("Frame")
mainPage.Size = UDim2.fromScale(1, 1)
mainPage.BackgroundTransparency = 1
mainPage.Parent = content

local pageTitle = Instance.new("TextLabel")
pageTitle.Position = UDim2.fromOffset(28, 25)
pageTitle.Size = UDim2.new(1, -56, 0, 30)
pageTitle.BackgroundTransparency = 1
pageTitle.Text = "Main"
pageTitle.TextColor3 = WHITE
pageTitle.TextSize = 22
pageTitle.Font = Enum.Font.GothamBold
pageTitle.TextXAlignment = Enum.TextXAlignment.Left
pageTitle.Parent = mainPage

local pageDescription = Instance.new("TextLabel")
pageDescription.Position = UDim2.fromOffset(28, 56)
pageDescription.Size = UDim2.new(1, -56, 0, 20)
pageDescription.BackgroundTransparency = 1
pageDescription.Text = "Automatically collect lemons from every tree."
pageDescription.TextColor3 = GREY_TEXT
pageDescription.TextSize = 11
pageDescription.Font = Enum.Font.Gotham
pageDescription.TextXAlignment = Enum.TextXAlignment.Left
pageDescription.Parent = mainPage

--==================================================
-- AUTO PICK CARD
--==================================================

local toggleCard = Instance.new("Frame")
toggleCard.Position = UDim2.fromOffset(22, 100)
toggleCard.Size = UDim2.new(1, -44, 0, 82)
toggleCard.BackgroundColor3 = CARD_BLACK
toggleCard.BorderSizePixel = 0
toggleCard.Parent = mainPage

local toggleCardCorner = Instance.new("UICorner")
toggleCardCorner.CornerRadius = UDim.new(0, 12)
toggleCardCorner.Parent = toggleCard

local toggleTitle = Instance.new("TextLabel")
toggleTitle.Position = UDim2.fromOffset(18, 14)
toggleTitle.Size = UDim2.new(1, -100, 0, 25)
toggleTitle.BackgroundTransparency = 1
toggleTitle.Text = "Auto Pick Fruits"
toggleTitle.TextColor3 = WHITE
toggleTitle.TextSize = 14
toggleTitle.Font = Enum.Font.GothamMedium
toggleTitle.TextXAlignment = Enum.TextXAlignment.Left
toggleTitle.Parent = toggleCard

local toggleDesc = Instance.new("TextLabel")
toggleDesc.Position = UDim2.fromOffset(18, 40)
toggleDesc.Size = UDim2.new(1, -100, 0, 20)
toggleDesc.BackgroundTransparency = 1
toggleDesc.Text = "Automatically pick every lemon from each tree."
toggleDesc.TextColor3 = GREY_TEXT
toggleDesc.TextSize = 10
toggleDesc.Font = Enum.Font.Gotham
toggleDesc.TextXAlignment = Enum.TextXAlignment.Left
toggleDesc.Parent = toggleCard

--==================================================
-- AUTO PICK TOGGLE
--==================================================

local toggle = Instance.new("TextButton")
toggle.Position = UDim2.new(1, -70, 0.5, -15)
toggle.Size = UDim2.fromOffset(52, 30)
toggle.BackgroundColor3 = TOGGLE_OFF
toggle.BorderSizePixel = 0
toggle.Text = ""
toggle.AutoButtonColor = false
toggle.Parent = toggleCard

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = toggle

local knob = Instance.new("Frame")
knob.Position = UDim2.fromOffset(3, 3)
knob.Size = UDim2.fromOffset(24, 24)
knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
knob.BorderSizePixel = 0
knob.Parent = toggle

local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1, 0)
knobCorner.Parent = knob

--==================================================
-- STATUS
--==================================================

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(28, 198)
status.Size = UDim2.new(1, -56, 0, 25)
status.BackgroundTransparency = 1
status.Text = "●  Disabled"
status.TextColor3 = GREY_TEXT
status.TextSize = 11
status.Font = Enum.Font.GothamMedium
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = mainPage

--==================================================
-- ANTI-AFK CARD
--==================================================

local antiAFKCard = Instance.new("Frame")
antiAFKCard.Name = "AntiAFKCard"
antiAFKCard.Position = UDim2.fromOffset(22, 235)
antiAFKCard.Size = UDim2.new(1, -44, 0, 82)
antiAFKCard.BackgroundColor3 = CARD_BLACK
antiAFKCard.BorderSizePixel = 0
antiAFKCard.ZIndex = 5
antiAFKCard.Parent = mainPage

local antiAFKCardCorner = Instance.new("UICorner")
antiAFKCardCorner.CornerRadius = UDim.new(0, 12)
antiAFKCardCorner.Parent = antiAFKCard

local antiAFKTitle = Instance.new("TextLabel")
antiAFKTitle.Position = UDim2.fromOffset(18, 14)
antiAFKTitle.Size = UDim2.new(1, -100, 0, 25)
antiAFKTitle.BackgroundTransparency = 1
antiAFKTitle.Text = "Anti-AFK"
antiAFKTitle.TextColor3 = WHITE
antiAFKTitle.TextSize = 14
antiAFKTitle.Font = Enum.Font.GothamMedium
antiAFKTitle.TextXAlignment = Enum.TextXAlignment.Left
antiAFKTitle.ZIndex = 6
antiAFKTitle.Parent = antiAFKCard

local antiAFKDesc = Instance.new("TextLabel")
antiAFKDesc.Position = UDim2.fromOffset(18, 40)
antiAFKDesc.Size = UDim2.new(1, -100, 0, 20)
antiAFKDesc.BackgroundTransparency = 1
antiAFKDesc.Text = "Prevents the game from kicking you for idling."
antiAFKDesc.TextColor3 = GREY_TEXT
antiAFKDesc.TextSize = 10
antiAFKDesc.Font = Enum.Font.Gotham
antiAFKDesc.TextXAlignment = Enum.TextXAlignment.Left
antiAFKDesc.ZIndex = 6
antiAFKDesc.Parent = antiAFKCard

--==================================================
-- ANTI-AFK TOGGLE
--==================================================

local antiAFKToggle = Instance.new("TextButton")
antiAFKToggle.Name = "AntiAFKToggle"
antiAFKToggle.Position = UDim2.new(1, -70, 0.5, -15)
antiAFKToggle.Size = UDim2.fromOffset(52, 30)
antiAFKToggle.BackgroundColor3 = TOGGLE_OFF
antiAFKToggle.BorderSizePixel = 0
antiAFKToggle.Text = ""
antiAFKToggle.AutoButtonColor = false
antiAFKToggle.ZIndex = 10
antiAFKToggle.Active = true
antiAFKToggle.Parent = antiAFKCard

local antiAFKToggleCorner = Instance.new("UICorner")
antiAFKToggleCorner.CornerRadius = UDim.new(1, 0)
antiAFKToggleCorner.Parent = antiAFKToggle

local antiAFKKnob = Instance.new("Frame")
antiAFKKnob.Name = "Knob"
antiAFKKnob.Position = UDim2.fromOffset(3, 3)
antiAFKKnob.Size = UDim2.fromOffset(24, 24)
antiAFKKnob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
antiAFKKnob.BorderSizePixel = 0
antiAFKKnob.ZIndex = 11
antiAFKKnob.Parent = antiAFKToggle

local antiAFKKnobCorner = Instance.new("UICorner")
antiAFKKnobCorner.CornerRadius = UDim.new(1, 0)
antiAFKKnobCorner.Parent = antiAFKKnob

--==================================================
-- ANTI-AFK UPDATE
--==================================================

local function updateAntiAFK()
	if antiAFKEnabled then

		TweenService:Create(
			antiAFKToggle,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				BackgroundColor3 = TOGGLE_ON
			}
		):Play()

		TweenService:Create(
			antiAFKKnob,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(25, 3)
			}
		):Play()

	else

		TweenService:Create(
			antiAFKToggle,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				BackgroundColor3 = TOGGLE_OFF
			}
		):Play()

		TweenService:Create(
			antiAFKKnob,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(3, 3)
			}
		):Play()
	end
end

antiAFKToggle.MouseButton1Click:Connect(function()
	antiAFKEnabled = not antiAFKEnabled
	updateAntiAFK()

	print(
		"[Sell Lemons] Anti-AFK:",
		antiAFKEnabled and "ON" or "OFF"
	)
end)

--==================================================
-- ANTI-AFK
--==================================================

player.Idled:Connect(function()
	if not antiAFKEnabled then
		return
	end

	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)

	print("[Sell Lemons] Anti-AFK activity sent")
end)

--==================================================
-- SETTINGS PAGE
--==================================================

local settingsPage = Instance.new("Frame")
settingsPage.Size = UDim2.fromScale(1, 1)
settingsPage.BackgroundTransparency = 1
settingsPage.Visible = false
settingsPage.Parent = content

local settingsTitle = Instance.new("TextLabel")
settingsTitle.Position = UDim2.fromOffset(28, 25)
settingsTitle.Size = UDim2.new(1, -56, 0, 30)
settingsTitle.BackgroundTransparency = 1
settingsTitle.Text = "Settings"
settingsTitle.TextColor3 = WHITE
settingsTitle.TextSize = 22
settingsTitle.Font = Enum.Font.GothamBold
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.Parent = settingsPage

local settingsDesc = Instance.new("TextLabel")
settingsDesc.Position = UDim2.fromOffset(28, 56)
settingsDesc.Size = UDim2.new(1, -56, 0, 20)
settingsDesc.BackgroundTransparency = 1
settingsDesc.Text = "Customize your collection settings."
settingsDesc.TextColor3 = GREY_TEXT
settingsDesc.TextSize = 11
settingsDesc.Font = Enum.Font.Gotham
settingsDesc.TextXAlignment = Enum.TextXAlignment.Left
settingsDesc.Parent = settingsPage

--==================================================
-- ACCENT CARD
--==================================================

local settingsCard = Instance.new("Frame")
settingsCard.Position = UDim2.fromOffset(22, 100)
settingsCard.Size = UDim2.new(1, -44, 0, 175)
settingsCard.BackgroundColor3 = CARD_BLACK
settingsCard.BorderSizePixel = 0
settingsCard.Parent = settingsPage

local settingsCardCorner = Instance.new("UICorner")
settingsCardCorner.CornerRadius = UDim.new(0, 12)
settingsCardCorner.Parent = settingsCard

local settingsLabel = Instance.new("TextLabel")
settingsLabel.Position = UDim2.fromOffset(18, 13)
settingsLabel.Size = UDim2.new(1, -36, 0, 25)
settingsLabel.BackgroundTransparency = 1
settingsLabel.Text = "Accent Color"
settingsLabel.TextColor3 = WHITE
settingsLabel.TextSize = 14
settingsLabel.Font = Enum.Font.GothamMedium
settingsLabel.TextXAlignment = Enum.TextXAlignment.Left
settingsLabel.Parent = settingsCard

local settingsInfo = Instance.new("TextLabel")
settingsInfo.Position = UDim2.fromOffset(18, 38)
settingsInfo.Size = UDim2.new(1, -36, 0, 18)
settingsInfo.BackgroundTransparency = 1
settingsInfo.Text = "Choose the color used for active controls."
settingsInfo.TextColor3 = GREY_TEXT
settingsInfo.TextSize = 10
settingsInfo.Font = Enum.Font.Gotham
settingsInfo.TextXAlignment = Enum.TextXAlignment.Left
settingsInfo.Parent = settingsCard

--==================================================
-- ACCENT BUTTONS
--==================================================

local accentButtons = {}

local accentNames = {
	"Purple",
	"Green",
	"Blue",
	"Red",
	"Orange",
	"Pink"
}

local accentPositions = {
	Purple = UDim2.fromOffset(18, 67),
	Green = UDim2.fromOffset(108, 67),
	Blue = UDim2.fromOffset(198, 67),

	Red = UDim2.fromOffset(18, 112),
	Orange = UDim2.fromOffset(108, 112),
	Pink = UDim2.fromOffset(198, 112)
}

for _, name in ipairs(accentNames) do

	local button = Instance.new("TextButton")

	button.Name = name .. "Accent"
	button.Position = accentPositions[name]
	button.Size = UDim2.fromOffset(78, 32)

	button.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	button.BorderSizePixel = 0

	button.Text = name
	button.TextColor3 = GREY_TEXT
	button.TextSize = 10
	button.Font = Enum.Font.GothamMedium

	button.AutoButtonColor = false
	button.Parent = settingsCard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	accentButtons[name] = button
end

--==================================================
-- ACCENT UPDATE
--==================================================

local function updateAccent()
	TOGGLE_ON = ACCENTS[currentAccent]

	for name, button in pairs(accentButtons) do

		if name == currentAccent then
			button.BackgroundColor3 = ACCENTS[name]
			button.TextColor3 = WHITE
		else
			button.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
			button.TextColor3 = GREY_TEXT
		end
	end

	if enabled then
		toggle.BackgroundColor3 = TOGGLE_ON
		status.TextColor3 = TOGGLE_ON
	end

	if antiAFKEnabled then
		antiAFKToggle.BackgroundColor3 = TOGGLE_ON
	end
end

for name, button in pairs(accentButtons) do

	button.MouseButton1Click:Connect(function()
		currentAccent = name
		updateAccent()
	end)
end

updateAccent()

--==================================================
-- AUTO PICK UPDATE
--==================================================

local function updateToggle()
	if enabled then

		TweenService:Create(
			toggle,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				BackgroundColor3 = TOGGLE_ON
			}
		):Play()

		TweenService:Create(
			knob,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(25, 3)
			}
		):Play()

		status.Text = "●  Enabled"
		status.TextColor3 = TOGGLE_ON

	else

		TweenService:Create(
			toggle,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				BackgroundColor3 = TOGGLE_OFF
			}
		):Play()

		TweenService:Create(
			knob,
			TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(3, 3)
			}
		):Play()

		status.Text = "●  Disabled"
		status.TextColor3 = GREY_TEXT
	end
end

toggle.MouseButton1Click:Connect(function()
	enabled = not enabled

	updateToggle()

	print(
		"[Sell Lemons]",
		enabled and "ON" or "OFF"
	)
end)

--==================================================
-- TABS
--==================================================

mainTab.MouseButton1Click:Connect(function()

	mainPage.Visible = true
	settingsPage.Visible = false

	mainTab.BackgroundTransparency = 0
	settingsTab.BackgroundTransparency = 1

	mainTab.TextColor3 = WHITE
	settingsTab.TextColor3 = Color3.fromRGB(150, 150, 150)
end)

settingsTab.MouseButton1Click:Connect(function()

	mainPage.Visible = false
	settingsPage.Visible = true

	mainTab.BackgroundTransparency = 1
	settingsTab.BackgroundTransparency = 0

	mainTab.TextColor3 = Color3.fromRGB(150, 150, 150)
	settingsTab.TextColor3 = WHITE
end)

--==================================================
-- MAIN GUI DRAGGING
--==================================================

local dragging = false
local dragStart
local startPosition

main.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then

		dragging = true
		dragStart = input.Position
		startPosition = main.Position
	end
end)

main.InputEnded:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)

	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then

		local delta = input.Position - dragStart

		main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,

			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

--==================================================
-- LEMON LAUNCHER
--==================================================

local launcher = Instance.new("TextButton")

launcher.Name = "LemonLauncher"
launcher.Size = UDim2.fromOffset(46, 46)
launcher.Position = UDim2.new(0, 22, 0.5, -23)

launcher.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
launcher.BorderSizePixel = 0

launcher.Text = "🍋"
launcher.TextSize = 22
launcher.Font = Enum.Font.GothamBold

launcher.AutoButtonColor = false
launcher.ZIndex = 50
launcher.Parent = gui

local launcherCorner = Instance.new("UICorner")
launcherCorner.CornerRadius = UDim.new(1, 0)
launcherCorner.Parent = launcher

--==================================================
-- LEMON LAUNCHER DRAGGING
--==================================================

local launcherDragging = false
local launcherDragStart
local launcherStartPosition
local launcherMoved = false

launcher.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then

		launcherDragging = true
		launcherMoved = false

		launcherDragStart = input.Position
		launcherStartPosition = launcher.Position
	end
end)

launcher.InputEnded:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		launcherDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)

	if launcherDragging and input.UserInputType == Enum.UserInputType.MouseMovement then

		local delta = input.Position - launcherDragStart

		if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
			launcherMoved = true
		end

		launcher.Position = UDim2.new(
			launcherStartPosition.X.Scale,
			launcherStartPosition.X.Offset + delta.X,

			launcherStartPosition.Y.Scale,
			launcherStartPosition.Y.Offset + delta.Y
		)
	end
end)

--==================================================
-- GUI SHRINK / GROW
--==================================================

local guiOpen = true
local guiAnimating = false

local function getCenterPosition(size, position)

	local centerX =
		position.X.Offset +
		(size.X.Offset / 2)

	local centerY =
		position.Y.Offset +
		(size.Y.Offset / 2)

	return UDim2.new(
		position.X.Scale,
		centerX,

		position.Y.Scale,
		centerY
	)
end

local function closeGUI()

	if guiAnimating or not guiOpen then
		return
	end

	guiAnimating = true

	local currentSize = main.Size
	local currentPosition = main.Position

	local centerPosition =
		getCenterPosition(
			currentSize,
			currentPosition
		)

	local closeTween = TweenService:Create(
		main,

		TweenInfo.new(
			0.25,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		),

		{
			Size = UDim2.fromOffset(1, 1),

			Position = UDim2.new(
				centerPosition.X.Scale,
				centerPosition.X.Offset,

				centerPosition.Y.Scale,
				centerPosition.Y.Offset
			)
		}
	)

	closeTween:Play()
	closeTween.Completed:Wait()

	main.Visible = false

	main.Size = currentSize
	main.Position = currentPosition

	guiOpen = false
	guiAnimating = false
end

local function openGUI()

	if guiAnimating or guiOpen then
		return
	end

	guiAnimating = true

	local currentSize = main.Size
	local currentPosition = main.Position

	local centerPosition =
		getCenterPosition(
			currentSize,
			currentPosition
		)

	main.Size = UDim2.fromOffset(1, 1)

	main.Position = UDim2.new(
		centerPosition.X.Scale,
		centerPosition.X.Offset,

		centerPosition.Y.Scale,
		centerPosition.Y.Offset
	)

	main.Visible = true

	local openTween = TweenService:Create(
		main,

		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),

		{
			Size = currentSize,
			Position = currentPosition
		}
	)

	openTween:Play()
	openTween.Completed:Wait()

	guiOpen = true
	guiAnimating = false
end

--==================================================
-- LAUNCHER CLICK
--==================================================

launcher.MouseButton1Click:Connect(function()

	if launcherMoved then
		launcherMoved = false
		return
	end

	if guiOpen then
		closeGUI()
	else
		openGUI()
	end
end)

--==================================================
-- SERVER HOP
--==================================================
-- FIX: the previous version tried to queue the local `source`
-- variable from the OUTER wrapper. loadstring() runs this code in
-- a fresh chunk that does not inherit that local, so `source` here
-- was always nil and queuing silently failed on every hop.
-- The outer wrapper now stores the script text in
-- `_G.__SellLemonsSource` before calling loadstring, so it's
-- reachable from in here regardless of chunk boundaries.
--==================================================

-- Some executors only expose the queue function namespaced (e.g.
-- syn.queue_on_teleport), and some use slightly different names.
-- Try every variant rather than assuming one.
local function resolveQueueFunction()

	if type(queue_on_teleport) == "function" then
		return queue_on_teleport
	end

	if type(queueonteleport) == "function" then
		return queueonteleport
	end

	if type(queueteleport) == "function" then
		return queueteleport
	end

	if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end

	return nil
end

-- FIX: instead of carrying the ENTIRE script's text across the
-- teleport boundary (via _G or getgenv, which either isn't shared
-- the way we assumed, or doesn't reliably survive a second use on
-- this executor), queue a tiny, constant bootstrap snippet that
-- waits for the new server to finish loading and then re-downloads
-- and re-runs this same file fresh from HOSTED_URL. Nothing has to
-- survive the teleport except a short string built from a fixed
-- URL, so there's no session state to lose between hops.
local function queueTeleportSource()

	local queueFn = resolveQueueFunction()

	if not queueFn then
		warn("[Sell Lemons] No queue_on_teleport-style function exists on this executor - it can't survive a server hop")
		return
	end

	local bootstrap = ([[
repeat task.wait() until game:IsLoaded()
loadstring(game:HttpGet("%s"))()
]]):format(HOSTED_URL)

	local ok, err = pcall(queueFn, bootstrap)

	if ok then
		print("[Sell Lemons] Reload bootstrap queued")
	else
		warn("[Sell Lemons] Queue function exists but errored when called:", err)
	end
end

local function serverHop()

	print("[Sell Lemons] Server hopping...")

	-- Queue right before the actual teleport, not at script load.
	-- If we queue only once at load time and the player gets
	-- teleported for any other reason first, the queue is consumed
	-- and this intentional hop would land with nothing queued.
	queueTeleportSource()

	task.wait(0.15)

	-- Surfacing this error instead of silently swallowing it: if
	-- Roblox throttles repeated self-teleports, or the executor
	-- rejects a second Teleport call in the same session, this will
	-- actually tell us instead of failing invisibly.
	local ok, err = pcall(function()
		TeleportService:Teleport(game.PlaceId, player)
	end)

	if ok then
		print("[Sell Lemons] Teleport call succeeded")
	else
		warn("[Sell Lemons] Teleport call FAILED:", err)
	end
end

--==================================================
-- TEST SERVER HOP BUTTON
--==================================================
-- REMOVE THIS ENTIRE SECTION WHEN YOU ARE DONE TESTING.
--==================================================

local testHopButton = Instance.new("TextButton")

testHopButton.Name = "TestServerHop"
testHopButton.Position = UDim2.fromOffset(22, 290)
testHopButton.Size = UDim2.fromOffset(284, 40)

testHopButton.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
testHopButton.BorderSizePixel = 0

testHopButton.Text = "TEST SERVER HOP"
testHopButton.TextColor3 = GREY_TEXT
testHopButton.TextSize = 10
testHopButton.Font = Enum.Font.GothamMedium

testHopButton.AutoButtonColor = false
testHopButton.Parent = settingsPage

local testHopCorner = Instance.new("UICorner")
testHopCorner.CornerRadius = UDim.new(0, 8)
testHopCorner.Parent = testHopButton

testHopButton.MouseButton1Click:Connect(function()

	print("[Sell Lemons] TEST SERVER HOP")

	serverHop()
end)

--==================================================
-- FARMER
--==================================================

local treeCache = {}
local lastTreeScan = 0

--==================================================
-- GET ROOT
--==================================================

local function getRoot()

	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

--==================================================
-- TREE CACHE
--==================================================

local function refreshTreeCache()

	local newCache = {}

	for _, tycoon in ipairs(workspace:GetChildren()) do

		if tycoon.Name:match("^Tycoon") then

			local constant = tycoon:FindFirstChild("Constant")
			local trees = constant and constant:FindFirstChild("Trees")

			if trees then

				for _, tree in ipairs(trees:GetChildren()) do

					if tree.Name == "LemonTree" then

						table.insert(newCache, tree)
					end
				end
			end
		end
	end

	treeCache = newCache
	lastTreeScan = os.clock()
end

local function getTycoonTrees()

	if os.clock() - lastTreeScan >= TREE_SCAN_DELAY then
		refreshTreeCache()
	end

	return treeCache
end

--==================================================
-- GET ACTIVE FRUIT DETECTORS
--==================================================

local function getFruitDetectors(tree)

	local detectors = {}

	if not tree or not tree.Parent then
		return detectors
	end

	for _, object in ipairs(tree:GetDescendants()) do

		if object:IsA("ClickDetector") then

			-- Only use detectors belonging to ClickFruitPart.
			local parent = object.Parent

			if parent and parent.Name == "ClickFruitPart" then
				table.insert(detectors, object)
			end
		end
	end

	return detectors
end

--==================================================
-- COLLECT TREE
--==================================================

local function collectTree(tree)

	if not enabled then
		return
	end

	if not tree or not tree.Parent then
		return
	end

	local root = getRoot()

	if not root then
		return
	end

	-- Teleport once.
	root.CFrame =
		tree:GetPivot() +
		Vector3.new(0, 3, 0)

	task.wait(TREE_STOP_TIME)

	if not enabled then
		return
	end

	-- Snapshot all current detectors.
	local detectors = getFruitDetectors(tree)

	-- Rapid-fire the whole tree.
	for _, detector in ipairs(detectors) do

		if not enabled then
			return
		end

		if detector
			and detector.Parent
			and detector:IsDescendantOf(tree) then

			pcall(function()
				fireclickdetector(detector)
			end)

			if CLICK_DELAY > 0 then
				task.wait(CLICK_DELAY)
			end
		end
	end
end

--==================================================
-- FARM LOOP
--==================================================

task.spawn(function()

	while true do

		if enabled then

			local trees = getTycoonTrees()

			for _, tree in ipairs(trees) do

				if not enabled then
					break
				end

				if tree and tree.Parent then
					collectTree(tree)
				end
			end

		end

		task.wait()
	end
end)

--==================================================
-- CHARACTER RESPAWN HANDLER
--==================================================

player.CharacterAdded:Connect(function()

	-- Give Roblox a moment to finish loading the character.
	task.wait(0.5)

	if enabled then
		refreshTreeCache()
	end
end)

--==================================================
-- INITIAL TREE CACHE
--==================================================

refreshTreeCache()

--==================================================
-- INITIAL STATE
--==================================================

updateToggle()
updateAntiAFK()

--==================================================
-- AUTOMATIC SERVER HOP
--==================================================

task.spawn(function()

	print("[Sell Lemons] Auto-hop loop started, interval =", SERVER_HOP_INTERVAL, "seconds")

	while true do

		task.wait(SERVER_HOP_INTERVAL)

		print("[Sell Lemons] Hop timer elapsed")

		-- Make sure the GUI/script still exists. If it's gone
		-- (script stopped/unloaded), stop looping instead of
		-- hopping forever with nothing left to control it.
		if not gui.Parent then
			print("[Sell Lemons] GUI gone - stopping auto-hop loop")
			break
		end

		print("[Sell Lemons] Hop interval reached - server hopping")

		serverHop()

		-- No `break` here anymore: after this hop, the script
		-- (re-)queues itself via serverHop() -> queueTeleportSource(),
		-- so it comes back up on the new server, hits this same
		-- task.spawn block again, and waits another 10 minutes
		-- before hopping again. Repeats indefinitely.
	end
end)

print("[Sell Lemons 🍋] Loaded")
print("[Sell Lemons 🍋] Trees cached:", #treeCache)
print("[Sell Lemons 🍋] Auto Pick Fruits: ON")
print("[Sell Lemons 🍋] Anti-AFK: ON")
print("[Sell Lemons 🍋] Server hop: 1 minute")
print("[Sell Lemons 🍋] Farming system ready")

end -- end of main()

--==================================================
-- RETRY WRAPPER
-- Run main() and, if the game still wasn't ready enough and
-- something threw, wait a beat and try the whole setup again
-- instead of leaving the script dead with no GUI and no farming.
--==================================================

local MAX_START_ATTEMPTS = 6
local started = false

for attempt = 1, MAX_START_ATTEMPTS do

	local ok, err = pcall(main)

	if ok then
		started = true
		break
	end

	warn("[Sell Lemons] Start attempt", attempt, "failed:", err)

	if attempt < MAX_START_ATTEMPTS then
		print("[Sell Lemons] Retrying in 2 seconds...")
		task.wait(2)
	end
end

if not started then
	warn("[Sell Lemons] Failed to start after", MAX_START_ATTEMPTS, "attempts - giving up for this server")
end
