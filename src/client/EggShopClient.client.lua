--// Egg Shop Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Builds a small result popup and shows what you rolled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local EggEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EggEvent")

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 200, 220),
	Rare      = Color3.fromRGB(80, 160, 255),
	Epic      = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
}

-- Build the popup once
local gui = Instance.new("ScreenGui")
gui.Name = "EggPopup"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.35)
frame.Size = UDim2.fromOffset(340, 130)
frame.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
frame.BackgroundTransparency = 0.05
frame.Visible = false
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -24, 0, 36)
title.Position = UDim2.fromOffset(12, 14)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = ""
title.Parent = frame

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, -24, 0, 54)
sub.Position = UDim2.fromOffset(12, 58)
sub.Font = Enum.Font.GothamMedium
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(230, 230, 230)
sub.Text = ""
sub.Parent = frame

local showToken = 0
local function show(color, titleText, subText)
	showToken += 1
	local myToken = showToken

	stroke.Color = color
	title.TextColor3 = color
	title.Text = titleText
	sub.Text = subText

	frame.Visible = true
	frame.Size = UDim2.fromOffset(300, 115)
	TweenService:Create(
		frame,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(340, 130) }
	):Play()

	task.wait(3)
	if myToken == showToken then
		frame.Visible = false
	end
end

EggEvent.OnClientEvent:Connect(function(action, ...)
	local args = { ... }

	if action == "Reward" then
		local name, rarity = args[1], args[2]
		show(RARITY_COLORS[rarity] or Color3.new(1, 1, 1), "You unlocked:", name .. "  (" .. rarity .. ")")

	elseif action == "Duplicate" then
		local name, _, refund = args[1], args[2], args[3]
		show(Color3.fromRGB(200, 200, 200), "Duplicate!", name .. " - refunded " .. refund .. " coins")

	elseif action == "NotEnough" then
		local cost, have = args[1], args[2]
		show(Color3.fromRGB(255, 90, 90), "Not enough coins", "Need " .. cost .. ", you have " .. have)
	end
end)
