--// Shop Config (shared)
--// The single source of truth for what's for sale and how much it costs.
--// Used by ShopService (server) to price/validate purchases, and by
--// ShopClient (client) to render each card's PriceLabel.
--//
--// Keyed by the item's name in ServerStorage.Items (also the name used for
--// the ownership/equip markers under a player - see ShopService).

local ShopConfig = {}

-- Price is the only number you should need to touch to rebalance an item.
ShopConfig.Items = {
	SpeedCoil = {
		DisplayName = "Speed Coil",
		Price = 500,
	},
}

-- look up one shop item by its ServerStorage.Items name
function ShopConfig.get(itemName)
	return ShopConfig.Items[itemName]
end

return ShopConfig
