--// Collection UI (Day 8/9)
--// Place in: StarterPlayer > StarterPlayerScripts
--// Shows every trail + skin as a grid. Owned = colored, locked = greyed.
--// Auto-opens and highlights the new item when you open an egg.
--// UI hierarchy lives in StarterGui.CollectionGui (see default.project.json);
--// this script only wires behavior onto existing instances.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("RewardsCatalog"))
local cardTemplate = Shared:WaitForChild("Templates"):WaitForChild("RewardCard")
local EggEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EggEvent")
local EquipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipEvent")

local RARITY = Catalog.RarityColors
local inventory = player:WaitForChild("Inventory")
local equippedTrail = player:WaitForChild("EquippedTrail", 10)

local function equippedName()
	return equippedTrail and equippedTrail.Value or ""
end

--============================ GUI ============================--
local gui = playerGui:WaitForChild("CollectionGui")
local openBtn = gui:WaitForChild("OpenBtn")
local dim = gui:WaitForChild("Dim")
local panel = gui:WaitForChild("Panel")
local counter = panel:WaitForChild("Counter")
local closeBtn = panel:WaitForChild("CloseBtn")
local tabsHolder = panel:WaitForChild("TabsHolder")
local scroll = panel:WaitForChild("Grid")

local currentFilter = "All"
local tabButtons = {}
for _, tabName in ipairs({ "All", "Trail", "Skin" }) do
	tabButtons[tabName] = tabsHolder:WaitForChild(tabName)
end

--============================ RENDER ============================--
local cardByName = {}

local function isOwned(name)
	return inventory:FindFirstChild(name) ~= nil
end

local function render()
	cardByName = {}
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local ownedCount, total = 0, 0
	for i, item in ipairs(Catalog.Rewards) do
		if currentFilter == "All" or item.type == currentFilter then
			total += 1
			local owned = isOwned(item.name)
			if owned then ownedCount += 1 end
			local rarityColor = RARITY[item.rarity] or Color3.new(1, 1, 1)

			local card = cardTemplate:Clone()
			card.LayoutOrder = i
			card.BackgroundColor3 = owned and Color3.fromRGB(30, 38, 58) or Color3.fromRGB(16, 20, 32)

			local stroke = card:WaitForChild("UIStroke")
			stroke.Color = owned and rarityColor or Color3.fromRGB(55, 62, 84)
			stroke.Thickness = owned and 3 or 1

			-- color swatch (trail color, or rarity color for skins)
			local swatch = card:WaitForChild("Swatch")
			swatch.BackgroundColor3 = owned and (item.color or rarityColor) or Color3.fromRGB(38, 44, 60)

			local typeTag = swatch:WaitForChild("TypeTag")
			typeTag.Text = owned and (item.type == "Trail" and "~" or "") or "?"

			local nameLbl = card:WaitForChild("NameLbl")
			nameLbl.TextColor3 = owned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 128, 148)
			nameLbl.Text = owned and item.name or "Locked"

			local rarityLbl = card:WaitForChild("RarityLbl")
			rarityLbl.TextColor3 = owned and rarityColor or Color3.fromRGB(90, 96, 116)
			rarityLbl.Text = item.rarity

			-- Equip button (owned trails only)
			local equipBtn = card:WaitForChild("EquipBtn")
			if owned and item.type == "Trail" then
				local isOn = equippedName() == item.name

				equipBtn.Visible = true
				equipBtn.BackgroundColor3 = isOn and Color3.fromRGB(60, 190, 110) or Color3.fromRGB(80, 140, 255)
				equipBtn.Text = isOn and "Equipped" or "Equip"

				equipBtn.MouseButton1Click:Connect(function()
					EquipEvent:FireServer(item.name)
				end)
			else
				equipBtn.Visible = false
			end

			card.Parent = scroll
			cardByName[item.name] = card
		end
	end

	counter.Text = ownedCount .. " / " .. total .. " unlocked"
end

local function setFilter(name)
	currentFilter = name
	for tabName, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (tabName == name) and Color3.fromRGB(80, 140, 255) or Color3.fromRGB(35, 45, 70)
	end
	render()
end

--============================ OPEN / CLOSE ============================--
local function open()
	render()
	dim.Visible = true
	panel.Visible = true
	panel.Size = UDim2.fromOffset(500, 360)
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(560, 400) }):Play()
end

local function close()
	panel.Visible = false
	dim.Visible = false
end

openBtn.MouseButton1Click:Connect(open)
closeBtn.MouseButton1Click:Connect(close)
dim.MouseButton1Click:Connect(close)

for tabName, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		setFilter(tabName)
	end)
end
setFilter("All")

-- live refresh when a new item drops
inventory.ChildAdded:Connect(function()
	if panel.Visible then render() end
end)

-- refresh equip buttons when the equipped trail changes
if equippedTrail then
	equippedTrail.Changed:Connect(function()
		if panel.Visible then render() end
	end)
end

--============================ EGG REVEAL → SHOW UI ============================--
local function pulseCard(itemName)
	local card = cardByName[itemName]
	if not card then return end
	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	if not stroke then return end
	for _ = 1, 3 do
		TweenService:Create(stroke, TweenInfo.new(0.2), { Thickness = 7 }):Play()
		task.wait(0.2)
		TweenService:Create(stroke, TweenInfo.new(0.2), { Thickness = 3 }):Play()
		task.wait(0.2)
	end
end

EggEvent.OnClientEvent:Connect(function(action, ...)
	if action ~= "Reward" then return end
	local itemName = ...
	local item = Catalog.get(itemName)

	task.wait(1) -- let the reveal toast play first
	setFilter(item and item.type or "All")
	open()
	task.spawn(pulseCard, itemName)
end)
