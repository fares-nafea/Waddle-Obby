--// Rewards Catalog (shared)
--// The single source of truth for every egg reward.
--// Used by EggService (server) to roll, and by the Collection UI (client)
--// to display trails/skins. Add new items here only.

local Catalog = {}

Catalog.RarityColors = {
	Common    = Color3.fromRGB(180, 200, 220),
	Rare      = Color3.fromRGB(80, 160, 255),
	Epic      = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
}

-- type = "Trail" or "Skin"
-- weight = drop chance (higher = more common)
-- color  = shown as the swatch in the UI (and used later when equipping trails)
Catalog.Rewards = {
	-- Trails
	{ name = "Frost Trail",   rarity = "Common",    type = "Trail", weight = 40, color = Color3.fromRGB(150, 220, 255) },
	{ name = "Snow Trail",    rarity = "Common",    type = "Trail", weight = 35, color = Color3.fromRGB(240, 248, 255) },
	{ name = "Aqua Trail",    rarity = "Rare",      type = "Trail", weight = 18, color = Color3.fromRGB(60, 200, 220) },
	{ name = "Rainbow Trail", rarity = "Epic",      type = "Trail", weight = 8,  color = Color3.fromRGB(255, 120, 200) },
	{ name = "Aurora Trail",  rarity = "Legendary", type = "Trail", weight = 2,  color = Color3.fromRGB(120, 255, 180) },
}

-- look up one reward by name
function Catalog.get(name)
	for _, r in ipairs(Catalog.Rewards) do
		if r.name == name then
			return r
		end
	end
	return nil
end

return Catalog
