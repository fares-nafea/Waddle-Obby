--// Egg Shop Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Shows the result popup (built in StarterGui.EggPopup) when you roll an egg.

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

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("EggPopup")
local frame = gui:WaitForChild("Popup")
local stroke = frame:WaitForChild("UIStroke")
local title = frame:WaitForChild("Title")
local sub = frame:WaitForChild("Sub")

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
