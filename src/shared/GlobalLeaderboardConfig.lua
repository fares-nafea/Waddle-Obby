--// Global Leaderboard Config (shared)
--// Single source of truth for the Global Coin Leaderboard's DataStore name
--// and timing, so GlobalLeaderboardService (the ranking backend) and
--// GlobalWorldLeaderboardService (the 3D board that renders it) never
--// disagree on how many ranks to show or drift out of sync - same idea as
--// ObbyConfig being the one place TimeService/ObbyClient/WorldLeaderboardService
--// all read from.

local Config = {}

-- bump the trailing version if the stored value's meaning ever changes
-- (e.g. switching from "highest ever" to "current balance") - a new store
-- name means old entries are never misread under the new meaning
Config.StoreName = "GlobalCoinLeaderboard_v1"

Config.TopCount = 10     -- how many ranks GetSortedAsync is asked for / the world board shows
Config.PushInterval = 60 -- seconds between writing a changed player's coin total to the store
Config.CacheTTL = 20     -- seconds a fetched top-list stays valid before refetching

return Config
