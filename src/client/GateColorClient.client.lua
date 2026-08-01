--// Gate Color Client
--// Place in: StarterPlayer > StarterPlayerScripts
--// Purely cosmetic: colors each workspace.Gates.GateN Portal green if the
--// LOCAL player can enter it (UnlockedObby >= N), red otherwise. This is a
--// LocalScript on purpose - two players with different progress need to see
--// the same physical gate colored differently, and a Part property changed
--// from a LocalScript only renders for that client, never replicates to the
--// server or other players. TeleportService's server-side UnlockedObby
--// check is the real gate; this script never blocks or allows anything, it
--// only reflects what that check will do.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObbyConfig"))

local player = Players.LocalPlayer
local GatesFolder = workspace:WaitForChild("Gates")

local GREEN = Color3.fromRGB(70, 200, 120)
local RED = Color3.fromRGB(210, 70, 70)

local unlockedObby = player:WaitForChild("UnlockedObby", 10)

local gatePortals = {} -- gateNumber -> Portal BasePart

local function colorGate(gateNumber, portal)
	local unlockedValue = (unlockedObby and unlockedObby.Value) or 1
	portal.Color = (gateNumber <= unlockedValue) and GREEN or RED
end

local function refreshAllGates()
	for gateNumber, portal in pairs(gatePortals) do
		colorGate(gateNumber, portal)
	end
end

-- gate number comes straight from the folder name (Config.getObbyId pulls
-- the first run of digits, same auto-discovery ObbyConfig/TeleportService
-- already use) - no manual per-gate assignment anywhere
local function setupGate(gate)
	local portal = gate:WaitForChild("Portal", 5)
	if not portal then
		warn("[GateColorClient] " .. gate.Name .. " has no Portal - can't color it")
		return
	end

	local gateNumber = tonumber(Config.getObbyId(gate.Name))
	if not gateNumber then
		warn("[GateColorClient] couldn't find a gate number in \"" .. gate.Name .. "\" - can't color it")
		return
	end

	gatePortals[gateNumber] = portal
	colorGate(gateNumber, portal)
end

for _, gate in ipairs(GatesFolder:GetChildren()) do
	setupGate(gate)
end

-- a gate added after startup (e.g. streamed in) still gets colored
GatesFolder.ChildAdded:Connect(setupGate)

-- fires the instant TimeService advances UnlockedObby (replicates from the
-- server to every client, but only this client's own copy drives its colors)
if unlockedObby then
	unlockedObby.Changed:Connect(refreshAllGates)
end
