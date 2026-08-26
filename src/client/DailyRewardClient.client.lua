--// Daily Reward Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Drives StarterGui.DailyRewardUI (the 7-day panel) and
--// StarterGui.DailyRewardGiftButtonUI (the always-on floating button).
--// Every object referenced below already exists (built in Studio) - this
--// script only finds them (WaitForChild) and reads/writes their properties,
--// same convention ShopClient/ProfileClient use; it never creates UI
--// Instances itself except cloning the CoinToast template, the same way
--// ObbyClient clones the LeaderboardRow template.
--//
--// The claim window/streak/reward are entirely server-decided
--// (DailyRewardService) - this script only ever sends a bare "Claim" and
--// renders whatever the server replicates back via LastClaimTime/
--// DailyStreak (same trust model as Coins/Inventory/EquippedTrail
--// elsewhere). The on-screen countdown is cosmetic only, same tolerance
--// already accepted for ObbyClient's run stopwatch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")


local DailyRewardRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DailyRewardRemote")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewardConfig = require(Shared:WaitForChild("DailyRewardConfig"))
local UIAnimation = require(Shared:WaitForChild("UIAnimation"))
local UIDisable = require(Shared:WaitForChild("UIDisable"))
local coinToastTemplate = Shared:WaitForChild("Templates"):WaitForChild("CoinToast")

local DAY_COUNT = DailyRewardConfig.MaxDay
local CLAIM_INTERVAL = 24 * 60 * 60 -- mirrors DailyRewardService; cosmetic countdown only, server re-checks the real value

local lastClaimTime = player:WaitForChild("LastClaimTime", 10)
local dailyStreak = player:WaitForChild("DailyStreak", 10)

