--// Data Service
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local store = DataStoreService:GetDataStore("PlayerData_v3")

local MAX_RETRIES = 5
local AUTOSAVE_EVERY = 60 -- seconds
local MAX_OBBY = 6 -- highest ObbyId in ObbyConfig.Overrides; keep in sync with it

--// SESSION LOCKING
--// Two servers must never hold the same player's data at the same time. If they
--// do, the older server's autosave overwrites the newer server's progress -
--// that's the classic Roblox rollback / item-duplication bug, and it usually
--// shows up on rejoins and teleports rather than in testing.
--//
--// Every write stamps the key with this server's SESSION_ID and the time, and a
--// server only ever writes to a key it still owns. The autosave loop refreshes
--// SessionStamp, so a stamp older than LOCK_STALE_AFTER means that server
--// crashed without releasing the lock and it's safe to take over.
local SESSION_ID = (game.JobId ~= "" and game.JobId) or HttpService:GenerateGUID(false)
local LOCK_STALE_AFTER = 180 -- seconds; 3 missed autosaves = the owner is gone
local LOCK_ATTEMPTS = 5      -- how many times to wait for a live lock to release
local LOCK_RETRY_WAIT = 3    -- seconds between those attempts

local sessionData = {}
local cantSave = {}

-- true if this server is allowed to write to `old` (nobody owns it, we already
-- own it, or the previous owner's lock has gone stale)
local function canClaim(old)
	if not old or not old.SessionId then return true end
	if old.SessionId == SESSION_ID then return true end
	return (os.time() - (old.SessionStamp or 0)) >= LOCK_STALE_AFTER
end

local function keyFor(player)
	return "player_" .. player.UserId
end

-- run a datastore call with retries
local function retry(fn)
	local attempts = 0
	while attempts < MAX_RETRIES do
		attempts += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn("[DataService] attempt " .. attempts .. " failed: " .. tostring(result))
		task.wait(2)
	end
	return false
end

local function defaultData()
	return {
		Coins = 0, Inventory = {}, Equipped = "", BestTimes = {}, UnlockedObby = 1,
		LastClaimTime = 0, DailyStreak = 0,
	}
end

-- one-time migration for saves written before the Sequential Obby Unlock
-- System existed: derive starting progress from BestTimes instead of
-- defaulting to 1, so a returning player who already beat Obby 4 isn't
-- relocked out of it. Never runs again once UnlockedObby is actually set.
local function migrateUnlockedObby(data)
	if data.UnlockedObby ~= nil then return end

	local highestCompleted = 0
	for obbyId in pairs(data.BestTimes) do
		local n = tonumber(obbyId)
		if n and n > highestCompleted then
			highestCompleted = n
		end
	end

	data.UnlockedObby = math.min(highestCompleted + 1, MAX_OBBY)
end

--=============== LOAD ===============--
-- Read + take ownership in a single UpdateAsync. This replaces the old GetAsync
-- because reading and locking have to be one atomic operation - with a separate
-- read there's a window where two servers both read the same data before either
-- claims it. Returns the player's data, or nil + a reason if we couldn't claim it.
local function claimData(player)
	local key = keyFor(player)

	for attempt = 1, LOCK_ATTEMPTS do
		local claimed

		local ok = retry(function()
			claimed = nil

			store:UpdateAsync(key, function(old)
				if not canClaim(old) then
					-- another live server owns this key - returning nil cancels the
					-- write, so we never touch data we don't own. `claimed` stays nil.
					return nil
				end

				local data = old or defaultData()
				data.Coins = data.Coins or 0
				data.Inventory = data.Inventory or {}
				data.Equipped = data.Equipped or ""
				data.BestTimes = data.BestTimes or {}
				migrateUnlockedObby(data)
				-- Daily Reward System fields, added after launch - old saves
				-- have neither, so this backfills "never claimed" once
				data.LastClaimTime = data.LastClaimTime or 0
				data.DailyStreak = data.DailyStreak or 0

				data.SessionId = SESSION_ID
				data.SessionStamp = os.time()

				claimed = data
				return data
			end)
		end)

		if not ok then
			return nil, "datastore request failed"
		end
		if claimed then
			return claimed
		end

		-- held by a live server: it's probably mid-shutdown and about to release
		if attempt < LOCK_ATTEMPTS then
			task.wait(LOCK_RETRY_WAIT)
		end
	end

	return nil, "data is locked by another server"
end

local function loadData(player)
	local data, reason = claimData(player)

	if not data then
		cantSave[player] = true
		warn("[DataService] LOAD FAILED for " .. player.Name .. " (" .. reason .. ") - progress won't save this session")
		return defaultData()
	end

	return data
end

-- hand the key back so a rejoin isn't blocked until the lock goes stale. Only
-- clears the lock if we're actually the owner, so it's safe to call blindly.
local function releaseKey(player)
	retry(function()
		store:UpdateAsync(keyFor(player), function(old)
			if old and old.SessionId == SESSION_ID then
				old.SessionId = nil
				return old
			end
			return nil
		end)
	end)
end

local function setupPlayer(player)
	local data = loadData(player)

	-- claimData can wait on a live lock, so the player may have already left by
	-- the time we get here. Building Instances for them would be pointless, and
	-- PlayerRemoving has already run (skipping the save, correctly, because
	-- DataLoaded was never set) - so release the lock here or it leaks.
	if player.Parent == nil then
		releaseKey(player)
		sessionData[player] = nil
		cantSave[player] = nil
		return
	end

	sessionData[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats

	leaderstats.Parent = player

	local inv = Instance.new("Folder")
	inv.Name = "Inventory"
	for _, itemName in ipairs(data.Inventory) do
		local b = Instance.new("BoolValue")
		b.Name = itemName
		b.Value = true
		b.Parent = inv
	end
	inv.Parent = player

	-- currently equipped trail (EquipService reads/writes this)
	local equipped = Instance.new("StringValue")
	equipped.Name = "EquippedTrail"
	equipped.Value = data.Equipped or ""
	equipped.Parent = player

	-- one IntValue per Obby (milliseconds) - TimeService reads/writes these
	local bestTimes = Instance.new("Folder")
	bestTimes.Name = "BestTimes"
	for obbyId, timeMs in pairs(data.BestTimes) do
		local entry = Instance.new("IntValue")
		entry.Name = obbyId
		entry.Value = timeMs
		entry.Parent = bestTimes
	end
	bestTimes.Parent = player

	-- highest ObbyId the player can currently enter - TeleportService gates
	-- Portal teleports on this, TimeService advances it on completion
	local unlockedObby = Instance.new("IntValue")
	unlockedObby.Name = "UnlockedObby"
	unlockedObby.Value = data.UnlockedObby
	unlockedObby.Parent = player

	-- unix timestamp (seconds) of the player's last Daily Reward claim; 0 = never
	-- claimed - DailyRewardService reads/writes this, entirely isolated from the
	-- rest of DataService otherwise
	local lastClaimTime = Instance.new("NumberValue")
	lastClaimTime.Name = "LastClaimTime"
	lastClaimTime.Value = data.LastClaimTime
	lastClaimTime.Parent = player

	-- consecutive Daily Reward claims - DailyRewardService reads/writes this
	local dailyStreak = Instance.new("IntValue")
	dailyStreak.Name = "DailyStreak"
	dailyStreak.Value = data.DailyStreak
	dailyStreak.Parent = player

	player:SetAttribute("DataLoaded", true)
	print("[DataService] loaded " .. player.Name .. " (" .. data.Coins .. " coins, " .. #data.Inventory .. " items)")
end

--=============== SAVE ===============--
-- releaseLock: pass true on the final save (leaving / shutdown) so the key is
-- freed immediately and the player can rejoin another server without waiting
-- LOCK_STALE_AFTER for the lock to expire.
local function saveData(player, releaseLock)
	-- NEVER save before the load finished. This function builds its payload by
	-- reading Instances (leaderstats, Inventory, EquippedTrail, BestTimes)
	-- starting from defaultData(), so if those Instances don't exist yet it
	-- writes 0 coins and an empty inventory straight over the player's real
	-- save. The window is real: loadData can spend seconds retrying while the
	-- autosave loop and PlayerRemoving are both free to fire.
	if not player:GetAttribute("DataLoaded") then
		return
	end

	if cantSave[player] then
		warn("[DataService] skipping save for " .. player.Name .. " (load had failed)")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local inv = player:FindFirstChild("Inventory")

	local data = defaultData()
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		data.Coins = coins.Value
	end
	if inv then
		for _, child in ipairs(inv:GetChildren()) do
			table.insert(data.Inventory, child.Name)
		end
	end

	local equipped = player:FindFirstChild("EquippedTrail")
	if equipped then
		data.Equipped = equipped.Value
	end

	local bestTimes = player:FindFirstChild("BestTimes")
	if bestTimes then
		for _, entry in ipairs(bestTimes:GetChildren()) do
			data.BestTimes[entry.Name] = entry.Value
		end
	end

	local unlockedObby = player:FindFirstChild("UnlockedObby")
	if unlockedObby then
		data.UnlockedObby = unlockedObby.Value
	end

	local lastClaimTime = player:FindFirstChild("LastClaimTime")
	if lastClaimTime then
		data.LastClaimTime = lastClaimTime.Value
	end

	local dailyStreak = player:FindFirstChild("DailyStreak")
	if dailyStreak then
		data.DailyStreak = dailyStreak.Value
	end

	-- A real UpdateAsync: the transform inspects `old` and refuses to write when
	-- this server no longer owns the key. (Returning `data` unconditionally
	-- ignored `old` entirely, which made this identical to SetAsync and left
	-- concurrent writes able to clobber each other.)
	local lostLock = false

	local ok = retry(function()
		lostLock = false

		store:UpdateAsync(keyFor(player), function(old)
			if old and old.SessionId and old.SessionId ~= SESSION_ID then
				lostLock = true
				return nil -- cancel the write; this data belongs to another server
			end

			if releaseLock then
				data.SessionId = nil
			else
				data.SessionId = SESSION_ID
			end
			data.SessionStamp = os.time()

			return data
		end)
	end)

	if lostLock then
		-- don't keep fighting a server that legitimately owns this player now
		cantSave[player] = true
		warn("[DataService] lost the session lock for " .. player.Name .. " - another server owns this data, save aborted")
		return
	end

	if ok then
		print("[DataService] saved " .. player.Name)
	else
		warn("[DataService] FAILED to save " .. player.Name)
	end
end

--=============== EVENTS ===============--
Players.PlayerAdded:Connect(setupPlayer)

-- catch anyone who was already in-game when the script started
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player, true) -- final save: write and release the lock
	sessionData[player] = nil
	cantSave[player] = nil
end)

-- autosave loop (crash insurance)
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_EVERY)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

-- save everyone on server shutdown
game:BindToClose(function()
	if RunService:IsStudio() then
		task.wait(1) -- give Studio a moment
	end
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(saveData, player, true) -- release locks so rejoins aren't blocked
	end
	task.wait(3) -- let the saves finish
end)
