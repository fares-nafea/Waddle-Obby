--// Boost UI Controller
--// Place in: StarterPlayer > StarterPlayerScripts
--// Drives StarterGui.BoostUI - a small always-available status badge (2X
--// Coins icon, active/expired status, remaining time) plus a compact panel
--// with one button per BoostConfig tier. Every object referenced below
--// already exists (built in Studio) - this script only finds them
--// (WaitForChild) and reads/writes their properties, same convention
--// ShopClient/ProfileClient use.
--//
--// No RemoteEvent is needed to know boost status: BoostRemainingSeconds and
--// BoostPermanent are DataService-created Instances that already replicate
--// to this client (same trust model ProfileClient/DailyRewardClient rely on
--// for UnlockedObby/DailyStreak/etc) - the server (BoostService) is the only
--// thing that ever writes them, so this script only ever displays what's
--// already there. BoostRemote is used for exactly one thing: asking the
--// server to prompt a purchase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BoostRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoostRemote")
local BoostConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoostConfig"))

local activateSound = SoundService:FindFirstChild("BoostActivateSound")
local ButtonClick = SoundService:WaitForChild("ButtonClick")

local boostRemainingSeconds = player:WaitForChild("BoostRemainingSeconds", 10)
local boostPermanent = player:WaitForChild("BoostPermanent", 10)

--============================ GUI ============================--
local gui = playerGui:WaitForChild("BoostUI")

local badge = gui:WaitForChild("StatusBadge")
local statusLbl = badge:WaitForChild("StatusLbl")
local timeLbl = badge:WaitForChild("TimeLbl")

local openButton = gui:WaitForChild("OpenButton")
local dim = gui:WaitForChild("Dim")
local panel = gui:WaitForChild("BoostFrame")
local header = panel:WaitForChild("Header")
local closeBtn = header:WaitForChild("CloseBtn")
local list = panel:WaitForChild("List")

badge.Visible = false
dim.Visible = false
panel.Visible = false

--============================ FORMAT ============================--
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

--============================ BADGE ============================--
local POP_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function playActivationCue()
	badge.Visible = true

	if activateSound then
		activateSound:Play()
	end

	local scale = badge:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.8
		TweenService:Create(scale, POP_TWEEN, { Scale = 1 }):Play()
	end
end

local function showExpiredNotification()
	badge.Visible = true
	statusLbl.Text = "Boost Expired"
	timeLbl.Visible = false

	task.delay(2.5, function()
		-- only hide if nothing re-activated it in the meantime
		if not boostPermanent.Value and boostRemainingSeconds.Value <= 0 then
			badge.Visible = false
		end
	end)
end

local function refresh()
	local permanent = boostPermanent.Value
	local remaining = boostRemainingSeconds.Value
	local active = permanent or remaining > 0

	if not active then
		badge.Visible = false
		return
	end

	badge.Visible = true
	statusLbl.Text = "2X Coins Active"

	if permanent then
		timeLbl.Visible = false
	else
		timeLbl.Visible = true
		timeLbl.Text = "Time Left: " .. formatTime(remaining)
	end
end

-- BoostRemainingSeconds.Changed fires from two very different sources: the
-- server's own once-a-second countdown (a decrease) and a purchase landing
-- (an increase) - only the increase should play the activation cue, so the
-- last seen value is tracked to tell them apart
local lastRemaining = boostRemainingSeconds.Value

boostRemainingSeconds.Changed:Connect(function(newValue)
	if newValue > lastRemaining then
		playActivationCue()
	elseif newValue == 0 and lastRemaining > 0 and not boostPermanent.Value then
		showExpiredNotification()
	end
	lastRemaining = newValue
	refresh()
end)

boostPermanent.Changed:Connect(function(newValue)
	refresh()
	if newValue then
		playActivationCue()
	end
end)

refresh()

--============================ PANEL OPEN / CLOSE ============================--
local OPEN_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local panelSize = panel.Size -- the size authored in Studio; never overwritten with a guessed value
local closing = false

local function openPanel()
	if panel.Visible then return end

	closing = false

	dim.Visible = true
	dim.BackgroundTransparency = 1
	ButtonClick:Play()
	panel.Visible = true
	panel.Size = panelSize - UDim2.fromOffset(40, 40)

	TweenService:Create(panel, OPEN_TWEEN, { Size = panelSize }):Play()
	TweenService:Create(dim, OPEN_TWEEN, { BackgroundTransparency = 0.5 }):Play()
end

local function closePanel()
	if not panel.Visible or closing then return end
	closing = true

	local shrink = TweenService:Create(panel, CLOSE_TWEEN, { Size = panelSize - UDim2.fromOffset(40, 40) })
	TweenService:Create(dim, CLOSE_TWEEN, { BackgroundTransparency = 1 }):Play()
	shrink:Play()

	shrink.Completed:Connect(function()
		ButtonClick:Play()
		panel.Visible = false
		dim.Visible = false
		panel.Size = panelSize
		closing = false
	end)
end

openButton.MouseButton1Click:Connect(function()
	if panel.Visible then
		closePanel()
	else
		openPanel()
	end
end)

closeBtn.MouseButton1Click:Connect(closePanel)
dim.MouseButton1Click:Connect(closePanel)

--============================ HOVER / PRESS FEEL ============================--
local PRESS_DOWN_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_UP_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- press-down/release "click" feel for any button, via its own UIScale - same helper ShopClient/ProfileClient/DailyRewardClient use
local function wireButtonPress(button)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then return end

	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, PRESS_DOWN_TWEEN, { Scale = 0.94 }):Play()
	end)

	local function release()
		TweenService:Create(scale, PRESS_UP_TWEEN, { Scale = 1 }):Play()
	end

	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

wireButtonPress(closeBtn)

--============================ BUY BUTTON WIRING ============================--
local ROW_NAMES = {
	Boost10Min = "Boost10MinRow",
	Boost30Min = "Boost30MinRow",
	Boost1Hour = "Boost1HourRow",
	BoostForever = "BoostForeverRow",
}

local BUY_DEBOUNCE = 1 -- seconds; stops one double-click firing two purchase prompts
local lastClick = 0

for _, item in ipairs(BoostConfig.Items) do
	local rowName = ROW_NAMES[item.Id]
	local row = rowName and list:FindFirstChild(rowName)

	if row then
		local buyButton = row:FindFirstChild("BuyButton")

		if buyButton then
			wireButtonPress(buyButton)

			buyButton.MouseButton1Click:Connect(function()
				local now = os.clock()
				if now - lastClick < BUY_DEBOUNCE then return end
				lastClick = now

				BoostRemote:FireServer("Boost", item.Id)
			end)
		else
			warn("[BoostUIController] " .. rowName .. ".BuyButton not found - can't sell " .. item.Name)
		end
	else
		warn("[BoostUIController] List." .. tostring(rowName) .. " not found - can't sell " .. item.Name)
	end
end
