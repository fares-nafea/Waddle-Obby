--// UI Animation
--// Place in: ReplicatedStorage > Shared
--// The single UI motion layer for the game. Client scripts open/close
--// panels, press buttons, and show popups/notifications through this
--// module - they never create their own Tweens. Timing and easing live
--// in Config so the whole game's feel can be retuned in one place.

local TweenService = game:GetService("TweenService")

local UIAnimation = {}

UIAnimation.Config = {
	OpenDuration = 0.2,
	CloseDuration = 0.15,
	ButtonDuration = 0.08,
	PopupDuration = 0.2,
	NotificationDuration = 0.2,
	NotificationHold = 2,
	ToastDuration = 0.9,

	OpenScaleFrom = 0.92,
	CloseScaleTo = 0.92,
	PopupScaleFrom = 0.88,
	ButtonPressScale = 0.94,

	DimTransparency = 0.5,

	OpenEasingStyle = Enum.EasingStyle.Quad,
	OpenEasingDirection = Enum.EasingDirection.Out,

	CloseEasingStyle = Enum.EasingStyle.Quad,
	CloseEasingDirection = Enum.EasingDirection.In,

	ButtonEasingStyle = Enum.EasingStyle.Quad,
	ButtonEasingDirection = Enum.EasingDirection.Out,
}

local Config = UIAnimation.Config

local records = {} -- [Instance] = { tweens = {Tween}, gen = number, closing = boolean, dim = Instance?, hooked = boolean }
local wiredButtons = setmetatable({}, { __mode = "k" })

local function tweenInfo(duration, style, direction)
	return TweenInfo.new(duration, style, direction)
end

local function openInfo()
	return tweenInfo(Config.OpenDuration, Config.OpenEasingStyle, Config.OpenEasingDirection)
end

local function closeInfo()
	return tweenInfo(Config.CloseDuration, Config.CloseEasingStyle, Config.CloseEasingDirection)
end

local function buttonInfo()
	return tweenInfo(Config.ButtonDuration, Config.ButtonEasingStyle, Config.ButtonEasingDirection)
end

local function popupInfo()
	return tweenInfo(Config.PopupDuration, Config.OpenEasingStyle, Config.OpenEasingDirection)
end

local function notificationInfo()
	return tweenInfo(Config.NotificationDuration, Config.OpenEasingStyle, Config.OpenEasingDirection)
end

local function toastInfo()
	return tweenInfo(Config.ToastDuration, Config.OpenEasingStyle, Config.OpenEasingDirection)
end

local function cancel(instance)
	local rec = records[instance]
	if not rec then
		return
	end
	for _, tween in ipairs(rec.tweens) do
		tween:Cancel()
	end
	table.clear(rec.tweens)
end

local function getRecord(instance)
	local rec = records[instance]
	if rec then
		return rec
	end

	rec = {
		tweens = {},
		gen = 0,
		closing = false,
		dim = nil,
	}
	records[instance] = rec

	instance.Destroying:Connect(function()
		cancel(instance)
		records[instance] = nil
	end)

	return rec
end

local function play(instance, info, properties)
	local rec = getRecord(instance)
	cancel(instance)
	local tween = TweenService:Create(instance, info, properties)
	table.insert(rec.tweens, tween)
	tween:Play()
	return tween
end

local function playMany(targets)
	local first
	for _, target in ipairs(targets) do
		local tween = play(target.instance, target.info, target.properties)
		if not first then
			first = tween
		end
	end
	return first
end

local function getOrCreateScale(guiObject)
	local scale = guiObject:FindFirstChild("UIAnimationScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	scale = guiObject:FindFirstChildOfClass("UIScale")
	if scale then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Name = "UIAnimationScale"
	scale.Scale = 1
	scale.Parent = guiObject
	return scale
end

local function isAlive(instance)
	return instance ~= nil and instance.Parent ~= nil
end

function UIAnimation.Open(frame, dim)
	if not isAlive(frame) then
		return false
	end

	local rec = getRecord(frame)
	if frame.Visible and not rec.closing then
		return false
	end

	rec.gen += 1
	rec.closing = false
	if dim then
		rec.dim = dim
	else
		dim = rec.dim
	end

	local scale = getOrCreateScale(frame)
	scale.Scale = Config.OpenScaleFrom
	frame.Visible = true

	local targets = {
		{ instance = scale, info = openInfo(), properties = { Scale = 1 } },
	}

	if dim then
		dim.Visible = true
		dim.BackgroundTransparency = 1
		table.insert(targets, {
			instance = dim,
			info = openInfo(),
			properties = { BackgroundTransparency = Config.DimTransparency },
		})
	end

	playMany(targets)
	return true
end

function UIAnimation.Close(frame, dim)
	if not isAlive(frame) then
		return false
	end

	local rec = getRecord(frame)
	if not frame.Visible or rec.closing then
		return false
	end

	rec.gen += 1
	local gen = rec.gen
	rec.closing = true
	dim = dim or rec.dim
	if dim then
		rec.dim = dim
	end

	local scale = getOrCreateScale(frame)
	local targets = {
		{ instance = scale, info = closeInfo(), properties = { Scale = Config.CloseScaleTo } },
	}

	if dim then
		table.insert(targets, {
			instance = dim,
			info = closeInfo(),
			properties = { BackgroundTransparency = 1 },
		})
	end

	local tween = playMany(targets)
	tween.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		if rec.gen ~= gen then
			return
		end
		if not isAlive(frame) then
			return
		end

		frame.Visible = false
		scale.Scale = 1
		if dim and isAlive(dim) then
			dim.Visible = false
		end
		rec.closing = false
	end)

	return true
