local DisableUI = {}

local TweenService = game:GetService("TweenService")

local originalTransparency = {}

local function SaveTransparency(object)
	if originalTransparency[object] then
		return
	end

	local data = {}

	if object:IsA("GuiObject") then
		data.BackgroundTransparency = object.BackgroundTransparency
	end

	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		data.TextTransparency = object.TextTransparency
		data.TextStrokeTransparency = object.TextStrokeTransparency
	end

	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		data.ImageTransparency = object.ImageTransparency
	end

	originalTransparency[object] = data
end

local function FadeObject(object, transparency, duration)
	if not object then
		return
	end

	SaveTransparency(object)

	local goal = {}

	if object:IsA("GuiObject") then
		goal.BackgroundTransparency = transparency
	end

	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		goal.TextTransparency = transparency
		goal.TextStrokeTransparency = transparency
	end

	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		goal.ImageTransparency = transparency
	end

	local tween = TweenService:Create(
		object,
		TweenInfo.new(
			duration,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		),
		goal
	)

	tween:Play()

	return tween
end

local function RestoreObject(object, duration)
	local saved = originalTransparency[object]

	if not saved then
		return
	end

	local tween = TweenService:Create(
		object,
		TweenInfo.new(
			duration,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),
		saved
	)

	tween:Play()

	return tween
end

function DisableUI.Disable(...)
	local buttons = { ... }

	for _, button in ipairs(buttons) do
		if button then
			local tween = FadeObject(button, 1, 0.5)

			if tween then
				tween.Completed:Connect(function()
					button.Visible = false
				end)
			end
		end
	end
end

function DisableUI.Appear(...)
	local buttons = { ... }

	for _, button in ipairs(buttons) do
		if button then
			button.Visible = true
			RestoreObject(button, 0.5)
		end
	end
end

function DisableUI.DisableTop(...)
	local buttons = { ... }

	for _, button in ipairs(buttons) do
		if button then
			local tween = FadeObject(button, 1, 0.5)

			if tween then
				tween.Completed:Connect(function()
					button.Visible = false
				end)
			end
		end
	end
end

function DisableUI.AppearTop(...)
	local buttons = { ... }

	for _, button in ipairs(buttons) do
		if button then
			button.Visible = true
			RestoreObject(button, 0.5)
		end
	end
end

return DisableUI