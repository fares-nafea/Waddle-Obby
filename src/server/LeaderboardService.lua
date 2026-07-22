--// Leaderboard Service
--// Place in: ServerScriptService (ModuleScript)
--// Owns one OrderedDataStore per Obby (scope = ObbyId) so each Obby has its
--// own independently sorted "fastest time" ranking. Value stored = time in
--// milliseconds, ascending sort = fastest first.
--//
--// Required by TimeService.server.lua to report new best times, and sets up
--// its own RemoteEvent listener so the client can request a live leaderboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local LeaderboardEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LeaderboardEvent")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObbyConfig"))

local STORE_NAME = "ObbyBestTimes_v1"
local CACHE_TTL = 20        -- seconds a fetched top-list stays valid before refetching
local REQUEST_COOLDOWN = 2  -- min seconds between leaderboard requests per player

local Leaderboard = {}

-- fired (obbyId) whenever a report actually lands a new best time, so other
-- systems (e.g. WorldLeaderboardService) can refresh instantly instead of
-- polling
local recordUpdated = Instance.new("BindableEvent")
Leaderboard.OnRecordUpdated = recordUpdated.Event

local orderedStores = {}    -- obbyId -> OrderedDataStore
local cache = {}            -- obbyId -> { entries = {...}, fetchedAt = os.clock() }
local lastRequest = {}       -- player -> os.clock()

-- OrderedDataStore scopes only allow a limited character set - keep it safe
local function sanitize(id)
	return (id:gsub("[^%w_%-]", "_"))
end

local function getStore(obbyId)
	local store = orderedStores[obbyId]
	if not store then
		store = DataStoreService:GetOrderedDataStore(STORE_NAME, sanitize(obbyId))
		orderedStores[obbyId] = store
	end
	return store
end

-- true if some workspace.Stages folder currently resolves to this ObbyId -
-- used to reject bogus obbyId strings a client might send. Folder names are
-- just labels (e.g. "Stage 1"); Config.getObbyId extracts the real ObbyId,
-- so this can't do a direct FindFirstChild(obbyId) lookup
local function isKnownObby(obbyId)
	local stages = Workspace:FindFirstChild("Stages")
	if not stages then return false end

	for _, stage in ipairs(stages:GetChildren()) do
		if Config.getObbyId(stage.Name) == obbyId then
			return true
		end
	end
	return false
end

-- record a new best time; safe to call even if it isn't actually better,
-- UpdateAsync only lowers the stored value, never raises it
function Leaderboard.ReportTime(player, obbyId, timeMs)
	if not isKnownObby(obbyId) then return end

	local store = getStore(obbyId)
	local key = tostring(player.UserId)

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			if old and old <= timeMs then
				return old
			end
			return timeMs
		end)
	end)

	if not ok then
		warn("[LeaderboardService] failed to report time for " .. player.Name .. ": " .. tostring(err))
		return
	end

	cache[obbyId] = nil -- invalidate so the next fetch picks up the new entry
	recordUpdated:Fire(obbyId)
end

-- fetch (with caching) the top N {rank, name, timeMs} for an Obby
function Leaderboard.GetTop(obbyId, count)
	if not isKnownObby(obbyId) then return {} end

	local cached = cache[obbyId]
	if cached and (os.clock() - cached.fetchedAt) < CACHE_TTL then
		return cached.entries
	end

	local store = getStore(obbyId)
	local entries = {}

	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, count)
	end)

	if ok and pages then
		local page = pages:GetCurrentPage()
		for rank, item in ipairs(page) do
			local userId = tonumber(item.key)
			local name = "Unknown"

			if userId then
				local nameOk, resolvedName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
				if nameOk then
					name = resolvedName
				end
			end

			table.insert(entries, { rank = rank, name = name, timeMs = item.value })
		end
	else
		warn("[LeaderboardService] failed to fetch leaderboard for " .. obbyId)
	end

	cache[obbyId] = { entries = entries, fetchedAt = os.clock() }
	return entries
end

--=============== CLIENT REQUESTS ===============--
LeaderboardEvent.OnServerEvent:Connect(function(player, obbyId)
	if type(obbyId) ~= "string" then return end
	if not isKnownObby(obbyId) then return end

	local last = lastRequest[player]
	if last and (os.clock() - last) < REQUEST_COOLDOWN then return end
	lastRequest[player] = os.clock()

	local entries = Leaderboard.GetTop(obbyId, Config.getLeaderboardSize(obbyId))

	LeaderboardEvent:FireClient(player, "Data", obbyId, entries)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

return Leaderboard
