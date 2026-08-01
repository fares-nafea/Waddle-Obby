--// Obby Config (shared)
--// Optional per-Obby overrides. Obbys are auto-discovered from workspace.Stages
--// (one child folder = one Obby) so adding a new Obby needs zero code changes.
--// Only add an entry here if an Obby needs a non-default minimum time,
--// leaderboard size, display name, or reward tiers.
--//
--// Single source of truth for all per-Obby data (merged from the former
--// RewardConfig.lua - reward tiers now live in Config.Overrides too).
--//
--// ObbyId vs folder name: the folder Name (e.g. "Stage 1") is just a label -
--// it can be renamed freely for readability. The canonical ObbyId used
--// everywhere internally (DataStore keys, BestTimes entries, RemoteEvent
--// payloads) is the number extracted from that name via getObbyId, so
--// renaming "1" -> "Stage 1" keeps every player's existing best times and
--// leaderboard entries intact (both extract to ObbyId "1").

local Config = {}

Config.Defaults = {
	MinTime = .3,          -- fastest a finish can legally be, in seconds (anti-exploit floor)
	LeaderboardSize = 10,  -- how many entries to show per Obby
	SafetyFactor = 0.6,    -- MinTime = RecordTime * this, when RecordTime is set
}

--// REWARD DEFAULTS (was RewardConfig.Default)
--// Used by getReward() for any ObbyId whose Overrides entry has no reward
--// tier fields (Fast/Normal/Slow) of its own - same fallback philosophy as
--// MinTime/LeaderboardSize above.
Config.RewardDefaults = {
	FastTime = 60,
	SlowTime = 120,
	Fast   = { Min = 150, Max = 400 },
	Normal = { Min = 75,  Max = 250 },
	Slow   = { Min = 25,  Max = 100 },
}

--// ANTI-EXPLOIT FLOOR
--// Any finish faster than getMinTime(obbyId) is rejected by TimeService before
--// it can touch coins, best times, or the global leaderboard. This matters more
--// than it looks: leaderboard entries live in an OrderedDataStore, so a single
--// fly/teleport exploiter setting a 0.3s "record" pollutes the world boards
--// permanently and is painful to clean up. The floor was previously 0.1s for
--// every Obby, which meant effectively no protection at all.
--//
--// Two ways to configure an Obby, per ObbyId (see getObbyId - NOT folder name):
--//   RecordTime = 40   the fastest a human has actually finished this Obby.
--//                     MinTime is derived as RecordTime * SafetyFactor, which
--//                     leaves headroom so a genuinely great run is never
--//                     rejected. This is the one to use.
--//   MinTime = 24      set the floor directly, skipping the calculation.
--// MinTime wins if both are present.
--//
--// ############################################################################
--// # CALIBRATE THESE BEFORE LAUNCH. The RecordTimes below are placeholders,   #
--// # not measurements - Obbys 1 and 3 are inferred from RewardConfig's        #
--// # FastTime, the rest are conservative guesses. Speedrun each Obby yourself #
--// # (or watch a fast playtester), then put YOUR best time in as RecordTime.  #
--// # They are deliberately lenient: too lenient only lets exploiters through, #
--// # while too strict silently rejects a real player's world record and they  #
--// # never find out why. Tune downward from real data, never upward from a    #
--// # guess - TimeService already warns with the exact time of every rejected  #
--// # finish, so watch the server log during playtests.                        #
--// ############################################################################
Config.Overrides = {
	["1"] = {
		RecordTime = 40,  -- placeholder: was RewardConfig FastTime = 60
		FastTime = .1, SlowTime = 120,
		Fast   = { Min = 200, Max = 700 },
		Normal = { Min = 100, Max = 400 },
		Slow   = { Min = 50,  Max = 200 },
	},
	["2"] = {
		RecordTime = 40,  -- placeholder: uncalibrated
		FastTime = .1, SlowTime = 120,
		Fast   = { Min = 200, Max = 700 },
		Normal = { Min = 100, Max = 400 },
		Slow   = { Min = 50,  Max = 200 },
	},
	["3"] = {
		RecordTime = 40, -- placeholder: was RewardConfig FastTime = 180
		FastTime = .1, SlowTime = 120,
		Fast   = { Min = 500, Max = 1500 },
		Normal = { Min = 300, Max = 900 },
		Slow   = { Min = 100, Max = 500 },
	},
	["4"] = {
		RecordTime = 40,  -- placeholder: uncalibrated
		FastTime = .1, SlowTime = 120,
		Fast   = { Min = 500, Max = 1500 },
		Normal = { Min = 300, Max = 900 },
		Slow   = { Min = 100, Max = 500 },
	},
	["5"] = { RecordTime = 40 },  -- placeholder: uncalibrated; no reward tier -> Config.RewardDefaults
	["6"] = { RecordTime = 40 },  -- placeholder: uncalibrated; no reward tier -> Config.RewardDefaults
}

-- the canonical ObbyId for a stage folder: the first run of digits in its
-- Name (so "1", "Stage 1", "Obby7", "Level 07" resolve to "1"/"1"/"7"/"07").
-- Falls back to the full folder name if it has no digits at all, so
-- non-numbered folders still work without hardcoding any specific name.
function Config.getObbyId(folderName)
	return folderName:match("%d+") or folderName
end

-- the anti-exploit floor for an Obby, in seconds. An explicit MinTime wins,
-- otherwise it's derived from RecordTime, otherwise the default. Callers are
-- unchanged - TimeService still just asks for a number.
function Config.getMinTime(obbyId)
	local override = Config.Overrides[obbyId]
	if override then
		if override.MinTime then
			return override.MinTime
		end
		if override.RecordTime then
			return override.RecordTime * (override.SafetyFactor or Config.Defaults.SafetyFactor)
		end
	end
	return Config.Defaults.MinTime
end

function Config.getLeaderboardSize(obbyId)
	local override = Config.Overrides[obbyId]
	return (override and override.LeaderboardSize) or Config.Defaults.LeaderboardSize
end

-- rolls the coin reward for finishing `obbyId` in `completionTime` seconds -
-- completionTime must be a server-computed elapsed time (see TimeService),
-- never a client-supplied value. Was RewardConfig.GetReward.
function Config.getReward(obbyId, completionTime)
	local override = Config.Overrides[obbyId]
	local cfg = (override and override.Fast) and override or Config.RewardDefaults

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

-- player-facing label for an ObbyId: an explicit override wins, otherwise
-- the live folder name of whichever workspace.Stages child currently owns
-- that ObbyId (so renaming the folder in Studio updates the UI with no
-- code change), falling back to the bare ObbyId if no stage matches
function Config.getDisplayName(obbyId)
	local override = Config.Overrides[obbyId]
	if override and override.DisplayName then
		return override.DisplayName
	end

	local stages = workspace:FindFirstChild("Stages")
	if stages then
		for _, stage in ipairs(stages:GetChildren()) do
			if Config.getObbyId(stage.Name) == obbyId then
				return stage.Name
			end
		end
	end

	return obbyId
end

return Config