end

function UIAnimation.Toggle(frame, isOpen, dim)
	if isOpen then
		return UIAnimation.Open(frame, dim)
	end
	return UIAnimation.Close(frame, dim)
end

function UIAnimation.ButtonPress(button)
	if not isAlive(button) or wiredButtons[button] then
		return
	end
	wiredButtons[button] = true

	local scale = getOrCreateScale(button)

	button.MouseButton1Down:Connect(function()
		if not isAlive(scale) then
			return
		end
		play(scale, buttonInfo(), { Scale = Config.ButtonPressScale })
	end)

	local function release()
		if not isAlive(scale) then
			return
		end
		play(scale, buttonInfo(), { Scale = 1 })
	end

	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

function UIAnimation.Popup(frame)
	if not isAlive(frame) then
		return false
	end

	local rec = getRecord(frame)
	rec.gen += 1
	rec.closing = false

	local scale = getOrCreateScale(frame)
	scale.Scale = Config.PopupScaleFrom
	frame.Visible = true
	play(scale, popupInfo(), { Scale = 1 })
	return true
end

function UIAnimation.Notification(instance, options)
	if not isAlive(instance) then
		return false
	end

	options = options or {}
	local rec = getRecord(instance)
	rec.gen += 1
	local gen = rec.gen
	rec.closing = false

	local companions = options.alsoFade or {}
	local hold = options.hold
	if hold == nil then
		hold = Config.NotificationHold
	end

	instance.Visible = true

	if options.rise then
		local endPosition = options.endPosition or UDim2.fromScale(0.5, -0.5)
		local properties = { Position = endPosition }
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			properties.TextTransparency = 1
		end

		local tween = play(instance, toastInfo(), properties)
		tween.Completed:Connect(function(playbackState)
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end
			if rec.gen ~= gen then
				return
			end
			if options.destroy and isAlive(instance) then
				instance:Destroy()
			end
		end)
		return true
	end

	local scale = getOrCreateScale(instance)
	scale.Scale = Config.OpenScaleFrom

	if options.targetBackgroundTransparency ~= nil then
		instance.BackgroundTransparency = 1
	end

	local fadeIn = {}
	if options.targetBackgroundTransparency ~= nil then
		fadeIn.BackgroundTransparency = options.targetBackgroundTransparency
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.TextTransparency = 1
		fadeIn.TextTransparency = 0
	end

	play(scale, notificationInfo(), { Scale = 1 })
	if next(fadeIn) ~= nil then
		play(instance, notificationInfo(), fadeIn)
	end

	for _, companion in ipairs(companions) do
		if isAlive(companion) then
			local props = {}
			if companion:IsA("TextLabel") or companion:IsA("TextButton") then
				companion.TextTransparency = 1
				props.TextTransparency = 0
			end
			if companion:IsA("ImageLabel") or companion:IsA("ImageButton") then
				companion.ImageTransparency = 1
				props.ImageTransparency = 0
			end
			if next(props) ~= nil then
				play(companion, notificationInfo(), props)
			end
		end
	end

	if hold <= 0 then
		return true
	end

	task.delay(hold, function()
		if rec.gen ~= gen then
			return
		end
		if not isAlive(instance) then
			return
		end

		rec.closing = true

		local hideProps = {}
		if options.targetBackgroundTransparency ~= nil then
			hideProps.BackgroundTransparency = 1
		end
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			hideProps.TextTransparency = 1
		end
		if next(hideProps) ~= nil then
			play(instance, closeInfo(), hideProps)
		end

		for _, companion in ipairs(companions) do
			if isAlive(companion) then
				local props = {}
				if companion:IsA("TextLabel") or companion:IsA("TextButton") then
					props.TextTransparency = 1
				end
				if companion:IsA("ImageLabel") or companion:IsA("ImageButton") then
					props.ImageTransparency = 1
				end
				if next(props) ~= nil then
					play(companion, closeInfo(), props)
				end
			end
		end

		local tween = play(scale, closeInfo(), { Scale = Config.CloseScaleTo })
		tween.Completed:Connect(function(playbackState)
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end
			if rec.gen ~= gen then
				return
			end
			if not isAlive(instance) then
				return
			end
			instance.Visible = false
			scale.Scale = 1
			rec.closing = false
			if options.destroy then
				instance:Destroy()
			end
		end)
	end)

	return true
end

return UIAnimation
