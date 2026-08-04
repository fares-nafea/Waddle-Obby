--// Daily Reward Service
--// Place in: ServerScriptService
--// Handles the Daily Reward claim (StarterGui.DailyRewardUI and the floating
--// Gift Button both talk to this through ReplicatedStorage.Remotes.
--// DailyRewardRemote). Server-authoritative: the claim window, streak, and
--// reward day are always computed here from the player's own
--// LastClaimTime/DailyStreak values - the client only ever sends "Claim"
--// with no payload, so there is nothing for it to fake.
--//
--// Isolated feature: this script only touches LastClaimTime/DailyStreak
--// (added to DataService's save alongside leaderstats.Coins - see
--// DataService.server.lua) and leaderstats.Coins itself. It never reads or
--// writes Inventory, EquippedTrail, BestTimes, or UnlockedObby, so it can't
--// affect Shop, Profile, Progression, or Obby completion.
--//
--// Reward Handlers: Coins is the only reward Type today, but granting is
--// dispatched through the RewardHandlers table below instead of an
--// if/elseif chain - adding a new Type later (e.g. "SpinTicket") is one
--// handler function here plus one DailyRewardConfig entry, no existing
--// handler or dispatch code changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DailyRewardRemote")
local DailyRewardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewardConfig"))

local CLAIM_INTERVAL = 24 * 60 * 60 -- seconds until the next reward becomes claimable
local STREAK_GRACE = 48 * 60 * 60   -- claim within this window of the last one to keep the streak alive; beyond it, the streak resets to 1

local debounce = {}

--=============== REWARD HANDLERS ===============--
-- each handler receives (player, rewardData) and applies it; add a new Type
-- by adding one function here and one matching Type in DailyRewardConfig
local RewardHandlers = {}

function RewardHandlers.Coins(player, rewardData)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then return end

	coins.Value += rewardData.Amount
end

local function grantReward(player, day)
	local rewardData = DailyRewardConfig.getReward(day)
	local handler = rewardData and RewardHandlers[rewardData.Type]

	if not handler then
		warn("[DailyRewardService] no RewardHandler for Type \"" .. tostring(rewardData and rewardData.Type) .. "\" (day " .. day .. ")")
		return nil
	end

	handler(player, rewardData)
	return rewardData
end

--=============== CLAIM ===============--
local function secondsUntilClaimable(lastClaimTime)
	if lastClaimTime.Value == 0 then return 0 end
	return math.max(0, (lastClaimTime.Value + CLAIM_INTERVAL) - os.time())
end

local function tryClaim(player)
	if debounce[player] then return end
	debounce[player] = true

	local lastClaimTime = player:FindFirstChild("LastClaimTime")
	local dailyStreak = player:FindFirstChild("DailyStreak")
	if not lastClaimTime or not dailyStreak then
		debounce[player] = nil
		return
	end

	local remaining = secondsUntilClaimable(lastClaimTime)
	if remaining > 0 then
		DailyRewardRemote:FireClient(player, "OnCooldown", remaining)
		debounce[player] = nil
		return
	end

	local now = os.time()
	local sinceLastClaim = now - lastClaimTime.Value

	if lastClaimTime.Value == 0 or sinceLastClaim > STREAK_GRACE then
		dailyStreak.Value = 1 -- first-ever claim, or missed a day: streak restarts
	else
		dailyStreak.Value += 1 -- claimed within the grace window: streak continues
	end

	-- capped at MaxDay - a streak longer than that keeps re-granting the
	-- MaxDay reward, it never wraps back around to Day 1 (see DailyRewardConfig)
	local day = math.min(dailyStreak.Value, DailyRewardConfig.MaxDay)
	local rewardData = grantReward(player, day)

	lastClaimTime.Value = now

	if rewardData then
		DailyRewardRemote:FireClient(player, "Claimed", day, rewardData)
	end

	task.wait(0.3)
	debounce[player] = nil
end

DailyRewardRemote.OnServerEvent:Connect(function(player, action)
	if action == "Claim" then
		tryClaim(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	debounce[player] = nil
end)
