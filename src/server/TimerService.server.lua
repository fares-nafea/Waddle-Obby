local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimerEvent = ReplicatedStorage.Events:WaitForChild("TimerEvent")

local startTimes = {}
local debounce = {}

for _, stage in ipairs(workspace.Stages:GetChildren()) do
	local StartPart = stage:FindFirstChild("StartTimer")
	local StopPart = stage:FindFirstChild("StopTimer")
	local ExitPart = stage:FindFirstChild("ExitPart")
	
	if not ExitPart then
		warn(stage.Name .. " is missing ExitPart")
		continue
	end

	if not StartPart then
		warn(stage.Name .. " is missing StartTimer")
		continue
	end

	if not StopPart then
		warn(stage.Name .. " is missing StopTimer")
		continue
	end

	ExitPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if not player then return end
		if not startTimes[player] then return end

		startTimes[player] = nil

		TimerEvent:FireClient(player, "Reset")

		print(player.Name .. " Left the timer")
	end)

	-- Start Timer
	StartPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if not player then return end
		
		if debounce[player] then return end

		debounce[player] = true
		
		startTimes[player] = os.clock()
		TimerEvent:FireClient(player, "Start")
		print(player.Name .. " Started Timer")

		task.wait(0.5)
		debounce[player] = nil
	end)
	-- Stop Timer
	StopPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if not player then return end
		if debounce[player] then return end
		if not startTimes[player] then return end

		debounce[player] = true

		local elapsed = os.clock() - startTimes[player]

		print(player.Name .. " Finished in " .. string.format("%.2f", elapsed) .. " seconds")

		local reward = math.floor((5000 / elapsed) + math.random(-50, 50))

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local coins = leaderstats:FindFirstChild("Coins")

			if coins then
				coins.Value += reward
			end
		end

		print(player.Name .. " earned " .. reward .. " Coins")

		TimerEvent:FireClient(player, "Finish", elapsed, reward)

		startTimes[player] = nil

		task.wait(0.5)
		debounce[player] = nil
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function()
			startTimes[player] = nil
			debounce[player] = nil

			TimerEvent:FireClient(player, "Reset")
		end)
	end)
end)