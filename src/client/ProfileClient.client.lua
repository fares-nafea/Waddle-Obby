--// Profile Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Opens/closes StarterGui.ProfileUI.ProfileFrame and renders the player's own
--// data - username, avatar, Coins, equipped Trail, owned Trail count, and each
--// Obby's completion state. Every value comes from Instances DataService
--// already loads/saves (leaderstats.Coins, Inventory, EquippedTrail, BestTimes) -
--// this script only reads them (WaitForChild + .Changed/ChildAdded), it never
--// creates or writes to a single one. No RemoteEvents needed: those Instances
--// already replicate to the client the same way ShopClient reads them.
--//
--// Obby Progress: the Sequential Obby Unlock System (TeleportService +
--// TimeService) gates entry via the player's UnlockedObby IntValue - an
--// ObbyId is locked until UnlockedObby reaches it, unlocked once reachable,
--// and completed the instant BestTimes has an IntValue for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ButtonClick = SoundService:WaitForChild("ButtonClick")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObbyConfig = require(Shared:WaitForChild("ObbyConfig"))
local UIAnimation = require(Shared:WaitForChild("UIAnimation"))
local UIDisable = require(Shared:WaitForChild("UIDisable"))

local OBBY_COUNT = 6

local inventory = player:WaitForChild("Inventory")
local equippedTrail = player:WaitForChild("EquippedTrail", 10)
local bestTimes = player:WaitForChild("BestTimes", 10)
local unlockedObby = player:WaitForChild("UnlockedObby", 10)

--============================ GUI ============================--
local profileGui = playerGui:WaitForChild("ProfileUI")
local openButton = profileGui:WaitForChild("OpenButton")
local dim = profileGui:WaitForChild("Dim")
local profileFrame = profileGui:WaitForChild("ProfileFrame")

local header = profileFrame:WaitForChild("Header")
local closeBtn = header:WaitForChild("CloseBtn")

local content = profileFrame:WaitForChild("Content")

local playerCard = content:WaitForChild("PlayerCard")
local avatar = playerCard:WaitForChild("Avatar")
local username = playerCard:WaitForChild("Username")

local currencyCard = content:WaitForChild("CurrencyCard")
local coinsAmount = currencyCard:WaitForChild("CoinsAmount")

local trailCard = content:WaitForChild("TrailCard")
local equippedLbl = trailCard:WaitForChild("EquippedLbl")
local ownedCountLbl = trailCard:WaitForChild("OwnedCountLbl")

local gui1 = playerGui:WaitForChild("BoostUI")
local gui2 = playerGui:WaitForChild("ShopUI")
local gui3 = playerGui:WaitForChild("DailyRewardGiftButtonUI")

local openButton1 = gui3:WaitForChild("GiftButton")
local openButton2 = gui1:WaitForChild("OpenButton")
local openButton3 = gui2:WaitForChild("OpenButton")
local openButton4 = profileGui:WaitForChild("OpenButton")

local badge = gui1:WaitForChild("StatusBadge")

dim.Visible = false
profileFrame.Visible = false

-- one row per Obby, found under content by "ObbyRow" .. ObbyId (built in Studio,
-- same lookup-by-name approach ShopClient uses for TrailConfig cards)
local obbyRows = {}
for i = 1, OBBY_COUNT do
	local obbyId = tostring(i)
	local row = content:WaitForChild("ObbyRow" .. obbyId, 5)
	if row then
		obbyRows[obbyId] = {
			frame = row,
			status = row:WaitForChild("StatusLbl"),
			time = row:WaitForChild("TimeLbl"),
		}
	else
		warn("[ProfileClient] content.ObbyRow" .. obbyId .. " not found - can't show Obby " .. obbyId)
	end
end

--============================ FORMATTING ============================--
-- ms -> "18.42s" (the Profile's own short format; the mm:ss.ms format used by
-- ObbyClient/WorldLeaderboardService is left untouched elsewhere)
local function formatSecondsShort(ms)
	return string.format("%.2fs", ms / 1000)
end

