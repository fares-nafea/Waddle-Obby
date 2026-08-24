--// Shop Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Opens/closes StarterGui.ShopUI.ShopFrame, wires the Buy button on each
--// trail card (found under ShopFrame.Grid), the Close button, and the live
--// coin counter. Every object referenced below already
--// exists (built in Studio) - this script only finds them (WaitForChild) and
--// reads/writes their properties; it never creates an Instance.
--//
--// The Shop sells ONLY cosmetic trails. Buying goes through ShopRemote (server
--// checks Coins, marks it owned). Equipping goes through EquipEvent -
--// EquipService is the one place that enforces "only one trail at a time"
--// (via the single EquippedTrail value), so this script never tracks equip
--// state itself, just reads it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService =  game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRemote")
local EquipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipEvent")
local TrailConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrailConfig"))

local ButtonClick = SoundService:WaitForChild("ButtonClick")

local inventory = player:WaitForChild("Inventory")
local equippedTrail = player:WaitForChild("EquippedTrail", 10)
local EQUIP_IMAGE = "rbxassetid://92424482846330"
local UNEQUIP_IMAGE = "rbxassetid://110451088897225"

--============================ GUI ============================--
local shopGui = playerGui:WaitForChild("ShopUI")
local openButton = shopGui:WaitForChild("OpenButton")
local dim = shopGui:WaitForChild("Dim")
local shopFrame = shopGui:WaitForChild("ShopFrame")

local header = shopFrame:WaitForChild("Header")
local headerRight = header:WaitForChild("HeaderRight")
local closeBtn = headerRight:WaitForChild("CloseBtn")
local coinPill = headerRight:WaitForChild("CoinPill")
local coinAmount = coinPill:WaitForChild("CoinAmount")

local grid = shopFrame:WaitForChild("Grid")

dim.Visible = false
shopFrame.Visible = false

-- one card per TrailConfig entry, found under Grid by its configured CardName -
-- add a new trail to TrailConfig plus its card in Studio and it shows up here automatically
local cards = {}
for _, item in ipairs(TrailConfig.Items) do
	local card = grid:WaitForChild(item.CardName, 5)
	if card then
		cards[item.Name] = card
	else
		warn("[ShopClient] Grid." .. item.CardName .. " not found - can't sell " .. item.Name)
	end
end

local function isOwned(trailName)
	return inventory:FindFirstChild(trailName) ~= nil
end

local function isEquipped(trailName)
	return equippedTrail ~= nil and equippedTrail.Value == trailName
end

local function refreshCard(trailName, card)

	local item = TrailConfig.get(trailName)
	if not item then
		return
	end

	local buyButton = card:WaitForChild("BuyButton")
	local equipButton = card:WaitForChild("EquipButton")
	local priceLabel = card:WaitForChild("PriceLabel")

	priceLabel.Text = item.Price .. " Coins"

	local owned = isOwned(trailName)
	local equipped = isEquipped(trailName)

	-- Buy
	buyButton.Visible = not owned

	-- Equip / Unequip
	equipButton.Visible = owned

	if equipped then
		equipButton.Image = UNEQUIP_IMAGE
	else
		equipButton.Image = EQUIP_IMAGE
	end

end


local function refreshAll()
	for trailName, card in pairs(cards) do
		refreshCard(trailName, card)
	end
end

--============================ COIN COUNTER ============================--
local function refreshCoins()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	coinAmount.Text = coins and tostring(coins.Value) or "0"
end

-- Coins is created by DataService a moment after PlayerAdded, so this waits
-- for it in the background instead of blocking the rest of the script
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 10)
	if coins then
		coins.Changed:Connect(refreshCoins)
	end
	refreshCoins()
end)

--============================ OPEN / CLOSE ============================--

local function openShop()

	if shopFrame.Visible then
		return
	end

	refreshAll()
	refreshCoins()

	ButtonClick:Play()
	dim.Visible = true
	shopFrame.Visible = true

end

local function closeShop()

	if not shopFrame.Visible then
		return
	end

	ButtonClick:Play()
	shopFrame.Visible = false
	dim.Visible = false

end

openButton.MouseButton1Click:Connect(function()

	if shopFrame.Visible then
		closeShop()
	else
		openShop()
	end

end)

closeBtn.MouseButton1Click:Connect(closeShop)

dim.MouseButton1Click:Connect(closeShop)

--============================ BUTTON WIRING ============================--
for trailName, card in pairs(cards) do
	card:WaitForChild("BuyButton").MouseButton1Click:Connect(function()
		ShopRemote:FireServer("Buy", trailName)
	end)

	-- EquipService toggles it off if you click the one you're already wearing,
	-- and guarantees only one trail is ever equipped at a time
	card:WaitForChild("EquipButton").MouseButton1Click:Connect(function()
		EquipEvent:FireServer(trailName)
	end)
end

--============================ LIVE REFRESH ============================--
inventory.ChildAdded:Connect(refreshAll)

if equippedTrail then
	equippedTrail.Changed:Connect(refreshAll)
end

--============================ SERVER FEEDBACK ============================--
ShopRemote.OnClientEvent:Connect(function(action, trailName, ...)
	if action == "Bought" then
		refreshAll()
	end
end)
