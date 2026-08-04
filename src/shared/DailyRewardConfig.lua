--// Daily Reward Config (shared)
--// Single source of truth for the 7-day daily login reward ladder. Day index
--// caps at MaxDay - a streak longer than that keeps re-granting the Day 7
--// reward every day instead of cycling back to Day 1.
--//
--// Reward Type is dispatched by DailyRewardService through a RewardHandlers
--// table, not an if/elseif chain. Coins is the only Type today; adding a new
--// one (e.g. "SpinTicket") later is one entry here plus one handler function
--// in DailyRewardService - no existing entry or handler changes.
--//
--// Type   - looked up in DailyRewardService.RewardHandlers.
--// Amount - Coins-specific payload; a future Type defines its own fields.

local Config = {}

Config.MaxDay = 7

Config.Days = {
	[1] = { Type = "Coins", Amount = 100 },
	[2] = { Type = "Coins", Amount = 250 },
	[3] = { Type = "Coins", Amount = 500 },
	[4] = { Type = "Coins", Amount = 750 },
	[5] = { Type = "Coins", Amount = 1000 },
	[6] = { Type = "Coins", Amount = 1500 },
	[7] = { Type = "Coins", Amount = 2500 },
}

-- the reward for `day`, clamped to MaxDay so a streak past Day 7 keeps
-- re-granting the Day 7 reward instead of erroring or cycling back to Day 1
function Config.getReward(day)
	local clamped = math.min(day, Config.MaxDay)
	return Config.Days[clamped]
end

return Config
