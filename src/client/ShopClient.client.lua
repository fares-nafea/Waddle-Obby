--// Shop Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Opens/closes StarterGui.ShopUI.ShopFrame and wires the Buy/Equip buttons
--// on each item card. Every object referenced below already exists (built in
--// Studio) - this script only finds them (WaitForChild) and reads/writes
--// their properties; it never creates an Instance.
--// Ownership/equip status is read straight off the replicated
--// player.Inventory / player.EquippedItems folders (the same pattern
--// InventoryClient already uses for trails) - only the Buy/Equip actions
--// themselves go through ShopRemote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRemote")
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local inventory = player:WaitForChild("Inventory")
local equippedItems = player:WaitForChild("EquippedItems")

--============================ GUI ============================--
local shopGui = playerGui:WaitForChild("ShopUI")
local openButton = shopGui:WaitForChild("OpenButton")
local shopFrame = shopGui:WaitForChild("ShopFrame")

shopFrame.Visible = false

-- one entry per item card wired up below; add more cards here as the shop grows
local cards = {
	SpeedCoil = shopFrame:WaitForChild("SpeedCoilCard"),
}

--============================ CARD STATE ============================--
local function isOwned(itemName)
	return inventory:FindFirstChild(itemName) ~= nil
end

local function isEquipped(itemName)
	return equippedItems:FindFirstChild(itemName) ~= nil
end

local function refreshCard(itemName, card)
	local item = ShopConfig.get(itemName)
	if not item then return end

	local buyButton = card:WaitForChild("BuyButton")
	local equipButton = card:WaitForChild("EquipButton")
	local priceLabel = card:WaitForChild("PriceLabel")
	local statusLabel = card:WaitForChild("StatusLabel")

	priceLabel.Text = item.Price .. " Coins"

	local owned = isOwned(itemName)
	buyButton.Visible = not owned
	equipButton.Visible = owned

	if owned then
		local equipped = isEquipped(itemName)
		equipButton.Text = equipped and "Unequip" or "Equip"
		statusLabel.Text = equipped and "Equipped" or "Owned"
	else
		statusLabel.Text = "Not Owned"
	end
end

local function refreshAll()
	for itemName, card in pairs(cards) do
		refreshCard(itemName, card)
	end
end

--============================ OPEN / CLOSE ============================--
local function openShop()
	refreshAll()

	-- pop-in tween: shrink from the card's own authored Size, then tween back
	-- up to it - never overwrites Size with a guessed absolute value
	local targetSize = shopFrame.Size
	shopFrame.Visible = true
	shopFrame.Size = targetSize - UDim2.fromOffset(40, 40)
	TweenService:Create(shopFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = targetSize }):Play()
end

local function closeShop()
	shopFrame.Visible = false
end

openButton.MouseButton1Click:Connect(function()
	if shopFrame.Visible then
		closeShop()
	else
		openShop()
	end
end)

--============================ BUTTON WIRING ============================--
for itemName, card in pairs(cards) do
	card:WaitForChild("BuyButton").MouseButton1Click:Connect(function()
		ShopRemote:FireServer("Buy", itemName)
	end)

	card:WaitForChild("EquipButton").MouseButton1Click:Connect(function()
		ShopRemote:FireServer("Equip", itemName)
	end)
end

--============================ LIVE REFRESH ============================--
inventory.ChildAdded:Connect(refreshAll)
equippedItems.ChildAdded:Connect(refreshAll)
equippedItems.ChildRemoved:Connect(refreshAll)

--============================ SERVER FEEDBACK ============================--
ShopRemote.OnClientEvent:Connect(function(action, itemName, ...)
	if action == "Bought" or action == "Equipped" then
		refreshAll()

	elseif action == "NotEnoughCoins" then
		local cost, have = ...
		local card = cards[itemName]
		if not card then return end

		local statusLabel = card:WaitForChild("StatusLabel")
		statusLabel.Text = "Need " .. cost .. " (have " .. have .. ")"

		task.wait(2)
		refreshCard(itemName, card) -- restore the normal status text
	end
end)
