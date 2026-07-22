--// World Leaderboard Service
--// Place in: ServerScriptService
--// Wires up a manually-placed world leaderboard board in each Obby folder,
--// showing that Obby's Top N fastest times. The board itself (Part +
--// SurfaceGui + Frames + TextLabels) is a clone of
--// ReplicatedStorage.Shared.Templates.LeaderboardBoard that YOU place and
--// position by hand in Studio, named "Leaderboard", inside each Obby's
--// stage folder. This script does no placement or positioning of any
--// kind - it only finds that existing Part, clones the LeaderboardRow row
--// template into it, and updates TextLabel values. If a stage has no
--// Leaderboard part, it's skipped with a warning (never auto-created).
--// All data comes from LeaderboardService (the same OrderedDataStores
--// TimeService already reports into) - no datastore calls happen here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObbyConfig"))
local Leaderboard = require(ServerScriptService:WaitForChild("LeaderboardService"))

local rowTemplate = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Templates"):WaitForChild("LeaderboardRow")

local REFRESH_INTERVAL = 30 -- seconds; fallback poll on top of instant OnRecordUpdated refreshes

local TROPHY = utf8.char(0x1F3C6)
local GOLD = Color3.fromRGB(255, 208, 40)
local SILVER = Color3.fromRGB(191, 194, 199)
local BRONZE = Color3.fromRGB(205, 127, 50)
local DEFAULT_COLOR = Color3.new(1, 1, 1)

local function rankColor(rank)
	if rank == 1 then return GOLD end
	if rank == 2 then return SILVER end
	if rank == 3 then return BRONZE end
	return DEFAULT_COLOR
end

-- ms -> "00:24.35" (same format ObbyClient/TimeService use)
local function formatMs(ms)
	local totalSeconds = ms / 1000
	local minutes = math.floor(totalSeconds / 60)
	local secs = totalSeconds % 60
	return string.format("%02d:%05.2f", minutes, secs)
end

--=============== SETUP / REFRESH ===============--
-- no placement logic here by design: the "Leaderboard" Part (a clone of
-- Templates.LeaderboardBoard) must already exist in the stage folder, at
-- whatever position/rotation it was hand-placed at in Studio. This script
-- never moves it and never creates one.
local boards = {} -- obbyId -> { list = Frame, empty = TextLabel }

local function setupStage(stage)
	local obbyId = Config.getObbyId(stage.Name)

	local part = stage:FindFirstChild("Leaderboard")
	if not part then
		warn("[WorldLeaderboardService] " .. obbyId .. " has no Leaderboard part - "
			.. "place a clone of Templates.LeaderboardBoard in this stage's folder, named \"Leaderboard\"")
		return
	end

	local surfaceGui = part:FindFirstChild("WorldLeaderboardGui")
	local board = surfaceGui and surfaceGui:FindFirstChild("Board")
	if not board then
		warn("[WorldLeaderboardService] " .. obbyId .. "'s Leaderboard part is missing WorldLeaderboardGui.Board - "
			.. "make sure it's an unmodified clone of Templates.LeaderboardBoard")
		return
	end

	board.Subtitle.Text = Config.getDisplayName(obbyId)

	boards[obbyId] = { list = board.List, empty = board.List:WaitForChild("EmptyLbl") }
end

local function renderBoard(obbyId)
	local board = boards[obbyId]
	if not board then return end

	local entries = Leaderboard.GetTop(obbyId, Config.getLeaderboardSize(obbyId))

	for _, child in ipairs(board.list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	board.empty.Visible = #entries == 0

	for _, entry in ipairs(entries) do
		local row = rowTemplate:Clone()
		row.LayoutOrder = entry.rank
		row.Size = UDim2.new(1, 0, 0.094, 0) -- scale-based: 10 rows fit any board resolution

		local color = rankColor(entry.rank)

		local rankLbl = row:WaitForChild("RankLbl")
		rankLbl.Text = (entry.rank == 1 and (TROPHY .. " ") or "") .. "#" .. entry.rank
		rankLbl.TextColor3 = color

		local nameLbl = row:WaitForChild("NameLbl")
		nameLbl.Text = entry.name
		nameLbl.TextColor3 = (entry.rank <= 3) and color or Color3.new(1, 1, 1)

		local timeLbl = row:WaitForChild("TimeLbl")
		timeLbl.Text = formatMs(entry.timeMs)
		timeLbl.TextColor3 = color

		row.Parent = board.list
	end
end

local function refreshAll()
	for obbyId in pairs(boards) do
		renderBoard(obbyId)
	end
end

--=============== INIT ===============--
local stages = workspace:FindFirstChild("Stages")
if stages then
	for _, stage in ipairs(stages:GetChildren()) do
		setupStage(stage)
	end
	refreshAll()

	-- new Obby folders added after startup (e.g. streamed in) get a board too
	stages.ChildAdded:Connect(function(stage)
		task.defer(function()
			setupStage(stage)
			renderBoard(stage.Name)
		end)
	end)
else
	warn("[WorldLeaderboardService] workspace.Stages not found - no world leaderboards set up")
end

-- instant update whenever any Obby gets a new best time
Leaderboard.OnRecordUpdated:Connect(renderBoard)

-- periodic fallback (catches rank/name drift the instant path wouldn't see)
task.spawn(function()
	while true do
		task.wait(REFRESH_INTERVAL)
		refreshAll()
	end
end)
