local StarterGui = game:GetService("StarterGui")

local success = false

repeat
	success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)

	if not success then
		task.wait(0.1)
	end
until success