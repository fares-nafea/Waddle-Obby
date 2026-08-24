--// Donation Board Controller
--// Place in: StarterPlayer > StarterPlayerScripts
--// Wires the Buy button on each tier card of the hand-placed world
--// Donation Board (a clone of Templates.DonationBoard in workspace, named
--// "DonationBoard") to ReplicatedStorage.Remotes.DonationRemote. Every
--// card's icon/name/price/description is already baked in (built in
--// Studio/JSON, same convention ShopClient's trail cards use) - this
--// script only finds them and connects clicks, it never creates or edits
--// an Instance.
--//
--// This is the ENTIRE client footprint of the donation system: the actual
--// purchase (MarketplaceService:PromptProductPurchase), receipt
--// verification, the chat announcement, and every celebration effect are
--// 100% server-side (DonationService.server.lua) - this script never hears
--// a result back, it just asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DonationRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DonationRemote")
local DonationConfig = require(Shared:WaitForChild("DonationConfig"))
local UIAnimation = require(Shared:WaitForChild("UIAnimation"))

--=============== GLOBAL ANNOUNCEMENT ===============--
-- registered before the board lookup below (which can `return` early if the
-- board isn't placed in workspace yet) - every player should still see
-- donation announcements regardless of whether their own client found the
-- board. DisplaySystemMessage is a client-only API, so this is the ONLY
-- place it's called; DonationService only ever decides the message text and
-- broadcasts it over this same remote.
DonationRemote.OnClientEvent:Connect(function(action, message)
	if action ~= "Announce" then return end

	local ok, err = pcall(function()
		local channels = TextChatService:WaitForChild("TextChannels", 5)
		local channel = channels:WaitForChild("RBXGeneral", 5)
		channel:DisplaySystemMessage(message)
	end)

	if not ok then
		warn("[DonationBoardController] failed to display donation announcement: " .. tostring(err))
	end
end)

--=============== SETUP ===============--
-- no placement logic here by design: the "DonationBoard" Model (a clone of
-- Templates.DonationBoard) must already exist in workspace, wherever it was
-- hand-placed in Studio. This script never moves or creates it.
local model = workspace:WaitForChild("DonationBoard", 15)
if not model then
	warn("[DonationBoardController] workspace.DonationBoard not found - "
		.. "place a clone of Templates.DonationBoard in workspace, named \"DonationBoard\"")
	return
end

local boardPart = model:WaitForChild("BoardPart", 5)
local surfaceGui = boardPart and boardPart:WaitForChild("DonationBoardGui", 5)
local board = surfaceGui and surfaceGui:WaitForChild("Board", 5)
local grid = board and board:WaitForChild("Grid", 5)

if not grid then
	warn("[DonationBoardController] workspace.DonationBoard is missing BoardPart.DonationBoardGui.Board.Grid - "
		.. "make sure it's an unmodified clone of Templates.DonationBoard")
	return
end

--=============== BUTTON WIRING ============--
local DONATE_DEBOUNCE = 1 -- seconds; stops one double-click firing two purchase prompts
local lastClick = 0

for _, item in ipairs(DonationConfig.Items) do
	local card = grid:FindFirstChild(item.CardName)

	if card then
		local buyButton = card:FindFirstChild("BuyButton")

		if buyButton then
			UIAnimation.ButtonPress(buyButton)

			buyButton.MouseButton1Click:Connect(function()
				local now = os.clock()
				if now - lastClick < DONATE_DEBOUNCE then return end
				lastClick = now

				DonationRemote:FireServer("Donate", item.Id)
			end)
		else
			warn("[DonationBoardController] " .. item.CardName .. ".BuyButton not found - can't sell " .. item.Name)
		end
	else
		warn("[DonationBoardController] Grid." .. item.CardName .. " not found - can't sell " .. item.Name)
	end
end
