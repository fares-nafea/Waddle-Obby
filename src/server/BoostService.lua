--// Boost Service (module)
--// Place in: ServerScriptService (ModuleScript)
--// Owns the 2X Coins Boost: Developer Product purchases, the banked
--// play-time countdown, and the reusable coin-multiplier function every
--// coin-granting script (currently just TimeService) calls through instead
--// of touching leaderstats.Coins directly. Required once by TimeService,
--// same shape as LeaderboardService.lua being required by
--// WorldLeaderboardService - this module's own top-level code (the ticking
--// loop, RemoteEvent listener, PurchaseDispatcher registration) runs then.
--//
--// Play-time only: BoostRemainingSeconds only ticks down for players who
--// are actually online (see the loop below, which only ever iterates
--// Players:GetPlayers()). Leaving freezes it exactly where it was -
--// DataService saves/loads it like any other field, so it resumes ticking
--// from the same banked value on rejoin, whenever that is.
--//
--// Stacking: a purchase always ADDS DurationSeconds to whatever's already
--// banked (10 min remaining + a 30 min purchase = 40 min remaining) - no
--// "already expired vs still active" branching needed, since there's no
--// wall-clock expiry to compare against.
--//
--// Security: the client never sends a duration or an amount, only a tier
--// id to request a prompt (same as DonationService/ShopService). The
--// actual grant happens in grantBoost below, called by PurchaseDispatcher
--// off receipt.ProductId - the sole source of truth for what was bought.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local BoostRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoostRemote")
local BoostConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoostConfig"))
local PurchaseDispatcher = require(ServerScriptService:WaitForChild("PurchaseDispatcher"))

local BoostService = {}

local REQUEST_COOLDOWN = 1 -- seconds; light debounce against a client button-mash spamming PromptProductPurchase
local TICK_INTERVAL = 1    -- seconds between each online player's countdown decrement

local lastRequest = {}

--=============== CALIBRATION WARNING ===============--
for _, item in ipairs(BoostConfig.Items) do
	if item.ProductId == 0 then
		warn("[BoostService] " .. item.Id .. " has no real ProductId set in BoostConfig - "
			.. "purchases for it will fail until you paste in the real Developer Product Id from the Creator Dashboard")
	end
end

--=============== MULTIPLIER (the reusable integration point) ===============--
-- true if `player` currently has 2X Coins active, permanent or timed
function BoostService.IsActive(player)
	local permanent = player:FindFirstChild("BoostPermanent")
	if permanent and permanent.Value then
		return true
	end

	local remaining = player:FindFirstChild("BoostRemainingSeconds")
	return remaining ~= nil and remaining.Value > 0
end

function BoostService.GetMultiplier(player)
	return BoostService.IsActive(player) and BoostConfig.Multiplier or 1
end

-- the reusable function every coin-granting script should call instead of
-- mutating leaderstats.Coins directly. Returns the amount actually awarded
-- (already multiplied) so callers can report the real number back to the client.
function BoostService.GrantCoins(player, baseAmount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then return 0 end

	local awarded = baseAmount * BoostService.GetMultiplier(player)
	coins.Value += awarded
	return awarded
end

--=============== PURCHASE REQUEST ===============--
local function tryPrompt(player, tierId)
	local last = lastRequest[player]
	if last and (os.clock() - last) < REQUEST_COOLDOWN then return end
	lastRequest[player] = os.clock()

	local item = BoostConfig.get(tierId)
	if not item or item.ProductId == 0 then return end

	MarketplaceService:PromptProductPurchase(player, item.ProductId)
end

BoostRemote.OnServerEvent:Connect(function(player, action, tierId)
	if action ~= "Boost" then return end
	if type(tierId) ~= "string" then return end

	tryPrompt(player, tierId)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

--=============== RECEIPT PROCESSING ===============--
-- called by PurchaseDispatcher at most once per PurchaseId, ever - this is
-- the only place a boost is actually granted
local function grantBoost(player, receiptInfo)
	local item = BoostConfig.getByProductId(receiptInfo.ProductId)
	if not item then
		-- shouldn't happen: PurchaseDispatcher only calls this for ProductIds
		-- this script itself registered below
		warn("[BoostService] no BoostConfig entry for ProductId " .. tostring(receiptInfo.ProductId))
		return
	end

	if item.Permanent then
		local permanent = player:FindFirstChild("BoostPermanent")
		if permanent then
			permanent.Value = true
		end
		return
	end

	-- a timed purchase on top of an already-permanent boost is a harmless
	-- no-op (the multiplier's already maxed) - still fine to keep the Robux,
	-- same as any Developer Product a player can buy again after already
	-- owning the effect
	if BoostService.IsActive(player) then
		local permanent = player:FindFirstChild("BoostPermanent")
		if permanent and permanent.Value then return end
	end

	local remaining = player:FindFirstChild("BoostRemainingSeconds")
	if remaining then
		remaining.Value += item.DurationSeconds
	end
end

for _, item in ipairs(BoostConfig.Items) do
	if item.ProductId ~= 0 then
		PurchaseDispatcher.RegisterHandler(item.ProductId, grantBoost)
	end
end

--=============== COUNTDOWN (play-time only) ===============--
-- only ever touches players currently in Players:GetPlayers() - leaving the
-- game simply stops this loop from seeing that player, freezing their
-- banked time exactly where it was until DataService saves it
task.spawn(function()
	while true do
		task.wait(TICK_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			local permanent = player:FindFirstChild("BoostPermanent")
			if not (permanent and permanent.Value) then
				local remaining = player:FindFirstChild("BoostRemainingSeconds")
				if remaining and remaining.Value > 0 then
					remaining.Value = math.max(0, remaining.Value - TICK_INTERVAL)
				end
			end
		end
	end
end)

return BoostService
