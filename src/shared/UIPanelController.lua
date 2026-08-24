--// UI Panel Controller
--// Place in: ReplicatedStorage > Shared
--// Single place that decides which main HUD panel is visible. Client scripts
--// register their frame (+ optional dim) once, then call Open / Close instead
--// of showing themselves independently. Opening one panel hides every other
--// registered main panel instantly; the requested panel still uses UIAnimation
--// so existing open/close motion is unchanged.

local Shared = script.Parent
local UIAnimation = require(Shared:WaitForChild("UIAnimation"))

local UIPanelController = {}

local panels = {} -- [id] = { frame = GuiObject, dim = GuiObject? }

local function isAlive(instance)
	return instance ~= nil and instance.Parent ~= nil
end

function UIPanelController.Register(id, frame, dim)
	if type(id) ~= "string" or id == "" then
		warn("[UIPanelController] Register needs a non-empty panel id")
		return false
	end
	if not isAlive(frame) then
		warn("[UIPanelController] Register(" .. id .. ") skipped - frame is missing")
		return false
	end

	panels[id] = {
		frame = frame,
		dim = dim,
	}
	return true
end

function UIPanelController.IsVisible(id)
	local entry = panels[id]
	return entry ~= nil and isAlive(entry.frame) and entry.frame.Visible == true
end

local function hideEntry(entry)
	if not entry or not isAlive(entry.frame) then
		return
	end
	UIAnimation.Hide(entry.frame, entry.dim)
end

function UIPanelController.HideAll()
	for _, entry in pairs(panels) do
		hideEntry(entry)
	end
end

function UIPanelController.Open(id)
	local entry = panels[id]
	if not entry then
		warn("[UIPanelController] Open skipped - unknown panel " .. tostring(id))
		return false
	end
	if not isAlive(entry.frame) then
		warn("[UIPanelController] Open skipped - panel " .. tostring(id) .. " is missing")
		return false
	end

	for otherId, other in pairs(panels) do
		if otherId ~= id then
			hideEntry(other)
		end
	end

	return UIAnimation.Open(entry.frame, entry.dim)
end

function UIPanelController.Close(id)
	local entry = panels[id]
	if not entry then
		warn("[UIPanelController] Close skipped - unknown panel " .. tostring(id))
		return false
	end
	if not isAlive(entry.frame) then
		return false
	end

	return UIAnimation.Close(entry.frame, entry.dim)
end

return UIPanelController
