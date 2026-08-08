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
local BoostService = require(ServerScriptService:WaitForChild("BoostService"))

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

--=============== SEQUENTIAL OBBY UNLOCK (backed by the UnlockedObby IntValue DataService loads/saves) ===============--
-- true if `obbyId` is currently reachable for `player`. TeleportService is
-- the normal gate (it blocks the Portal teleport before a player can ever
-- touch this stage's parts) - this is defense-in-depth for anyone who
-- reaches a StartTimer some other way (noclip/fly), same anti-exploit
-- posture as the MinTime floor below.
local function isUnlocked(player, obbyId)
	local unlockedObby = player:FindFirstChild("UnlockedObby")
	local n = tonumber(obbyId)
	if not unlockedObby or not n then return true end
	return n <= unlockedObby.Value
end

-- advances UnlockedObby to whatever finishing `obbyId` unlocks next, if it's
-- further than the player already has. Never regresses; no-ops past the
-- last configured Obby (Config.getUnlocksNext returns nil there).
local function unlockNext(player, obbyId)
	local unlockedObby = player:FindFirstChild("UnlockedObby")
	if not unlockedObby then return end

	local nextId = Config.getUnlocksNext(obbyId)
	local nextNum = nextId and tonumber(nextId)
	if nextNum and nextNum > unlockedObby.Value then
		unlockedObby.Value = nextNum
	end
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

		-- normally unreachable (TeleportService already blocks the Portal into a
		-- locked Obby) - this only catches someone who got here another way
		if not isUnlocked(player, obbyId) then return end

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

		-- reward scales with how fast this run was relative to the Obby's TargetTime -
		-- GrantCoins applies the 2X Coins multiplier (if active) and returns the
		-- actual amount awarded, so everything below (the print, the "Finish"
		-- payload) reports the real, possibly-doubled number
		local baseReward = Config.getReward(obbyId, elapsed)
		local reward = BoostService.GrantCoins(player, baseReward)

		-- Sequential Obby Unlock: any legitimate completion counts, not just a
		-- new best - a replay of an already-cleared Obby shouldn't matter, but
		-- the first clear must, regardless of how fast it was
		unlockNext(player, obbyId)

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
