local Players = game:GetService("Players")

local folder = workspace:WaitForChild("Water")
local TpPart = folder:WaitForChild("DamageWater")
local SpawnLocation = workspace:WaitForChild("SpawnLocation")

TpPart.Touched:Connect(function(hit)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if humanoid and rootPart then
		rootPart.CFrame = CFrame.new(
			SpawnLocation.Position.X,
			SpawnLocation.Position.Y + 5,
			SpawnLocation.Position.Z
		)
	end
end)