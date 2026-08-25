--// Trail Config (shared)
--// The Shop sells ONLY cosmetic trails - no gameplay-affecting items. This is
--// the single source of truth for what's directly purchasable with Coins, in
--// shop display order. Used by ShopService (server) to price/validate
--// purchases, by EquipService (server) to recognize a name as a valid,
--// equippable trail, and by ShopClient (client) to render each card.
--//
--// To add a new trail: build its Trail template (Attachment0/Attachment1/
--// Trail, same shape as the others) in ReplicatedStorage.Trails, build its
--// card under StarterGui.ShopUI.ShopFrame.Grid, then add one entry below.
--// No other script changes needed.
--//
--// Name     - matches the Trail template in ReplicatedStorage.Trails, and
--//            the ownership marker tracked under a player's Inventory.
--// CardName - the card's Instance name under ShopFrame.Grid (built in Studio).
--// Color    - swatch color for the card's Trail preview.

local TrailConfig = {}

TrailConfig.Items = {
	{ Name = "Sunset",      Price = 100,  CardName = "SunsetTrailCard"},
	{ Name = "Ocean",      Price = 250,  CardName = "OceanTrailCard"},
	{ Name = "Forest",      Price = 500,  CardName = "ForestTrailCard"},
	{ Name = "Royal",      Price = 1000,  CardName = "RoyalTrailCard"},
	{ Name = "Fire",      Price = 1500,  CardName = "FireTrailCard"},
	{ Name = "Toxic",      Price = 2500,  CardName = "ToxicTrailCard"},
	{ Name = "Aurora",      Price = 4000,  CardName = "AuroraTrailCard"},
	{ Name = "Candy",      Price = 6000,  CardName = "CandyTrailCard"},
	{ Name = "Cyber",      Price = 8000,  CardName = "CyberTrailCard"},
	{ Name = "Lava",      Price = 10000,  CardName = "LavaTrailCard"},
	{ Name = "Galaxy",      Price = 13000,  CardName = "GalaxyTrailCard"},
	{ Name = "Ice",      Price = 16000,  CardName = "IceTrailCard"},
	{ Name = "Purple Flame",      Price = 20000,  CardName = "PurpleFlameTrailCard"},
	{ Name = "Electric",      Price = 25000,  CardName = "ElectricTrailCard"},
	{ Name = "Dragon",      Price = 30000,  CardName = "DragonTrailCard"},
	{ Name = "Rainbow",      Price = 40000,  CardName = "RainbowTrailCard"},
	{ Name = "Cosmic",      Price = 50000,  CardName = "CosmicTrailCard"},
	{ Name = "Golden",      Price = 65000,  CardName = "GoldenTrailCard"},
	{ Name = "Diamond",      Price = 80000,  CardName = "DiamondTrailCard"},
	{ Name = "Waddle Legend",      Price = 100000,  CardName = "WaddleLegendTrailCard"},
	{ Name = "Celestial",      Price = 110000,  CardName = "CelestialTrailCard"},

}

-- look up one shop trail by its ReplicatedStorage.Trails / ownership-marker name
function TrailConfig.get(trailName)
	for _, item in ipairs(TrailConfig.Items) do
		if item.Name == trailName then
			return item
		end
	end
	return nil
end

return TrailConfig
