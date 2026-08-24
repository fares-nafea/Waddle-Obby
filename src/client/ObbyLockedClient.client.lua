--// Obby Locked Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Shows a brief fading banner when the server blocks a teleport into a
--// locked Obby (see TeleportService's Portal.Touched gate). Purely a
--// renderer - the server has already decided the teleport was blocked
--// before this ever fires, so there's nothing to validate here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIAnimation = require(Shared:WaitForChild("UIAnimation"))
local ObbyLockedEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ObbyLockedEvent")

local noticeGui = playerGui:WaitForChild("LockedNoticeUI")
local noticeFrame = noticeGui:WaitForChild("NoticeFrame")
local noticeLbl = noticeFrame:WaitForChild("NoticeLbl")

local function showMessage(text)
	noticeLbl.Text = text
	UIAnimation.Notification(noticeFrame, {
		alsoFade = { noticeLbl },
		targetBackgroundTransparency = 0.1,
	})
end

ObbyLockedEvent.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "string" then return end
	showMessage(message)
end)
