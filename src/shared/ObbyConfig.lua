--// Obby Config (shared)
--// Optional per-Obby overrides. Obbys are auto-discovered from workspace.Stages
--// (one child folder = one Obby, folder Name = ObbyId) so adding a new Obby
--// needs zero code changes. Only add an entry here if an Obby needs a
--// non-default minimum time, leaderboard size, or display name.

local Config = {}

Config.Defaults = {
	MinTime = 3,         -- fastest a finish can legally be, in seconds (anti-exploit floor)
	LeaderboardSize = 10, -- how many entries to show per Obby
}

-- Config.Overrides["Obby1"] = { MinTime = 5 }
Config.Overrides = {}

function Config.getMinTime(obbyId)
	local override = Config.Overrides[obbyId]
	return (override and override.MinTime) or Config.Defaults.MinTime
end

function Config.getLeaderboardSize(obbyId)
	local override = Config.Overrides[obbyId]
	return (override and override.LeaderboardSize) or Config.Defaults.LeaderboardSize
end

function Config.getDisplayName(obbyId)
	local override = Config.Overrides[obbyId]
	return (override and override.DisplayName) or obbyId
end

return Config
