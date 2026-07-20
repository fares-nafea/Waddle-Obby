--// Equip Service (Day 9)
--// Place in: ServerScriptService
--// Attaches the chosen trail to the player's character. Server-authoritative:
--// it re-checks ownership from the Inventory folder and never trusts the client.
--// Trail templates (Trail + Attachment0 + Attachment1, fully configured) live in
--// ReplicatedStorage.Trails; this script only clones and wires them onto a character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipEvent")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RewardsCatalog"))
local Trails = ReplicatedStorage:WaitForChild("Trails")

local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", 5)
end

-- remove whatever trail (and its attachments) is currently on the root
local function clearTrail(root)
	local old = root:FindFirstChild("EquippedTrail")
	if old then old:Destroy() end

	local a0 = root:FindFirstChild("TrailAtt0")
	if a0 then a0:Destroy() end

	local a1 = root:FindFirstChild("TrailAtt1")
	if a1 then a1:Destroy() end
end

-- apply (or clear if trailName == "") a trail to a character
local function applyTrail(character, trailName)
	local root = getRoot(character)
	if not root then return end

	-- always clear the old one first
	clearTrail(root)

	if trailName == "" then return end

	local item = Catalog.get(trailName)
	if not item or item.type ~= "Trail" then return end

	local template = Trails:FindFirstChild(trailName)
	if not template then return end

	local clone = template:Clone()
	local a0 = clone:WaitForChild("Attachment0")
	local a1 = clone:WaitForChild("Attachment1")
	local trail = clone:WaitForChild("Trail")

	a0.Name = "TrailAtt0"
	a1.Name = "TrailAtt1"
	trail.Name = "EquippedTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1

	a0.Parent = root
	a1.Parent = root
	trail.Parent = root

	clone:Destroy() -- discard the now-empty template wrapper
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