--============================ PLAYER SECTION ============================--
local function refreshPlayerInfo()
	username.Text = player.Name
end

task.spawn(function()
	local ok, content0 = pcall(Players.GetUserThumbnailAsync, Players, player.UserId,
		Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	if ok then
		avatar.Image = content0
	else
		warn("[ProfileClient] failed to fetch avatar thumbnail for " .. player.Name)
	end
end)

--============================ CURRENCY SECTION ============================--
local function refreshCoins()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	coinsAmount.Text = coins and tostring(coins.Value) or "0"
end

-- Coins is created by DataService a moment after PlayerAdded, same wait
-- pattern ShopClient uses for its coin counter
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 10)
	if coins then
		coins.Changed:Connect(refreshCoins)
	end
	refreshCoins()
end)

--============================ TRAIL SECTION ============================--
local function refreshTrail()
	local equippedName = equippedTrail and equippedTrail.Value
	equippedLbl.Text = "Equipped: " .. ((equippedName and equippedName ~= "") and equippedName or "None")
	ownedCountLbl.Text = "Owned Trails: " .. #inventory:GetChildren()
end

--============================ OBBY PROGRESS SECTION ============================--
local DONE_COLOR = Color3.fromRGB(78, 214, 144)
local UNLOCKED_COLOR = Color3.fromRGB(108, 140, 255)
local LOCKED_COLOR = Color3.fromRGB(125, 133, 156)

local function refreshObbies()
	local unlockedValue = (unlockedObby and unlockedObby.Value) or 1

	for obbyId, row in pairs(obbyRows) do
		local displayName = ObbyConfig.getDisplayName(obbyId)
		local entry = bestTimes and bestTimes:FindFirstChild(obbyId)
		local obbyNum = tonumber(obbyId)

		if entry then
			row.status.Text = displayName .. " ✅"
			row.status.TextColor3 = DONE_COLOR
			row.time.Text = "Best Time: " .. formatSecondsShort(entry.Value)
		elseif obbyNum and obbyNum <= unlockedValue then
			row.status.Text = displayName .. " 🔓"
			row.status.TextColor3 = UNLOCKED_COLOR
			row.time.Text = "Not completed yet"
		else
			row.status.Text = displayName .. " 🔒"
			row.status.TextColor3 = LOCKED_COLOR
			row.time.Text = "Locked"
		end
	end
end

--============================ REFRESH ALL ============================--
local function refreshAll()
	refreshPlayerInfo()
	refreshCoins()
	refreshTrail()
	refreshObbies()
end

--============================ OPEN / CLOSE ============================--
local function openProfile()
	refreshAll()
	UIDisable.DisableTop(badge)
	UIDisable.Disable(openButton1, openButton2, openButton3, openButton4)
	if UIAnimation.Open(profileFrame, dim) then
		ButtonClick:Play()
	end
end

local function closeProfile()
	UIDisable.AppearTop(badge)
	UIDisable.Appear(openButton1, openButton2, openButton3, openButton4)
	if UIAnimation.Close(profileFrame, dim) then
		ButtonClick:Play()
	end
end

openButton.MouseButton1Click:Connect(function()
	task.wait(0.1)
	if profileFrame.Visible then
		closeProfile()
	else
		openProfile()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
    task.wait(0.1)
    closeProfile()
end)
dim.MouseButton1Click:Connect(function()
    task.wait(0.1)
    closeProfile()
end)

UIAnimation.ButtonPress(openButton)
UIAnimation.ButtonPress(closeBtn)

--============================ LIVE REFRESH ============================--
inventory.ChildAdded:Connect(refreshTrail)

if equippedTrail then
	equippedTrail.Changed:Connect(refreshTrail)
end

if bestTimes then
	local function hookEntry(entry)
		entry.Changed:Connect(refreshObbies)
	end

	for _, entry in ipairs(bestTimes:GetChildren()) do
		hookEntry(entry)
	end

	bestTimes.ChildAdded:Connect(function(entry)
		hookEntry(entry)
		refreshObbies()
	end)
end

if unlockedObby then
	unlockedObby.Changed:Connect(refreshObbies)
end
