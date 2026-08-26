--// Obby Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Drives the Timer UI (StarterGui.TimerGui) while a run is active, and the
--// Result UI (StarterGui.ResultGui) - time, best time, "NEW BEST TIME!" and
--// that Obby's live leaderboard - when a run finishes.
--// All times shown come from the server (TimerEvent); this script never
--// computes an authoritative time, only renders one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local TimerEvent = Events:WaitForChild("TimerEvent")
local LeaderboardEvent = Events:WaitForChild("LeaderboardEvent")
local ButtonClick = SoundService:WaitForChild("ButtonClick")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObbyConfig = require(Shared:WaitForChild("ObbyConfig"))
local UIAnimation = require(Shared:WaitForChild("UIAnimation"))
local UIDisable = require(Shared:WaitForChild("UIDisable"))
local rowTemplate = Shared:WaitForChild("Templates"):WaitForChild("LeaderboardRow")

--============================ GUI ============================--
local timerGui = playerGui:WaitForChild("TimerGui")
local timerFrame = timerGui:WaitForChild("TimerFrame")
local timerObbyLbl = timerFrame:WaitForChild("ObbyLbl")
local timerTimeLbl = timerFrame:WaitForChild("TimeLbl")

local resultGui = playerGui:WaitForChild("ResultGui")
local dim = resultGui:WaitForChild("Dim")
local panel = resultGui:WaitForChild("Panel")
local closeBtn = panel:WaitForChild("CloseBtn")
local bestBanner = panel:WaitForChild("BestBanner")
local titleLbl = panel:WaitForChild("Title")
local timeLbl = panel:WaitForChild("TimeLbl")
local bestLbl = panel:WaitForChild("BestLbl")
local rewardLbl = panel:WaitForChild("RewardLbl")
local list = panel:WaitForChild("List")

local gui1 = playerGui:WaitForChild("BoostUI")
local gui2 = playerGui:WaitForChild("ShopUI")
local gui3 = playerGui:WaitForChild("ProfileUI")
local gui4 = playerGui:WaitForChild("DailyRewardGiftButtonUI")

local openButton1 = gui4:WaitForChild("GiftButton")
local openButton2 = gui3:WaitForChild("OpenButton")
local openButton3 = gui2:WaitForChild("OpenButton")
local openButton4 = gui1:WaitForChild("OpenButton")

dim.Visible = false
panel.Visible = false

--============================ TIME FORMATTING ============================--
-- ms -> "00:24.35"
local function formatMs(ms)
	local totalSeconds = ms / 1000
	local minutes = math.floor(totalSeconds / 60)
	local secs = totalSeconds % 60
	return string.format("%02d:%05.2f", minutes, secs)
end

-- ms -> "01:23.456" (millisecond-precise, for the completion notification)
local function formatMsPrecise(ms)
	local minutes = math.floor(ms / 60000)
	local secs = math.floor(ms % 60000 / 1000)
	local millis = ms % 1000
	return string.format("%02d:%02d.%03d", minutes, secs, millis)
end

--============================ TIMER UI ============================--
local running = false
local runStart = 0
local heartbeatConn = nil

local function stopTimerDisplay()
	running = false
	timerFrame.Visible = false
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function startTimerDisplay(obbyId)
	stopTimerDisplay()

	running = true
	runStart = os.clock()
	timerObbyLbl.Text = ObbyConfig.getDisplayName(obbyId)
	timerTimeLbl.Text = "00:00.00"
	timerFrame.Visible = true

	-- purely cosmetic local stopwatch; the server's "Finish" value is authoritative
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not running then return end
		timerTimeLbl.Text = formatMs((os.clock() - runStart) * 1000)
	end)
end

--============================ LEADERBOARD ============================--
local function renderLeaderboard(entries)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for _, entry in ipairs(entries) do
		local row = rowTemplate:Clone()
		row.LayoutOrder = entry.rank
		row:WaitForChild("RankLbl").Text = "#" .. entry.rank
		row:WaitForChild("NameLbl").Text = entry.name
		row:WaitForChild("TimeLbl").Text = formatMs(entry.timeMs)
		row.Parent = list
	end
end

--============================ RESULT UI ============================--
local function showResult(obbyId, timeMs, reward, isNewBest, bestMs)
	titleLbl.Text = "Completed in " .. formatMsPrecise(timeMs)
	timeLbl.Text = "Your Time: " .. formatMs(timeMs)
	bestLbl.Text = "Best Time: " .. formatMs(bestMs)
	rewardLbl.Text = "Reward: +" .. reward .. " Coins"
	bestBanner.Visible = isNewBest

	renderLeaderboard({}) -- clear stale rows while the fresh list loads
	
	UIAnimation.Open(panel, dim)
	UIDisable.Disable(openButton1, openButton2, openButton3, openButton4)
	LeaderboardEvent:FireServer(obbyId)
end

local function hideResult()
	UIDisable.Appear(openButton1, openButton2, openButton3, openButton4)
	if UIAnimation.Close(panel, dim) then
		ButtonClick:Play()
	end
end

closeBtn.MouseButton1Click:Connect(function()
    task.wait(0.1)
    hideResult()
end)
dim.MouseButton1Click:Connect(function()
    task.wait(0.1)
    hideResult()
end)

UIAnimation.ButtonPress(closeBtn)

--============================ SERVER EVENTS ============================--
TimerEvent.OnClientEvent:Connect(function(action, obbyId, ...)
	if action == "Start" then
		startTimerDisplay(obbyId)

	elseif action == "Reset" then
		stopTimerDisplay()

	elseif action == "Finish" then
		local timeMs, reward, isNewBest, bestMs = ...
		stopTimerDisplay()

		-- guard against a malformed/stale payload instead of erroring mid-render
		-- (a silent error here would leave Title/Your Time set but Best Time blank)
		if type(bestMs) ~= "number" then
			warn("[ObbyClient] Finish payload missing bestMs for " .. tostring(obbyId) .. " - ignoring")
			return
		end

		showResult(obbyId, timeMs, reward, isNewBest, bestMs)
	end
end)

LeaderboardEvent.OnClientEvent:Connect(function(action, obbyId, entries)
	if action ~= "Data" then return end
	if not panel.Visible then return end -- ignore late responses after the panel closed
	renderLeaderboard(entries)
end)