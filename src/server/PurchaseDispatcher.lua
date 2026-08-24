--// Purchase Dispatcher (module)
--// Place in: ServerScriptService (ModuleScript)
--// The single place MarketplaceService.ProcessReceipt is ever assigned.
--// Roblox only allows one ProcessReceipt callback per game - assigning it
--// twice silently replaces the first, which would break whichever feature
--// (Donations, Boosts, ...) registered first. Every Developer-Product
--// feature registers a handler here by ProductId instead of touching
--// MarketplaceService.ProcessReceipt directly.
--//
--// Also owns receipt idempotency centrally: a PurchaseId is unique across
--// EVERY product a player ever buys, not just one feature's products, so
--// the "have we already granted this" DataStore check belongs here once,
--// not duplicated per feature. A handler is only ever invoked for a
--// PurchaseId that has never been granted before - same UpdateAsync-guard
--// idiom GlobalLeaderboardService/DonationService already used individually.

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local receiptStore = DataStoreService:GetDataStore("PurchaseReceipts_v11")

local PurchaseDispatcher = {}

local handlers = {} -- ProductId -> function(player, receiptInfo)

-- register the function to call when a receipt for `productId` is confirmed
-- new (never granted before). Called at most once per PurchaseId, ever.
function PurchaseDispatcher.RegisterHandler(productId, handler)
	handlers[productId] = handler
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retry once they're back
	end

	local handler = handlers[receiptInfo.ProductId]
	if not handler then
		warn("[PurchaseDispatcher] receipt for unregistered ProductId " .. tostring(receiptInfo.ProductId)
			.. " - granting nothing, but acknowledging so Roblox stops retrying it")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local alreadyGranted = false

	local ok = pcall(function()
		receiptStore:UpdateAsync(receiptInfo.PurchaseId, function(old)
			if old then
				alreadyGranted = true
				return old
			end
			return true
		end)
	end)

	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- DataStore hiccup, let Roblox retry
	end

	if not alreadyGranted then
		handler(player, receiptInfo)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return PurchaseDispatcher
