--// Shop Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Opens/closes StarterGui.ShopUI.ShopFrame, wires the Buy button on each
--// trail card (found under ShopFrame.Grid), the Close button, the live coin
--// counter, and hover/press feedback. Every object referenced below already
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
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopRemote")
local EquipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipEvent")
local TrailConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrailConfig"))

local inventory = player:WaitForChild("Inventory")
local equippedTrail = player:WaitForChild("EquippedTrail", 10)

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

--============================ CARD STATE ============================--
local STATUS_STYLE = {
	NotOwned = { Text = "Not Owned", Color = Color3.fromRGB(125, 133, 156), Bg = Color3.fromRGB(28, 33, 50) },
	Owned    = { Text = "Owned",     Color = Color3.fromRGB(78, 214, 144),  Bg = Color3.fromRGB(20, 43, 34) },
	Equipped = { Text = "Equipped",  Color = Color3.fromRGB(255, 208, 40), Bg = Color3.fromRGB(46, 38, 12) },
}

local function isOwned(trailName)
	return inventory:FindFirstChild(trailName) ~= nil
end

local function isEquipped(trailName)
	return equippedTrail ~= nil and equippedTrail.Value == trailName
end

-- recolors + retexts the StatusLabel pill in one place, so every call site
-- (refreshCard, the NotEnoughCoins flash) stays in sync
local function applyStatusStyle(statusLabel, key)
	local style = STATUS_STYLE[key]
	statusLabel.Text = style.Text
	statusLabel.TextColor3 = style.Color
	statusLabel.BackgroundColor3 = style.Bg

	local stroke = statusLabel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = style.Color
	end
end

local function refreshCard(trailName, card)
	local item = TrailConfig.get(trailName)
	if not item then return end

	local buyButton = card:WaitForChild("BuyButton")
	local equipButton = card:WaitForChild("EquipButton")
	local priceLabel = card:WaitForChild("PriceLabel")
	local statusLabel = card:WaitForChild("StatusLabel")
	local cardStroke = card:FindFirstChildOfClass("UIStroke")

	priceLabel.Text = item.Price .. " Coins"

	local owned = isOwned(trailName)
	buyButton.Visible = not owned
	equipButton.Visible = owned

	if owned then
		local equipped = isEquipped(trailName)
		equipButton.Text = equipped and "Unequip" or "Equip"
		applyStatusStyle(statusLabel, equipped and "Equipped" or "Owned")

		if cardStroke then
			cardStroke.Color = equipped and Color3.fromRGB(255, 208, 40) or Color3.fromRGB(78, 214, 144)
			cardStroke.Thickness = equipped and 1.5 or 1
		end
	else
		applyStatusStyle(statusLabel, "NotOwned")

		if cardStroke then
			cardStroke.Color = Color3.fromRGB(55, 62, 84)
			cardStroke.Thickness = 1
		end
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
local OPEN_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local panelSize = shopFrame.Size -- the size authored in Studio; never overwritten with a guessed value
local closing = false

local function openShop()
	if shopFrame.Visible then return end
	refreshAll()
	refreshCoins()

	closing = false
	dim.Visible = true
	dim.BackgroundTransparency = 1
	shopFrame.Visible = true
	shopFrame.Size = panelSize - UDim2.fromOffset(40, 40)

	TweenService:Create(shopFrame, OPEN_TWEEN, { Size = panelSize }):Play()
	TweenService:Create(dim, OPEN_TWEEN, { BackgroundTransparency = 0.5 }):Play()
end

local function closeShop()
	if not shopFrame.Visible or closing then return end
	closing = true

	local shrink = TweenService:Create(shopFrame, CLOSE_TWEEN, { Size = panelSize - UDim2.fromOffset(40, 40) })
	TweenService:Create(dim, CLOSE_TWEEN, { BackgroundTransparency = 1 }):Play()
	shrink:Play()

	shrink.Completed:Connect(function()
		shopFrame.Visible = false
		dim.Visible = false
		shopFrame.Size = panelSize -- reset ahead of the next open
		closing = false
	end)
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

--============================ HOVER / PRESS FEEL ============================--
local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_DOWN_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_UP_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- whole-card hover pop, driven by the card's own UIScale so it never fights
-- Grid's UIGridLayout (which owns .Size, but has no opinion on UIScale.Scale)
local function wireCardHover(card)
	local scale = card:FindFirstChildOfClass("UIScale")
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if not scale then return end

	local baseTransparency = stroke and stroke.Transparency or 0

	card.MouseEnter:Connect(function()
		TweenService:Create(scale, HOVER_TWEEN, { Scale = 1.025 }):Play()
		if stroke then
			TweenService:Create(stroke, HOVER_TWEEN, { Transparency = 0 }):Play()
		end
	end)

	card.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER_TWEEN, { Scale = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, HOVER_TWEEN, { Transparency = baseTransparency }):Play()
		end
	end)
end

-- press-down/release "click" feel for any button, via its own UIScale
local function wireButtonPress(button)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then return end

	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, PRESS_DOWN_TWEEN, { Scale = 0.94 }):Play()
	end)

	local function release()
		TweenService:Create(scale, PRESS_UP_TWEEN, { Scale = 1 }):Play()
	end

	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

for _, card in pairs(cards) do
	wireCardHover(card)
	wireButtonPress(card:WaitForChild("BuyButton"))
	wireButtonPress(card:WaitForChild("EquipButton"))
end
wireButtonPress(closeBtn)

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

	elseif action == "NotEnoughCoins" then
		local cost, have = ...
		local card = cards[trailName]
		if not card then return end

		local statusLabel = card:WaitForChild("StatusLabel")
		applyStatusStyle(statusLabel, "NotOwned")
		statusLabel.Text = "Need " .. cost .. " (have " .. have .. ")"

		task.wait(2)
		refreshCard(trailName, card) -- restore the normal status text/color
	end
end)
