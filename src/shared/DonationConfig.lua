--// Donation Config (shared)
--// Single source of truth for the Robux donation tiers, sold as Developer
--// Products. Used by DonationService (server) to validate/prompt purchases
--// and match an incoming receipt back to a tier, and by
--// DonationBoardController (client) to know which tier each board card's
--// Buy button should request.
--//
--// To add a new tier: create the Developer Product in the Creator
--// Dashboard, build its card under Templates.DonationBoard's Grid (same
--// convention TrailConfig's cards use in ShopUI), then add one entry below.
--// No other script changes needed.
--//
--// Id          - internal key, also used in the chat announcement lookup.
--// CardName    - the card's Instance name under the board's Grid (built in Studio).
--// ProductId   - the Developer Product's numeric Id.
--// Price       - Robux, display-only; the real charge is whatever the
--//               Developer Product itself is configured for on Roblox.
--// Message     - chat announcement template; "{player}" is replaced with the donor's name.
--//
--// ############################################################################
--// # CALIBRATE BEFORE LAUNCH: every ProductId below is 0 (a placeholder).     #
--// # Go to Creator Dashboard > Monetization > Developer Products, copy each   #
--// # product's real numeric Id, and paste it in below. Nothing works -        #
--// # PromptProductPurchase silently fails and ProcessReceipt can never match  #
--// # a tier - until these are real. DonationService warns on startup for any  #
--// # tier still left at 0.                                                    #
--// ############################################################################

local Config = {}

Config.SpecialThreshold = 1000   -- Robux; donations at/above this get the stronger announcement + effects
Config.LegendaryThreshold = 5000 -- Robux; donations at/above this get the biggest announcement + effects

Config.Items = {
	{
		Id = "SmallSupport", CardName = "SmallSupportCard", ProductId = 3651340014,
		Name = "Small Support", Icon = "🐧", Price = 10,
		Description = "Every bit helps keep Waddle Obby running!",
		Message = "💸 {player} donated 10 Robux to support Waddle Obby! 🐧",
	},
	{
		Id = "Supporter", CardName = "SupporterCard", ProductId = 3651344111,
		Name = "Supporter", Icon = "🐧", Price = 20,
		Description = "Thanks for backing the Waddle crew!",
		Message = "💸 {player} donated 20 Robux to support Waddle Obby! 🐧",
	},
	{
		Id = "BigSupport", CardName = "BigSupportCard", ProductId = 3651349687,
		Name = "Big Support", Icon = "💎", Price = 50,
		Description = "A big boost toward future updates!",
		Message = "💎 {player} donated 50 Robux to support Waddle Obby! 💎",
	},
	{
		Id = "SuperSupporter", CardName = "SuperSupporterCard", ProductId = 3651354339,
		Name = "Super Supporter", Icon = "👑", Price = 100,
		Description = "You're officially a Super Supporter!",
		Message = "👑 {player} donated 100 Robux as a Super Supporter! 👑",
	},
	{
		Id = "VIPSupporter", CardName = "VIPSupporterCard", ProductId = 3651359449,
		Name = "VIP Supporter", Icon = "🌟", Price = 1000,
		Description = "VIP status - our biggest thanks!",
		Message = "🌟 {player} became a VIP Supporter with a 1,000 Robux donation! 🌟",
	},
	{
		Id = "WaddleLegend", CardName = "WaddleLegendCard", ProductId = 3651363274,
		Name = "Waddle Legend", Icon = "🏆", Price = 5000,
		Description = "Legendary support - you're in the Hall of Fame!",
		Message = "👑 {player} became a Waddle Legend with a 5,000 Robux donation! 🔥",
	},
}

local byId, byProductId = {}, {}
for _, item in ipairs(Config.Items) do
	byId[item.Id] = item
	byProductId[item.ProductId] = item
end
byProductId[0] = nil -- placeholders never resolve to a tier, even before they're filled in

function Config.get(id)
	return byId[id]
end

function Config.getByProductId(productId)
	return byProductId[productId]
end

function Config.formatMessage(item, playerName)
	return (item.Message:gsub("{player}", playerName))
end

function Config.isSpecial(item)
	return item.Price >= Config.SpecialThreshold
end

function Config.isLegendary(item)
	return item.Price >= Config.LegendaryThreshold
end

return Config
