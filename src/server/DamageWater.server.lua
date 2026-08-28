local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = workspace:WaitForChild("Water")
local TpPart = folder:WaitForChild("DamageWater")
local SpawnLocation = workspace:WaitForChild("SpawnLocation")

local Events = ReplicatedStorage:WaitForChild("Events")
local TimerEvent = Events:WaitForChild("TimerEvent")

TpPart.Touched:Connect(function(hit)

	local character = hit.Parent

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if humanoid and rootPart then

		local player = Players:GetPlayerFromCharacter(character)

		if not player then
			return
		end

		rootPart.CFrame = CFrame.new(
			SpawnLocation.Position.X,
			SpawnLocation.Position.Y + 5,
			SpawnLocation.Position.Z
		)

		TimerEvent:FireClient(player, "Reset")
	end

end)