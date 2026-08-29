local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local shiftLock = false

local OFF_IMAGE = "rbxasset://textures/ui/mouseLock_off@2x.png"
local ON_IMAGE = "rbxasset://textures/ui/mouseLock_on@2x.png"


--------------------------------------------------
-- GUI
--------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")

local gui = playerGui:WaitForChild("ShiftLockGui")
local button = gui:WaitForChild("ShiftLockButton")

-- Show button only on Touch devices
button.Visible = UserInputService.TouchEnabled


--------------------------------------------------
-- SHIFT LOCK
--------------------------------------------------

local function setShiftLock(enabled)

	shiftLock = enabled

	if button.Visible then
		if shiftLock then
			button.Image = ON_IMAGE
		else
			button.Image = OFF_IMAGE
		end
	end

end


local function toggleShiftLock()

	setShiftLock(not shiftLock)

end


--------------------------------------------------
-- MOBILE
--------------------------------------------------

button.Activated:Connect(function()

	toggleShiftLock()

end)


--------------------------------------------------
-- PC
--------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)

	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then

		toggleShiftLock()

	end

end)


--------------------------------------------------
-- CHARACTER
--------------------------------------------------

player.CharacterAdded:Connect(function(character)

	shiftLock = false

	button.Image = OFF_IMAGE

	local humanoid = character:WaitForChild("Humanoid")

	humanoid.AutoRotate = true

end)


--------------------------------------------------
-- ROTATION
--------------------------------------------------

RunService.RenderStepped:Connect(function()

	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end


	if shiftLock then

		humanoid.AutoRotate = false

		-- Lock mouse on PC
		if not UserInputService.TouchEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end

		local direction = camera.CFrame.LookVector

		local flatDirection = Vector3.new(
			direction.X,
			0,
			direction.Z
		)

		if flatDirection.Magnitude > 0.001 then

			root.CFrame = CFrame.lookAt(
				root.Position,
				root.Position + flatDirection.Unit
			)

		end

	else

		humanoid.AutoRotate = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	end

end)