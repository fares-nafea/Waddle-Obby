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
	MinTime = 0.1,         -- fastest a finish can legally be, in seconds (anti-exploit floor)
	LeaderboardSize = 10, -- how many entries to show per Obby
}

-- Config.Overrides["1"] = { MinTime = 5 } -- keyed by ObbyId (see getObbyId), not folder name
Config.Overrides = {}

-- the canonical ObbyId for a stage folder: the first run of digits in its
-- Name (so "1", "Stage 1", "Obby7", "Level 07" resolve to "1"/"1"/"7"/"07").
-- Falls back to the full folder name if it has no digits at all, so
-- non-numbered folders still work without hardcoding any specific name.
function Config.getObbyId(folderName)
	return folderName:match("%d+") or folderName
end

function Config.getMinTime(obbyId)
	local override = Config.Overrides[obbyId]
	return (override and override.MinTime) or Config.Defaults.MinTime
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
