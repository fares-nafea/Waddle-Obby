local DisableUI = {}

local TweenService = game:GetService("TweenService")

local originalPositions = {}

local function SavePosition(button)
	originalPositions[button] = button.Position
end

function DisableUI.Disable(disappears1, disappears2, disappears3, disappears4)
	local buttons = {
		disappears1,
		disappears2,
		disappears3,
		disappears4
	}

	for _, button in ipairs(buttons) do
		SavePosition(button)

		local tween = TweenService:Create(
			button,
			TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{
				Position = UDim2.new(
					0,
					-50,
					button.Position.Y.Scale,
					button.Position.Y.Offset
				)
			}
		)

		tween:Play()

		tween.Completed:Connect(function()
			button.Visible = false
		end)
	end
end

function DisableUI.Appear(appear1, appear2, appear3, appear4)
	local buttons = {
		appear1,
		appear2,
		appear3,
		appear4
	}

	for _, button in ipairs(buttons) do
		if originalPositions[button] then
			button.Visible = true

			local tween = TweenService:Create(
				button,
				TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{
					Position = originalPositions[button]
				}
			)

			tween:Play()
		end
	end
end

return DisableUI
