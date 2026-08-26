local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trails = ReplicatedStorage:WaitForChild("Trails")

local StarterGui = game:GetService("StarterGui")
local ShopUI = StarterGui:WaitForChild("ShopUI")
local ShopFrame = ShopUI:WaitForChild("ShopFrame")
local Grid = ShopFrame:WaitForChild("Grid")

for _, Trail in Trails:GetChildren() do

	local CardName = Trail.Name:gsub(" Trail$", "") .. "TrailCard"
	local Card = Grid:FindFirstChild(CardName) 

	if Card and Card:IsA("Frame") then

		local Preview = Card:WaitForChild("Preview")
		local UIGradient = Preview:WaitForChild("UIGradient")

		UIGradient.Color = Trail.Trail.Color

	else
		warn("Card not found:", CardName)
	end
end