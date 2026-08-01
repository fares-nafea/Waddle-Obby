--// Obby Locked Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Shows a brief fading banner when the server blocks a teleport into a
--// locked Obby (see TeleportService's Portal.Touched gate). Purely a
--// renderer - the server has already decided the teleport was blocked
--// before this ever fires, so there's nothing to validate here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ObbyLockedEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ObbyLockedEvent")

local noticeGui = playerGui:WaitForChild("LockedNoticeUI")
local noticeFrame = noticeGui:WaitForChild("NoticeFrame")
local noticeLbl = noticeFrame:WaitForChild("NoticeLbl")

local FADE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOLD_TIME = 2 -- seconds the banner stays fully visible before fading out

-- bumped on every new message so a stale fade-out from a rapid-fire repeat
-- touch (e.g. bumping the same locked gate twice) can't hide a fresher banner
local showToken = 0

local function showMessage(text)
	noticeLbl.Text = text

	showToken += 1
	local myToken = showToken

	noticeFrame.Visible = true
	noticeFrame.BackgroundTransparency = 1
	noticeLbl.TextTransparency = 1

	TweenService:Create(noticeFrame, FADE_IN, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(noticeLbl, FADE_IN, { TextTransparency = 0 }):Play()

	task.delay(HOLD_TIME, function()
		if showToken ~= myToken then return end

		local outTween = TweenService:Create(noticeFrame, FADE_OUT, { BackgroundTransparency = 1 })
		TweenService:Create(noticeLbl, FADE_OUT, { TextTransparency = 1 }):Play()
		outTween:Play()

		outTween.Completed:Connect(function()
			if showToken == myToken then
				noticeFrame.Visible = false
			end
		end)
	end)
end

ObbyLockedEvent.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "string" then return end
	showMessage(message)
end)
