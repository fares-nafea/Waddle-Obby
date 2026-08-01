--// Reward Config (shared)
--// Defines how many coins a player earns for finishing an Obby. The payout is
--// randomized (math.random) within a range that depends on the Obby's
--// difficulty and how fast the run was - not a flat, predictable number.
--// Read by TimeService (server) right after it computes the
--// server-authoritative elapsed time for a finished run, so the random roll
--// itself always happens on the server - a client never sees or picks the
--// range, only the final rolled amount.
--//
--// Keyed by ObbyId (see ObbyConfig.getObbyId) - the same canonical id used by
--// Config.Overrides, BestTimes entries, and the leaderboard DataStores - not
--// by folder name. Any ObbyId with no entry here falls back to
--// RewardConfig.Default, so a new Obby keeps paying out sensible rewards
--// with zero config (same philosophy as ObbyConfig.Overrides).

local RewardConfig = {}

-- FastTime   finishing at/under this many seconds rolls the Fast range
-- SlowTime   finishing over this many seconds rolls the Slow range (Normal is between)
-- Fast/Normal/Slow = { Min, Max } passed straight to math.random(Min, Max)
RewardConfig.Rewards = {
	["1"] = {
		FastTime = .1,
		SlowTime = 120,
		Fast   = { Min = 200, Max = 700 },
		Normal = { Min = 100, Max = 400 },
		Slow   = { Min = 50,  Max = 200 },
	},
	["2"] = {
		FastTime = .1,
		SlowTime = 120,
		Fast   = { Min = 200, Max = 700 },
		Normal = { Min = 100, Max = 400 },
		Slow   = { Min = 50,  Max = 200 },
	},
	["3"] = {
		FastTime = .1,
		SlowTime = 120,
		Fast   = { Min = 500, Max = 1500 },
		Normal = { Min = 300, Max = 900 },
		Slow   = { Min = 100, Max = 500 },
	},
	["4"] = {
		FastTime = .1,
		SlowTime = 120,
		Fast   = { Min = 500, Max = 1500 },
		Normal = { Min = 300, Max = 900 },
		Slow   = { Min = 100, Max = 500 },
	},
}

RewardConfig.Default = {
	FastTime = .1,
	SlowTime = 120,
	Fast   = { Min = 150, Max = 400 },
	Normal = { Min = 75,  Max = 250 },
	Slow   = { Min = 25,  Max = 100 },
}

-- rolls the coin reward for finishing `obbyId` in `completionTime` seconds -
-- completionTime must be a server-computed elapsed time (see TimeService),
-- never a client-supplied value
function RewardConfig.GetReward(obbyId, completionTime)
	local cfg = RewardConfig.Rewards[obbyId] or RewardConfig.Default

	local tier
	if completionTime <= cfg.FastTime then
		tier = cfg.Fast
	elseif completionTime <= cfg.SlowTime then
		tier = cfg.Normal
	else
		tier = cfg.Slow
	end

	return math.random(tier.Min, tier.Max)
end

return RewardConfig
