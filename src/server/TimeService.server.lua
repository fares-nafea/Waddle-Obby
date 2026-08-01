--// Time Service
--// Place in: ServerScriptService
--// Times each player's run through each Obby (workspace.Stages child folder),
--// entirely server-side. Detects/saves new best times and reports them to
--// LeaderboardService. The server never trusts a client-sent time - every
--// elapsed value comes from os.clock() on this script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TimerEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TimerEvent")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObbyConfig"))
local Leaderboard = require(ServerScriptService:WaitForChild("LeaderboardService"))

-- activeRuns[player] = { obbyId = string, startTick = number }
local activeRuns = {}
-- separate debounce per touch part: a StopPart touch must never be blocked
-- by a StartPart debounce still cooling down from a few hundred ms earlier
-- (a legitimate finish can land well within 0.5s of the start on short obbys)
local startDebounce = {}
local stopDebounce = {}

--=============== BEST TIME (backed by the BestTimes folder DataService loads/saves) ===============--
local function getBestTimesFolder(player)
	local folder = player:WaitForChild("BestTimes", 10)
	if not folder then
		warn("[TimeService] " .. player.Name .. " has no BestTimes folder after 10s - DataService may not have loaded")
	end
	return folder
end

local function getBestTime(player, obbyId)
	local folder = getBestTimesFolder(player)
	local entry = folder and folder:FindFirstChild(obbyId)
	return entry and entry.Value or nil
end

local function setBestTime(player, obbyId, timeMs)
	local folder = getBestTimesFolder(player)
	if not folder then return end

	local entry = folder:FindFirstChild(obbyId)
	if not entry then
		entry = Instance.new("IntValue")
		entry.Name = obbyId
		entry.Parent = folder
	end
	entry.Value = timeMs
end

--=============== TIME FORMATTING (for server-side logging only) ===============--
local function formatSeconds(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%05.2f", minutes, secs)
end

--=============== SETUP ===============--
local function setupStage(stage)
	local obbyId = Config.getObbyId(stage.Name)
	local StartPart = stage:FindFirstChild("StartTimer")
	local StopPart = stage:FindFirstChild("StopTimer")
	local ExitPart = stage:FindFirstChild("ExitPart")

	if not ExitPart then
		warn(obbyId .. " is missing ExitPart")
		return
	end
	if not StartPart then
		warn(obbyId .. " is missing StartTimer")
		return
	end
	if not StopPart then
		warn(obbyId .. " is missing StopTimer")
		return
	end

	ExitPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local run = activeRuns[player]
		if not run or run.obbyId ~= obbyId then return end

		activeRuns[player] = nil
		TimerEvent:FireClient(player, "Reset", obbyId)
	end)

	StartPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- don't let anyone start until their real save data (best times) has loaded
		if not player:GetAttribute("DataLoaded") then return end

		if startDebounce[player] then return end
		startDebounce[player] = true

		activeRuns[player] = { obbyId = obbyId, startTick = os.clock() }
		TimerEvent:FireClient(player, "Start", obbyId)

		task.wait(0.5)
		startDebounce[player] = nil
	end)

	StopPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		if stopDebounce[player] then return end

		local run = activeRuns[player]
		if not run or run.obbyId ~= obbyId then return end

		stopDebounce[player] = true

		local elapsed = os.clock() - run.startTick
		activeRuns[player] = nil

		-- anti-exploit floor: no legitimate run can finish faster than this
		if elapsed < Config.getMinTime(obbyId) then
			warn(player.Name .. " rejected finish on " .. obbyId .. " (" .. formatSeconds(elapsed) .. " - too fast)")
			TimerEvent:FireClient(player, "Reset", obbyId)
			task.wait(0.5)
			stopDebounce[player] = nil
			return
		end

		local timeMs = math.floor(elapsed * 1000)
		print(player.Name .. " finished " .. obbyId .. " in " .. formatSeconds(elapsed))

		-- reward scales with how fast this run was relative to the Obby's TargetTime
		local reward = Config.getReward(obbyId, elapsed)
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local coins = leaderstats:FindFirstChild("Coins")
			if coins then
				coins.Value += reward
			end
		end

		local previousBest = getBestTime(player, obbyId)
		local isNewBest = (previousBest == nil) or (timeMs < previousBest)

		if isNewBest then
			setBestTime(player, obbyId, timeMs)
			task.spawn(Leaderboard.ReportTime, player, obbyId, timeMs)
		end

		local bestMs = isNewBest and timeMs or previousBest
		print(string.format("[TimeService] %s finished %s: time=%dms reward=%d previousBest=%s isNewBest=%s bestMs=%d",
			player.Name, obbyId, timeMs, reward, tostring(previousBest), tostring(isNewBest), bestMs))

		TimerEvent:FireClient(player, "Finish", obbyId, timeMs, reward, isNewBest, bestMs)

		task.wait(0.5)
		stopDebounce[player] = nil
	end)
end

local stages = workspace:FindFirstChild("Stages")
if stages then
	for _, stage in ipairs(stages:GetChildren()) do
		setupStage(stage)
	end
else
	warn("[TimeService] workspace.Stages not found - no Obbys set up")
end

--=============== RESET ON DEATH / LEAVE ===============--
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function()
			local run = activeRuns[player]
			activeRuns[player] = nil
			startDebounce[player] = nil
			stopDebounce[player] = nil

			if run then
				TimerEvent:FireClient(player, "Reset", run.obbyId)
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	activeRuns[player] = nil
	startDebounce[player] = nil
	stopDebounce[player] = nil
end)
