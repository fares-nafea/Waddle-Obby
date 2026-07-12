--// Egg Service (Day 7)
--// Place in: ServerScriptService
--// Handles buying an egg with coins and rolling a random reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EggEvent")

--============================ CONFIG ============================--
local EGG_COST = 100            -- coins per egg (about one obby run)
local DUPLICATE_REFUND = 0.25   -- refund this fraction if you roll a dupe

-- Reward pool. Higher weight = more common.
-- Add/rename freely — this is what your viewers vote on.
local REWARDS = {
	{ name = "Icy Blue Penguin", rarity = "Common",    weight = 50 },
	{ name = "Frost Trail",      rarity = "Common",    weight = 40 },
	{ name = "Golden Penguin",   rarity = "Rare",      weight = 20 },
	{ name = "Rainbow Trail",    rarity = "Epic",      weight = 8  },
	{ name = "Mythic Emperor",   rarity = "Legendary", weight = 2  },
}
--===============================================================--

local debounce = {}

local function getCoins(player)
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Coins")
end

local function getInventory(player)
	local inv = player:FindFirstChild("Inventory")
	if not inv then
		inv = Instance.new("Folder")
		inv.Name = "Inventory"
		inv.Parent = player
	end
	return inv
end

local function rollReward()
	local total = 0
	for _, r in ipairs(REWARDS) do
		total += r.weight
	end

	local pick = math.random() * total
	local acc = 0
	for _, r in ipairs(REWARDS) do
		acc += r.weight
		if pick <= acc then
			return r
		end
	end
	return REWARDS[1]
end

local function tryBuy(player)
	if debounce[player] then return end
	debounce[player] = true

	local coins = getCoins(player)
	if not coins then
		debounce[player] = nil
		return
	end

	if coins.Value < EGG_COST then
		EggEvent:FireClient(player, "NotEnough", EGG_COST, coins.Value)
		debounce[player] = nil
		return
	end

	-- charge first, then roll
	coins.Value -= EGG_COST

	local reward = rollReward()
	local inv = getInventory(player)

	if inv:FindFirstChild(reward.name) then
		-- already owned: give a small refund so dupes don't feel bad
		local refund = math.floor(EGG_COST * DUPLICATE_REFUND)
		coins.Value += refund
		EggEvent:FireClient(player, "Duplicate", reward.name, reward.rarity, refund)
	else
		local owned = Instance.new("BoolValue")
		owned.Name = reward.name
		owned.Value = true
		owned.Parent = inv
		EggEvent:FireClient(player, "Reward", reward.name, reward.rarity)
	end

	task.wait(0.5)
	debounce[player] = nil
end

-- Hook up the egg in the lobby.
-- Put a Part (or Model) named "Egg" in Workspace with a ProximityPrompt inside it.
local egg = workspace:WaitForChild("Egg")
local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)

if not prompt then
	warn("[EggService] No ProximityPrompt found inside 'Egg'. Add one to enable buying.")
	return
end

prompt.ActionText = "Buy Egg"
prompt.ObjectText = EGG_COST .. " Coins"
prompt.HoldDuration = 0.3

prompt.Triggered:Connect(function(player)
	tryBuy(player)
end)

Players.PlayerRemoving:Connect(function(player)
	debounce[player] = nil
end)