--============================ REWARD DISPLAY (extensible, same idea as the server's RewardHandlers) ============================--
-- how to describe a reward Type on the claim toast; add a new Type by adding
-- one function here - no existing entry changes
local RewardDisplayHandlers = {}

function RewardDisplayHandlers.Coins(rewardData)
	return "+" .. rewardData.Amount .. " Coins"
end

local function describeReward(rewardData)
	local handler = rewardData and RewardDisplayHandlers[rewardData.Type]
	return handler and handler(rewardData) or "Reward Claimed!"
end

--============================ GUI ============================--
local dailyRewardGui = playerGui:WaitForChild("DailyRewardUI")
local dim = dailyRewardGui:WaitForChild("Dim")
local panel = dailyRewardGui:WaitForChild("DailyRewardFrame")

local header = panel:WaitForChild("Header")
local closeBtn = header:WaitForChild("CloseBtn")
local streakLbl = panel:WaitForChild("StreakLbl")
local cardsRow = panel:WaitForChild("CardsRow")
local countdownLbl = panel:WaitForChild("CountdownLbl")
local claimButton = panel:WaitForChild("ClaimButton")

local gui = playerGui:WaitForChild("BoostUI")
local gui2 = playerGui:WaitForChild("ShopUI")
local gui3 = playerGui:WaitForChild("ProfileUI")
local giftGui = playerGui:WaitForChild("DailyRewardGiftButtonUI")

local giftButton = giftGui:WaitForChild("GiftButton")
local openButton1 = gui:WaitForChild("OpenButton")
local openButton2 = gui2:WaitForChild("OpenButton")
local openButton3 = gui3:WaitForChild("OpenButton")


local giftNotifyDot = giftButton:WaitForChild("NotifyDot")

local claimSound = SoundService:FindFirstChild("DailyRewardClaimSound")
local ButtonClick = SoundService:WaitForChild("ButtonClick")

dim.Visible = false
panel.Visible = false

-- one card per configured day, found under CardsRow by "DayCard" .. day
local dayCards = {}
for i = 1, DAY_COUNT do
	local card = cardsRow:WaitForChild("DayCard" .. i, 5)
	if card then
		dayCards[i] = {
			frame = card,
			amountLbl = card:WaitForChild("AmountLabel"),
			checkMark = card:WaitForChild("CheckMark"),
			stroke = card:FindFirstChildOfClass("UIStroke"),
		}
		dayCards[i].amountLbl.Text = tostring(DailyRewardConfig.getReward(i).Amount)
	else
		warn("[DailyRewardClient] CardsRow.DayCard" .. i .. " not found")
	end
end

--============================ COOLDOWN MATH (cosmetic mirror of the server) ============================--
local function secondsUntilClaimable()
	if lastClaimTime.Value == 0 then return 0 end
	return math.max(0, (lastClaimTime.Value + CLAIM_INTERVAL) - os.time())
end

local function formatCountdown(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

--============================ CARD STATES ============================--

local function applyCardState(card, state)
	if state == "Claimed" then
		card.checkMark.Visible = true
		card.frame.BackgroundTransparency = 0

		if card.stroke then
			card.stroke.Thickness = 1
		end

	elseif state == "ClaimedCurrent" then
		card.checkMark.Visible = true
		card.frame.BackgroundTransparency = 0

		if card.stroke then
			card.stroke.Thickness = 2
		end

	elseif state == "Current" then
		card.checkMark.Visible = false
		card.frame.BackgroundTransparency = 0

		if card.stroke then
			card.stroke.Thickness = 2
		end

	else -- Locked
		card.checkMark.Visible = false
		card.frame.BackgroundTransparency = 0.15

		if card.stroke then
			card.stroke.Thickness = 1
		end
	end
end

-- pendingDay = the day the NEXT successful claim will grant, capped at
-- DAY_COUNT so a long streak keeps landing on the last day instead of
-- wrapping back to Day 1 (mirrors DailyRewardService's own math exactly)
local function refreshCards()
	local streak = dailyStreak.Value
	local claimableNow = secondsUntilClaimable() <= 0
	local pendingDay = math.min(streak + 1, DAY_COUNT)
	local lastGrantedDay = math.min(streak, DAY_COUNT)

	for i, card in pairs(dayCards) do
		if claimableNow then
			if i < pendingDay then
				applyCardState(card, "Claimed")
			elseif i == pendingDay then
				applyCardState(card, "Current")
			else
				applyCardState(card, "Locked")
			end
		else
			if streak > 0 and i < lastGrantedDay then
				applyCardState(card, "Claimed")
			elseif streak > 0 and i == lastGrantedDay then
				applyCardState(card, "ClaimedCurrent")
			else
				applyCardState(card, "Locked")
			end
		end
	end
end

--============================ CLAIM BUTTON + COUNTDOWN ============================--
local CLAIM_ACTIVE_COLOR = 1
local CLAIM_DISABLED_COLOR = 0.7

local function refreshClaimButton()
	local text = claimButton:WaitForChild("text")
	local remaining = secondsUntilClaimable()
	local claimableNow = remaining <= 0

	claimButton.Active = claimableNow
	claimButton.AutoButtonColor = claimableNow
	claimButton.text.Text = claimableNow and "Claim" or "Claimed"
	claimButton.Disabled.BackgroundTransparency = claimableNow and CLAIM_ACTIVE_COLOR or CLAIM_DISABLED_COLOR

	countdownLbl.Visible = not claimableNow
	if not claimableNow then
		countdownLbl.Text = "Next reward in " .. formatCountdown(remaining)
	end

	giftNotifyDot.Visible = claimableNow
end

local function refreshStreakLabel()
	streakLbl.Text = "🔥 Streak: " .. dailyStreak.Value .. (dailyStreak.Value == 1 and " Day" or " Days")
end

local function refreshAll()
	refreshCards()
	refreshClaimButton()
	refreshStreakLabel()
end

-- keeps the countdown ticking even with no server event; .Changed covers the
-- instant a claim actually lands so the UI doesn't wait up to a second
task.spawn(function()
	while true do
		refreshClaimButton()
		task.wait(1)
	end
end)

lastClaimTime.Changed:Connect(refreshAll)
dailyStreak.Changed:Connect(refreshAll)

--============================ OPEN / CLOSE ============================--
local function openPanel()
	refreshAll()
	UIDisable.Disable(giftButton, openButton1, openButton2, openButton3)
	if UIAnimation.Open(panel, dim) then
		ButtonClick:Play()
	end
end

local function closePanel()
	UIDisable.Appear(giftButton, openButton1, openButton2, openButton3)
	if UIAnimation.Close(panel, dim) then
		ButtonClick:Play()
	end
end

closeBtn.MouseButton1Click:Connect(closePanel)
dim.MouseButton1Click:Connect(closePanel)
giftButton.MouseButton1Click:Connect(function()
	if panel.Visible then
		closePanel()
	else
		openPanel()
	end
end)

UIAnimation.ButtonPress(closeBtn)
UIAnimation.ButtonPress(claimButton)
UIAnimation.ButtonPress(giftButton)

--============================ CLAIM ANIMATION ============================--
local function showCoinToast(card, text)
	local toast = coinToastTemplate:Clone()
	toast.Text = text
	toast.TextTransparency = 0
	toast.Position = UDim2.fromScale(0.5, 0.4)
	toast.Parent = card.frame

	UIAnimation.Notification(toast, {
		rise = true,
		destroy = true,
		hold = 0,
	})
end

local function playClaimAnimation(day, rewardData)
	if claimSound then
		claimSound:Play()
	end

	local card = dayCards[day]
	if card then
		showCoinToast(card, describeReward(rewardData))
		UIAnimation.Popup(card.frame)
	end

	UIAnimation.Popup(claimButton)
	refreshAll()
end

--============================ CLAIM WIRING ============================--
claimButton.MouseButton1Click:Connect(function()
	if not claimButton.Active then return end
	DailyRewardRemote:FireServer("Claim")
end)

DailyRewardRemote.OnClientEvent:Connect(function(action, ...)
	if action == "Claimed" then
		local day, rewardData = ...
		playClaimAnimation(day, rewardData)

	elseif action == "OnCooldown" then
		refreshClaimButton()
	end
end)

--============================ AUTO-OPEN (once per session, only if claimable) ============================--
task.spawn(function()
	refreshAll()

	if secondsUntilClaimable() <= 0 then
		task.wait(1.5) -- let the player's screen settle in before popping the panel
		openPanel()
	end
end)
