--// Shop Service
--// Place in: ServerScriptService
--// Handles buying and equipping Shop items (StarterGui.ShopUI talks to this
--// through ReplicatedStorage.Remotes.ShopRemote). Server-authoritative: price
--// and ownership are always re-checked here, never trusted from the client.
--// Tools are the exact pre-built templates in ServerStorage.Items - this
--// script only clones them, it never Instance.new()s a Tool from scratch.
--//
--// Ownership/equip state is tracked the same way EggService/EquipService
--// already track Inventory/EquippedTrail: small per-player BoolValue/Folder
--// instances created under the Player at runtime (there's no way to
--// "pre-build in Studio" a value for a player who hasn't joined yet), then
--// saved/loaded by DataService exactly like Inventory already is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRemote")
local ItemsFolder = ServerStorage:WaitForChild("Items")
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local debounce = {}

local function getInventory(player)
	return player:WaitForChild("Inventory", 10)
end

local function getEquippedItems(player)
	return player:WaitForChild("EquippedItems", 10)
end

local function isOwned(player, itemName)
	local inv = getInventory(player)
	return inv ~= nil and inv:FindFirstChild(itemName) ~= nil
end

local function isEquipped(player, itemName)
	local equipped = getEquippedItems(player)
	return equipped ~= nil and equipped:FindFirstChild(itemName) ~= nil
end

-- give the player their own copy of the pre-built tool - always cloned from
-- the one designer-configured template in ServerStorage.Items
local function grantTool(player, itemName)
	local template = ItemsFolder:FindFirstChild(itemName)
	if not template then
		warn("[ShopService] ServerStorage.Items." .. itemName .. " not found - can't grant it")
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack and not backpack:FindFirstChild(itemName) then
		template:Clone().Parent = backpack
	end

	-- StarterGear is what makes the tool survive the player's next respawn
	-- without this script having to re-grant it every single CharacterAdded
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear and not starterGear:FindFirstChild(itemName) then
		template:Clone().Parent = starterGear
	end
end

local function revokeTool(player, itemName)
	local locations = { player:FindFirstChild("Backpack"), player:FindFirstChild("StarterGear"), player.Character }
	for _, container in ipairs(locations) do
		local tool = container and container:FindFirstChild(itemName)
		if tool then tool:Destroy() end
	end
end

local function setEquipped(player, itemName, equipped)
	local folder = getEquippedItems(player)
	if not folder then return end

	local entry = folder:FindFirstChild(itemName)

	if equipped then
		if not entry then
			entry = Instance.new("BoolValue")
			entry.Name = itemName
			entry.Value = true
			entry.Parent = folder
		end
		grantTool(player, itemName)
	else
		if entry then entry:Destroy() end
		revokeTool(player, itemName)
	end
end

local function tryBuy(player, itemName)
	if debounce[player] then return end
	debounce[player] = true

	local item = ShopConfig.get(itemName)
	if not item then
		debounce[player] = nil
		return
	end

	if isOwned(player, itemName) then
		debounce[player] = nil
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then
		debounce[player] = nil
		return
	end

	if coins.Value < item.Price then
		ShopRemote:FireClient(player, "NotEnoughCoins", itemName, item.Price, coins.Value)
		debounce[player] = nil
		return
	end

	local inv = getInventory(player)
	if not inv then
		debounce[player] = nil
		return
	end

	coins.Value -= item.Price

	local owned = Instance.new("BoolValue")
	owned.Name = itemName
	owned.Value = true
	owned.Parent = inv

	ShopRemote:FireClient(player, "Bought", itemName)

	task.wait(0.3)
	debounce[player] = nil
end

local function tryToggleEquip(player, itemName)
	if not ShopConfig.get(itemName) then return end
	if not isOwned(player, itemName) then return end

	local nowEquipped = not isEquipped(player, itemName)
	setEquipped(player, itemName, nowEquipped)

	ShopRemote:FireClient(player, "Equipped", itemName, nowEquipped)
end

ShopRemote.OnServerEvent:Connect(function(player, action, itemName)
	if type(itemName) ~= "string" then return end

	if action == "Buy" then
		tryBuy(player, itemName)
	elseif action == "Equip" then
		tryToggleEquip(player, itemName)
	end
end)

-- re-grant any already-equipped tool on join (once DataService has loaded
-- Inventory/EquippedItems onto the player) and on every respawn
local function hookCharacter(player)
	player.CharacterAdded:Connect(function()
		local equipped = getEquippedItems(player)
		if not equipped then return end
		for _, entry in ipairs(equipped:GetChildren()) do
			grantTool(player, entry.Name)
		end
	end)
end

Players.PlayerAdded:Connect(hookCharacter)
for _, player in ipairs(Players:GetPlayers()) do
	hookCharacter(player)
	if player.Character then
		local equipped = getEquippedItems(player)
		if equipped then
			for _, entry in ipairs(equipped:GetChildren()) do
				grantTool(player, entry.Name)
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	debounce[player] = nil
end)
