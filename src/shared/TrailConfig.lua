--// Trail Config (shared)
--// The Shop sells ONLY cosmetic trails - no gameplay-affecting items. This is
--// the single source of truth for what's directly purchasable with Coins, in
--// shop display order. Used by ShopService (server) to price/validate
--// purchases, by EquipService (server) to recognize a name as a valid,
--// equippable trail alongside the existing egg-only trails in
--// RewardsCatalog, and by ShopClient (client) to render each card.
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
--//
--// Note: "Rainbow Trail" is intentionally the SAME trail RewardsCatalog
--// already offers as a rare Egg drop (same ReplicatedStorage.Trails
--// template, same Inventory key) - buying it here is just a guaranteed,
--// non-RNG way to get it. Every other name below is Shop-exclusive.

local TrailConfig = {}

TrailConfig.Items = {
	{ Name = "Blue Trail",      Price = 300,  CardName = "BlueTrailCard",      Color = Color3.fromRGB(80, 160, 255) },
	{ Name = "Fire Trail",      Price = 450,  CardName = "FireTrailCard",      Color = Color3.fromRGB(255, 120, 60) },
	{ Name = "Rainbow Trail",   Price = 1200, CardName = "RainbowTrailCard",   Color = Color3.fromRGB(255, 120, 200) },
	{ Name = "Lightning Trail", Price = 700,  CardName = "LightningTrailCard", Color = Color3.fromRGB(255, 240, 120) },
	{ Name = "Galaxy Trail",    Price = 900,  CardName = "GalaxyTrailCard",    Color = Color3.fromRGB(140, 90, 255) },
	{ Name = "Neon Trail",      Price = 600,  CardName = "NeonTrailCard",      Color = Color3.fromRGB(80, 255, 190) },
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
