--// Collection UI (Day 8/9)
--// Place in: StarterPlayer > StarterPlayerScripts
--// Shows every trail + skin as a grid. Owned = colored, locked = greyed.
--// Auto-opens and highlights the new item when you open an egg.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RewardsCatalog"))
local EggEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EggEvent")
local EquipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipEvent")

local RARITY = Catalog.RarityColors
local inventory = player:WaitForChild("Inventory")
local equippedTrail = player:WaitForChild("EquippedTrail", 10)

local function equippedName()
	return equippedTrail and equippedTrail.Value or ""
end

--============================ GUI ============================--
local gui = Instance.new("ScreenGui")
gui.Name = "CollectionGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- open button (bottom-left)
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenBtn"
openBtn.Size = UDim2.fromOffset(140, 46)
openBtn.Position = UDim2.new(0, 16, 1, -70)
openBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 70)
openBtn.Text = "Collection"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextScaled = true
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 12)
local obPad = Instance.new("UIPadding", openBtn)
obPad.PaddingTop = UDim.new(0, 10); obPad.PaddingBottom = UDim.new(0, 10)

-- dim background
local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.Text = ""
dim.AutoButtonColor = false
dim.Visible = false
dim.Parent = gui

-- panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(560, 400)
panel.BackgroundColor3 = Color3.fromRGB(20, 26, 42)
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -120, 0, 44)
title.Position = UDim2.fromOffset(20, 12)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "My Collection"
title.Parent = panel

local counter = Instance.new("TextLabel")
counter.BackgroundTransparency = 1
counter.Size = UDim2.new(0, 120, 0, 24)
counter.Position = UDim2.fromOffset(20, 54)
counter.TextXAlignment = Enum.TextXAlignment.Left
counter.Font = Enum.Font.GothamMedium
counter.TextScaled = true
counter.TextColor3 = Color3.fromRGB(170, 180, 200)
counter.Text = "0 / 0 unlocked"
counter.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(40, 40)
closeBtn.Position = UDim2.new(1, -52, 0, 14)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

-- filter tabs
local tabsHolder = Instance.new("Frame")
tabsHolder.BackgroundTransparency = 1
tabsHolder.Size = UDim2.new(1, -40, 0, 34)
tabsHolder.Position = UDim2.fromOffset(20, 84)
tabsHolder.Parent = panel
local tabsLayout = Instance.new("UIListLayout", tabsHolder)
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 8)

local currentFilter = "All"
local tabButtons = {}
local function makeTab(name)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(100, 34)
	b.BackgroundColor3 = Color3.fromRGB(35, 45, 70)
	b.Text = name
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Parent = tabsHolder
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local p = Instance.new("UIPadding", b)
	p.PaddingTop = UDim.new(0, 8); p.PaddingBottom = UDim.new(0, 8)
	tabButtons[name] = b
	return b
end

-- scrolling grid
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Grid"
scroll.Size = UDim2.new(1, -40, 1, -140)
scroll.Position = UDim2.fromOffset(20, 128)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
local grid = Instance.new("UIGridLayout", scroll)
grid.CellSize = UDim2.fromOffset(120, 182)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder

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

			local card = Instance.new("Frame")
			card.LayoutOrder = i
			card.BackgroundColor3 = owned and Color3.fromRGB(30, 38, 58) or Color3.fromRGB(16, 20, 32)
			card.Parent = scroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

			local stroke = Instance.new("UIStroke")
			stroke.Color = owned and rarityColor or Color3.fromRGB(55, 62, 84)
			stroke.Thickness = owned and 3 or 1
			stroke.Parent = card

			-- color swatch (trail color, or rarity color for skins)
			local swatch = Instance.new("Frame")
			swatch.Size = UDim2.new(1, -20, 0, 66)
			swatch.Position = UDim2.fromOffset(10, 10)
			swatch.BackgroundColor3 = owned and (item.color or rarityColor) or Color3.fromRGB(38, 44, 60)
			swatch.Parent = card
			Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 8)

			local typeTag = Instance.new("TextLabel")
			typeTag.BackgroundTransparency = 1
			typeTag.Size = UDim2.fromScale(1, 1)
			typeTag.Font = Enum.Font.GothamBold
			typeTag.TextScaled = true
			typeTag.TextColor3 = Color3.fromRGB(255, 255, 255)
			typeTag.TextTransparency = 0.15
			typeTag.Text = owned and (item.type == "Trail" and "~" or "") or "?"
			typeTag.Parent = swatch

			local nameLbl = Instance.new("TextLabel")
			nameLbl.BackgroundTransparency = 1
			nameLbl.Size = UDim2.new(1, -12, 0, 34)
			nameLbl.Position = UDim2.fromOffset(6, 82)
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextScaled = true
			nameLbl.TextWrapped = true
			nameLbl.TextColor3 = owned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 128, 148)
			nameLbl.Text = owned and item.name or "Locked"
			nameLbl.Parent = card

			local rarityLbl = Instance.new("TextLabel")
			rarityLbl.BackgroundTransparency = 1
			rarityLbl.Size = UDim2.new(1, -12, 0, 18)
			rarityLbl.Position = UDim2.fromOffset(6, 118)
			rarityLbl.Font = Enum.Font.GothamMedium
			rarityLbl.TextScaled = true
			rarityLbl.TextColor3 = owned and rarityColor or Color3.fromRGB(90, 96, 116)
			rarityLbl.Text = item.rarity
			rarityLbl.Parent = card

			-- Equip button (owned trails only)
			if owned and item.type == "Trail" then
				local isOn = equippedName() == item.name

				local equipBtn = Instance.new("TextButton")
				equipBtn.Size = UDim2.new(1, -16, 0, 30)
				equipBtn.Position = UDim2.fromOffset(8, 144)
				equipBtn.BackgroundColor3 = isOn and Color3.fromRGB(60, 190, 110) or Color3.fromRGB(80, 140, 255)
				equipBtn.Text = isOn and "Equipped" or "Equip"
				equipBtn.Font = Enum.Font.GothamBold
				equipBtn.TextScaled = true
				equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				equipBtn.Parent = card
				Instance.new("UICorner", equipBtn).CornerRadius = UDim.new(0, 8)
				local ep = Instance.new("UIPadding", equipBtn)
				ep.PaddingTop = UDim.new(0, 6); ep.PaddingBottom = UDim.new(0, 6)

				equipBtn.MouseButton1Click:Connect(function()
					EquipEvent:FireServer(item.name)
				end)
			end

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

for _, tab in ipairs({ "All", "Trail", "Skin" }) do
	makeTab(tab).MouseButton1Click:Connect(function()
		setFilter(tab)
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
