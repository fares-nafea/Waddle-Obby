local TweenService = game:GetService("TweenService")

local Module = {}

local originalPositions = {}

local function SavePosition(button)
	originalPositions[button] = button.Position
end

function Module.Disable(disappears1, disappears2, disappears3, disappears4)
	local buttons = {
		disappears1,
		disappears2,
		disappears3,
		disappears4
	}

	for _, button in ipairs(buttons) do
		originalPositions[button] = button.Position
		button.Visible = true

		local tween = TweenService:Create(
			button,
			TweenInfo.new(
				90,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Position = UDim2.new(
					1,
					100,
					button.Position.Y.Scale,
					button.Position.Y.Offset
				)
			}
		)

		tween:Play()

		tween.Completed:Once(function()
			button.Visible = false
		end)
	end
end

function Module.Appear(appear1, appear2, appear3, appear4)
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
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = originalPositions[button]
				}
			)

			tween:Play()
		end
	end
end

return Module