--// Obby Config (shared)
--// Optional per-Obby overrides. Obbys are auto-discovered from workspace.Stages
--// (one child folder = one Obby) so adding a new Obby needs zero code changes.
--// Only add an entry here if an Obby needs a non-default minimum time,
--// leaderboard size, or display name.
--//
--// ObbyId vs folder name: the folder Name (e.g. "Stage 1") is just a label -
--// it can be renamed freely for readability. The canonical ObbyId used
--// everywhere internally (DataStore keys, BestTimes entries, RemoteEvent
--// payloads) is the number extracted from that name via getObbyId, so
--// renaming "1" -> "Stage 1" keeps every player's existing best times and
--// leaderboard entries intact (both extract to ObbyId "1").

local Config = {}

Config.Defaults = {
	MinTime = 15,          -- fastest a finish can legally be, in seconds (anti-exploit floor)
	LeaderboardSize = 10,  -- how many entries to show per Obby
	SafetyFactor = 0.6,    -- MinTime = RecordTime * this, when RecordTime is set
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
	["1"] = { RecordTime = 40 },  -- placeholder: RewardConfig FastTime = 60
	["2"] = { RecordTime = 40 },  -- placeholder: uncalibrated
	["3"] = { RecordTime = 120 }, -- placeholder: RewardConfig FastTime = 180
	["4"] = { RecordTime = 40 },  -- placeholder: uncalibrated
	["5"] = { RecordTime = 40 },  -- placeholder: uncalibrated
	["6"] = { RecordTime = 40 },  -- placeholder: uncalibrated
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
