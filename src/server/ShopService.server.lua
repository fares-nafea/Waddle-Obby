--// Shop Service
--// Place in: ServerScriptService
--// Handles buying cosmetic Trails (StarterGui.ShopUI talks to this through
--// ReplicatedStorage.Remotes.ShopRemote). Server-authoritative: price and
--// ownership are always re-checked here, never trusted from the client.
--//
--// This is Buy-only. Trails aren't Tools - they're visual attachments handled
--// entirely by the existing EquipService (same EquipEvent), so ShopService
--// never grants Backpack items and never touches equip state. Buying just
--// marks a trail as owned in Inventory;
--// EquipService is the single place that decides what's actually equipped,
--// which is also what already guarantees only one trail at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRemote")
local TrailConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrailConfig"))

local debounce = {}

local function getInventory(player)
	return player:WaitForChild("Inventory", 10)
end

local function isOwned(player, trailName)
	local inv = getInventory(player)
	return inv ~= nil and inv:FindFirstChild(trailName) ~= nil
end

local function tryBuy(player, trailName)
	if debounce[player] then return end
	debounce[player] = true

	local item = TrailConfig.get(trailName)
	if not item then
		debounce[player] = nil
		return
	end

	if isOwned(player, trailName) then
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
		ShopRemote:FireClient(player, "NotEnoughCoins", trailName, item.Price, coins.Value)
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
	owned.Name = trailName
	owned.Value = true
	owned.Parent = inv

	ShopRemote:FireClient(player, "Bought", trailName)

	task.wait(0.3)
	debounce[player] = nil
end

ShopRemote.OnServerEvent:Connect(function(player, action, trailName)
	if type(trailName) ~= "string" then return end

	if action == "Buy" then
		tryBuy(player, trailName)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	debounce[player] = nil
end)
