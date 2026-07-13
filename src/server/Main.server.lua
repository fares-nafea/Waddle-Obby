local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local Coin = Instance.new("IntValue")
	Coin.Name = "Coins"
	Coin.Value = 0
	Coin.Parent = leaderstats
end)
