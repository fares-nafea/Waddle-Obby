--// Data Service
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local MAX_RETRIES = 5
local AUTOSAVE_EVERY = 60 -- seconds

local sessionData = {}
local cantSave = {}

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
	return { Coins = 0, Inventory = {}, Equipped = "", BestTimes = {}, EquippedItems = {} }
end

--=============== LOAD ===============--
local function loadData(player)
	local loaded
	local ok = retry(function()
		loaded = store:GetAsync(keyFor(player))
	end)

	if not ok then
		cantSave[player] = true
		warn("[DataService] LOAD FAILED for " .. player.Name .. " - progress won't save this session")
		return defaultData()
	end

	if loaded == nil then
		return defaultData()
	end

	loaded.Coins = loaded.Coins or 0
	loaded.Inventory = loaded.Inventory or {}
	loaded.Equipped = loaded.Equipped or ""
	loaded.BestTimes = loaded.BestTimes or {}
	loaded.EquippedItems = loaded.EquippedItems or {}
	return loaded
end

local function setupPlayer(player)
	local data = loadData(player)
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

	-- shop items currently equipped (ShopService reads/writes these) - kept
	-- separate from the single EquippedTrail slot above since a player can
	-- have more than one shop item equipped at once
	local equippedItems = Instance.new("Folder")
	equippedItems.Name = "EquippedItems"
	for _, itemName in ipairs(data.EquippedItems) do
		local b = Instance.new("BoolValue")
		b.Name = itemName
		b.Value = true
		b.Parent = equippedItems
	end
	equippedItems.Parent = player

	player:SetAttribute("DataLoaded", true)
	print("[DataService] loaded " .. player.Name .. " (" .. data.Coins .. " coins, " .. #data.Inventory .. " items)")
end

--=============== SAVE ===============--
local function saveData(player)
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

	local equippedItems = player:FindFirstChild("EquippedItems")
	if equippedItems then
		for _, entry in ipairs(equippedItems:GetChildren()) do
			table.insert(data.EquippedItems, entry.Name)
		end
	end

	local ok = retry(function()
		-- UpdateAsync is safer than SetAsync against concurrent writes
		store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)

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
	saveData(player)
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
		task.spawn(saveData, player)
	end
	task.wait(3) -- let the saves finish
end)
