--// Donation Service
--// Place in: ServerScriptService
--// Handles Robux donations sold as Developer Products.
--// DonationBoardController (client) only ever asks to prompt a purchase -
--// this script decides whether that ask is valid and calls
--// MarketplaceService:PromptProductPurchase itself. grantDonation below is
--// the ONLY place a donation is ever actually granted (the chat
--// announcement + celebration effects); nothing here trusts a
--// client-reported tier or price - receipt.ProductId from Roblox is the
--// sole source of truth, looked up fresh against DonationConfig every time.
--//
--// Idempotency + the actual MarketplaceService.ProcessReceipt assignment
--// both live in PurchaseDispatcher, shared with every other
--// Developer-Product feature (e.g. BoostService) - Roblox only allows one
--// ProcessReceipt callback per game, so a second feature assigning it
--// directly would silently break this one. This script only registers a
--// handler for its own ProductIds; PurchaseDispatcher guarantees that
--// handler is called at most once per PurchaseId, ever.
--//
--// Isolated feature: donations never touch leaderstats.Coins, Inventory, or
--// any other DataService-owned value - a donation's only "reward" is the
--// announcement + effects below, same self-contained philosophy
--// DailyRewardService already uses for its own claim flow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local DonationRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DonationRemote")
local DonationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DonationConfig"))
local PurchaseDispatcher = require(ServerScriptService:WaitForChild("PurchaseDispatcher"))

local DONATE_COOLDOWN = 1 -- seconds; light debounce against a client button-mash spamming PromptProductPurchase
local lastRequest = {}

--=============== CALIBRATION WARNING ===============--
for _, item in ipairs(DonationConfig.Items) do
	if item.ProductId == 0 then
		warn("[DonationService] " .. item.Id .. " has no real ProductId set in DonationConfig - "
			.. "donations for it will fail until you paste in the real Developer Product Id from the Creator Dashboard")
	end
end

--=============== ANNOUNCEMENT ===============--
-- TextChannel:DisplaySystemMessage is a client-only API - the server only
-- ever decides WHAT to say (item + player come from this script's own
-- trusted state, never from a client), then hands the finished string to
-- every client over the same DonationRemote the purchase request already
-- uses. DonationBoardController is the only place that actually calls
-- DisplaySystemMessage.
local function announce(player, item)
	local message = DonationConfig.formatMessage(item, player.Name)
	DonationRemote:FireAllClients("Announce", message)
end

--=============== EFFECTS ===============--
-- all built as plain Instances parented into the donor's Character - no
-- RemoteEvent needed, server-owned Instances just replicate to everyone
-- looking, same trust model GlobalWorldLeaderboardService already relies on
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 208, 40),  -- gold
	Color3.fromRGB(255, 255, 255), -- white
	Color3.fromRGB(108, 140, 255), -- blue
	Color3.fromRGB(255, 99, 99),   -- red
}

local function spawnConfetti(character, legendary)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DonationConfettiAttachment"
	attachment.Position = Vector3.new(0, 3, 0)
	attachment.Parent = hrp

	local burstPerColor = legendary and 20 or 9

	for _, color in ipairs(CONFETTI_COLORS) do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.Size = NumberSequence.new(legendary and 0.6 or 0.35)
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(6, 12)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 0
		emitter.Parent = attachment
		emitter:Emit(burstPerColor)
	end

	Debris:AddItem(attachment, 3)
end

local function spawnHighlight(character, legendary)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DonationHighlight"
	highlight.FillColor = legendary and Color3.fromRGB(255, 208, 40) or Color3.fromRGB(108, 140, 255)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = legendary and 0.5 or 0.7
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	Debris:AddItem(highlight, legendary and 6 or 3)
end

local function playSound(character, legendary)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local template = SoundService:FindFirstChild(legendary and "DonationLegendarySound" or "DonationSound")
	if not template then return end

	local sound = template:Clone()
	sound.Parent = hrp
	sound:Play()

	Debris:AddItem(sound, 8)
end

local function celebrate(player, item)
	local character = player.Character
	if not character then return end

	local legendary = DonationConfig.isLegendary(item)

	spawnConfetti(character, legendary)
	spawnHighlight(character, legendary)
	playSound(character, legendary)
end

--=============== PURCHASE REQUEST ===============--
local function tryPrompt(player, tierId)
	local last = lastRequest[player]
	if last and (os.clock() - last) < DONATE_COOLDOWN then return end
	lastRequest[player] = os.clock()

	local item = DonationConfig.get(tierId)
	if not item or item.ProductId == 0 then return end

	MarketplaceService:PromptProductPurchase(player, item.ProductId)
end

DonationRemote.OnServerEvent:Connect(function(player, action, tierId)
	if action ~= "Donate" then return end
	if type(tierId) ~= "string" then return end

	tryPrompt(player, tierId)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

--=============== RECEIPT PROCESSING ===============--
-- called by PurchaseDispatcher at most once per PurchaseId, ever - this is
-- the only place a donation is actually granted
local function grantDonation(player, receiptInfo)
	local item = DonationConfig.getByProductId(receiptInfo.ProductId)
	if not item then
		-- shouldn't happen: PurchaseDispatcher only calls this for ProductIds
		-- this script itself registered below
		warn("[DonationService] no DonationConfig entry for ProductId " .. tostring(receiptInfo.ProductId))
		return
	end

	announce(player, item)
	celebrate(player, item)
end

for _, item in ipairs(DonationConfig.Items) do
	if item.ProductId ~= 0 then
		PurchaseDispatcher.RegisterHandler(item.ProductId, grantDonation)
	end
end
