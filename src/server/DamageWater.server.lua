local Players = game:GetService("Players")

local folder = workspace:WaitForChild("Water")
local killPart = folder:WaitForChild("DamageWater")

killPart.Touched:Connect(function(hit)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.Health = 0
	end
end)