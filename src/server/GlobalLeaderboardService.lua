--// Global Leaderboard Service (module)
--// Place in: ServerScriptService (ModuleScript)
--// Owns a single OrderedDataStore ranking every player worldwide by coins.
--// Reads totals from leaderstats.Coins - the same Instance DataService
--// creates and ShopService/DailyRewardService/TimeService already treat as
--// authoritative. Nothing here ever accepts a coin value from a client -
--// this module has no RemoteEvent at all, it's only required by
--// GlobalWorldLeaderboardService.server.lua, the same split
--// LeaderboardService.lua/WorldLeaderboardService.server.lua already use.
--//
--// Ranks by lifetime-highest coins, not current balance, via the same
--// UpdateAsync "keep the max" pattern LeaderboardService.ReportTime uses to
--// keep a best time (there it's <=/min, here it's >=/max) - so spending
--// coins in the Shop can never lower a player's rank.
--//
--// Writes are batched, not per-coin-change: OrderedDataStore has the same
--// per-minute write budget as any other DataStore, and Coins can change
--// several times a second while running an Obby. A Changed listener only
--// flags a player dirty (no DataStore call); a PushInterval loop flushes
--// whoever is dirty in one UpdateAsync each, and PlayerRemoving does one
--// final flush so a leave mid-interval doesn't drop a new high. Reads are
--// cached for CacheTTL; OnUpdated fires after a batch actually writes
--// something, so the world board can refresh instantly instead of only
--// polling (same idea as LeaderboardService.OnRecordUpdated).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GlobalLeaderboardConfig"))

local store = DataStoreService:GetOrderedDataStore(Config.StoreName)

local Leaderboard = {}

local updated = Instance.new("BindableEvent")
Leaderboard.OnUpdated = updated.Event

local dirty = {} -- player -> true, coins changed since last flush
local cache = { entries = {}, fetchedAt = 0 }

--=============== WRITE (batched) ===============--
local function flushPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then return end

	local key = tostring(player.UserId)
	local amount = coins.Value

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			if old and old >= amount then
				return old
			end
			return amount
		end)
	end)

	if not ok then
		warn("[GlobalLeaderboardService] failed to save rank for " .. player.Name .. ": " .. tostring(err))
		return
	end

	cache.fetchedAt = 0 -- invalidate so the next fetch picks up the new total
	updated:Fire()
end

local function flushDirty()
	local players = {}
	for player in pairs(dirty) do
		table.insert(players, player)
		dirty[player] = nil
	end

	for _, player in ipairs(players) do
		flushPlayer(player)
	end
end

local function hookPlayer(player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 10)

	-- claimData can take a while (session lock contention) or fail outright,
	-- same window DataService's own setupPlayer guards against; if Coins
	-- never shows up this player just never reports to the leaderboard
	if not coins then
		warn("[GlobalLeaderboardService] no Coins found for " .. player.Name .. " - not tracked on the global leaderboard")
		return
	end

	coins.Changed:Connect(function()
		dirty[player] = true
	end)

	dirty[player] = true -- report the starting total right away
end

--=============== READ (cached) ===============--
function Leaderboard.GetTop(count)
	if (os.clock() - cache.fetchedAt) < Config.CacheTTL then
		return cache.entries
	end

	local entries = {}

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count) -- false = descending, highest coins first
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

			table.insert(entries, { rank = rank, name = name, coins = item.value })
		end
	else
		warn("[GlobalLeaderboardService] failed to fetch the global leaderboard")
	end

	cache.entries = entries
	cache.fetchedAt = os.clock()
	return entries
end

--=============== EVENTS ===============--
Players.PlayerAdded:Connect(hookPlayer)

-- catch anyone who was already in-game when this module first loaded
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(hookPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	local wasDirty = dirty[player]
	dirty[player] = nil

	if wasDirty then
		flushPlayer(player) -- final write so a leave mid-interval isn't lost; PlayerRemoving can yield, same as DataService.saveData
	end
end)

--=============== BATCHED PUSH LOOP ===============--
task.spawn(function()
	while true do
		task.wait(Config.PushInterval)
		flushDirty()
	end
end)

return Leaderboard
