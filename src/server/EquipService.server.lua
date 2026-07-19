--// Equip Service (Day 9)
--// Place in: ServerScriptService
--// Attaches the chosen trail to the player's character. Server-authoritative:
--// it re-checks ownership from the Inventory folder and never trusts the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipEvent")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RewardsCatalog"))

local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", 5)
end

-- build (or reuse) the two attachments a Trail needs
local function ensureAttachments(root)
	local a0 = root:FindFirstChild("TrailAtt0")
	if not a0 then
		a0 = Instance.new("Attachment")
		a0.Name = "TrailAtt0"
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = root
	end

	local a1 = root:FindFirstChild("TrailAtt1")
	if not a1 then
		a1 = Instance.new("Attachment")
		a1.Name = "TrailAtt1"
		a1.Position = Vector3.new(0, -1.5, 0)
		a1.Parent = root
	end

	return a0, a1
end

-- apply (or clear if trailName == "") a trail to a character
local function applyTrail(character, trailName)
	local root = getRoot(character)
	if not root then return end

	-- always clear the old one first
	local old = root:FindFirstChild("EquippedTrail")
	if old then old:Destroy() end

	if trailName == "" then return end

	local item = Catalog.get(trailName)
	if not item or item.type ~= "Trail" then return end

	local a0, a1 = ensureAttachments(root)

	local trail = Instance.new("Trail")
	trail.Name = "EquippedTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(item.color or Color3.new(1, 1, 1))
	trail.Lifetime = 0.6
	trail.MinLength = 0.05
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.FaceCamera = true
	trail.Parent = root
end

-- client asks to equip/toggle a trail
EquipEvent.OnServerEvent:Connect(function(player, trailName)
	if typeof(trailName) ~= "string" then return end

	local equipped = player:FindFirstChild("EquippedTrail")
	if not equipped then return end

	if trailName ~= "" then
		-- ownership check (never trust the client)
		local inv = player:FindFirstChild("Inventory")
		if not (inv and inv:FindFirstChild(trailName)) then return end

		local item = Catalog.get(trailName)
		if not item or item.type ~= "Trail" then return end

		-- clicking the one you already wear = take it off
		if equipped.Value == trailName then
			trailName = ""
		end
	end

	equipped.Value = trailName

	if player.Character then
		applyTrail(player.Character, trailName)
	end
end)

-- re-apply the saved trail every time the character spawns
local function hookCharacter(player)
	player.CharacterAdded:Connect(function(character)
		local equipped = player:WaitForChild("EquippedTrail", 10)
		if equipped then
			applyTrail(character, equipped.Value)
		end
	end)
end

Players.PlayerAdded:Connect(hookCharacter)
for _, player in ipairs(Players:GetPlayers()) do
	hookCharacter(player)
	if player.Character then
		local equipped = player:FindFirstChild("EquippedTrail")
		if equipped then
			applyTrail(player.Character, equipped.Value)
		end
	end
end
