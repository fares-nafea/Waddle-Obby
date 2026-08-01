--// Teleport Service

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObbyConfig"))
local ObbyLockedEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ObbyLockedEvent")

local GatesFolder = workspace:WaitForChild("Gates")
local StagesFolder = workspace:WaitForChild("Stages")

local debounce = {}

Players.PlayerRemoving:Connect(function(player)
	debounce[player] = nil
end)

for _, gate in ipairs(GatesFolder:GetChildren()) do
	local portal = gate:WaitForChild("Portal") 

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if not player then
			return
		end

		if debounce[player] then
			return
		end

		debounce[player] = true

		local stageNum = portal:GetAttribute("Stage-Num")

		if stageNum then
			-- Sequential Obby Unlock: block entry into an Obby the player hasn't
			-- reached yet. UnlockedObby defaults to missing-means-1 so a player
			-- whose data hasn't loaded yet can still only reach Obby 1, never
			-- something further in - fails safe, not open.
			local unlockedObby = player:FindFirstChild("UnlockedObby")
			local unlockedValue = unlockedObby and unlockedObby.Value or 1

			if stageNum > unlockedValue then
				ObbyLockedEvent:FireClient(player, "Complete Obby " .. (stageNum - 1) .. " first!")
				task.wait(1)
				debounce[player] = nil
				return
			end

			local stageName = "Stage " .. stageNum
			print("[TeleportService] Searching for stage folder: " .. stageName)
			local stage = StagesFolder:FindFirstChild(stageName)

			if stage then
				local tpPart = stage:FindFirstChild("TpPart")

				if tpPart then
					character:PivotTo(tpPart.CFrame + Vector3.new(0, 3, 0))
				else
					warn("TpPart Not Found in Stage "..stageNum)
				end
			else
				warn("Stage "..stageNum.." Not Found")
			end
		else
			warn("Portal Does Not Have Stage-Num")
		end

		task.wait(1)
		debounce[player] = nil
	end)
end

-- "Stage 1" -> "Gate1": pulls the number out of the stage folder's Name and
-- rebuilds it in Gates' naming convention (no space, "Gate" prefix)
local function getGateNameForStage(stage)
	local stageNumber = stage.Name:match("%d+")
	if not stageNumber then
		return nil
	end
	return "Gate" .. stageNumber
end

for _, stage in ipairs(StagesFolder:GetChildren()) do
	local exitPart = stage:FindFirstChild("ExitPart")
	if not exitPart then
		warn("[TeleportService] " .. stage.Name .. " has no ExitPart - its exit teleport won't be wired up")
	end

	local FinishPart = stage:FindFirstChild("FinishPart")
	if not FinishPart then
		warn("[TeleportService] " .. stage.Name .. " has no FinishPart - its finish teleport won't be wired up")
	end

	if exitPart then
		exitPart.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)

			if not player then
				return
			end

			if debounce[player] then
				return
			end

			debounce[player] = true

			local gateName = getGateNameForStage(stage)
			local gate = gateName and GatesFolder:FindFirstChild(gateName)

			if gate then
				local spawnPart = gate:FindFirstChild("SpawnPart")

				if spawnPart then
					character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
				else
					warn("SpawnPart Not Found in " .. gate.Name)
				end
			else
				warn(tostring(gateName) .. " Not Found for " .. stage.Name)
			end

			warn("Leaved Stage")

			task.wait(1)
			debounce[player] = nil
		end)
	end

	if FinishPart then
		FinishPart.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)

			if not player then
				return
			end

			if debounce[player] then
				return
			end

			debounce[player] = true

			local gateName = getGateNameForStage(stage)
			local gate = gateName and GatesFolder:FindFirstChild(gateName)

			if gate then
				local spawnPart = gate:FindFirstChild("SpawnPart")

				if spawnPart then
					character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
				else
					print("spawnpart not found in ", gate.Name)
				end
			else
				print("gate not found ", tostring(gateName))
			end

			warn("Finished")

			task.wait(1)
			debounce[player] = nil
		end)
	end

end