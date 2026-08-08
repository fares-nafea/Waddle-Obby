--// Boost Config (shared)
--// Single source of truth for the 2X Coins Boost Developer Products. Used
--// by BoostService (server) to validate/prompt purchases and match an
--// incoming receipt back to a tier, and by BoostUIController (client) to
--// know which tier each panel button should request.
--//
--// No Robux price is stored here on purpose - MarketplaceService's own
--// purchase dialog always shows the product's real, current price, so
--// there's nothing to keep in sync or get stale.
--//
--// Id               - internal key.
--// ProductId        - the Developer Product's numeric Id.
--// DurationSeconds  - how much banked time a purchase adds (nil for Permanent).
--// Permanent        - true for the one-time "Forever" tier: sets BoostPermanent
--//                     instead of adding to BoostRemainingSeconds.
--//
--// ############################################################################
--// # CALIBRATE BEFORE LAUNCH: every ProductId below is 0 (a placeholder).     #
--// # Go to Creator Dashboard > Monetization > Developer Products, copy each   #
--// # product's real numeric Id, and paste it in below. Nothing works -        #
--// # PromptProductPurchase silently fails and ProcessReceipt can never match  #
--// # a tier - until these are real. BoostService warns on startup for any     #
--// # tier still left at 0.                                                    #
--// ############################################################################

local Config = {}

Config.Multiplier = 2 -- the "2X" - single source of truth so GetMultiplier and any display text stay in sync

Config.Items = {
	{ Id = "Boost10Min",   ProductId = 3652152586, Name = "10 Minutes", Icon = "🪙", DurationSeconds = 600 },
	{ Id = "Boost30Min",   ProductId = 3652157122, Name = "30 Minutes", Icon = "🪙", DurationSeconds = 1800 },
	{ Id = "Boost1Hour",   ProductId = 3652162597, Name = "1 Hour",     Icon = "🪙", DurationSeconds = 3600 },
	{ Id = "BoostForever", ProductId = 1941708787, Name = "Forever",    Icon = "🪙", Permanent = true },
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

return Config
