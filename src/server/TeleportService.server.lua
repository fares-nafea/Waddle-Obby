--// Teleport Service

local Players = game:GetService("Players")

local GatesFolder = workspace:WaitForChild("Gates")
local StagesFolder = workspace:WaitForChild("Stages")

local debounce = {}

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
			local stage = StagesFolder:FindFirstChild(tostring(stageNum))

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

for _, stage in ipairs(StagesFolder:GetChildren()) do
	local exitPart = stage:WaitForChild("ExitPart")
	local FinishPart = stage:WaitForChild("FinishPart")
	
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

		local gate = GatesFolder:FindFirstChild("Gate" .. stage.Name)

		if gate then
			local spawnPart = gate:FindFirstChild("SpawnPart")

			if spawnPart then
				character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
			else
				warn("SpawnPart Not Found in " .. gate.Name)
			end
		else
			warn("Gate" .. stage.Name .. " Not Found")
		end
		
		warn("Leaved Stage")

		task.wait(1)
		debounce[player] = nil
	end)
	
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
		
		local gate = GatesFolder:FindFirstChild("Gate" .. stage.Name)
		
		if gate then
			local spawnPart = gate:FindFirstChild("SpawnPart")
			
			if spawnPart then
				character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
			else
				print("spawnpart not found in ", stage.Name)
			end
		else
			print("gate not found ", stage.Name)
		end
		
		warn("Finished")
		
		task.wait(1)
		debounce[player] = nil
	end)
	
end