--// Global World Leaderboard Service
--// Place in: ServerScriptService
--// Wires up a single, hand-placed physical Global Coin Leaderboard board - a
--// clone of ReplicatedStorage.Shared.Templates.GlobalLeaderboardBoard that
--// YOU place in workspace (not inside Stages - this is a game-wide board,
--// not a per-Obby one), renamed "GlobalLeaderboard". This script does no
--// placement or positioning of any kind - same convention
--// WorldLeaderboardService uses for the per-Obby boards - it only finds
--// that existing Model, clones the GlobalLeaderboardRow template into its
--// SurfaceGui, updates TextLabels, and spins the coin decoration. If
--// workspace.GlobalLeaderboard doesn't exist, it warns once and stops.
--//
--// All ranking data comes from GlobalLeaderboardService.lua (the same
--// OrderedDataStore-backed module - no DataStore calls happen here) and
--// this script has no RemoteEvent, so there is nothing for a client to feed
--// a fake coin total into. Every TextLabel below is a server-owned
--// Instance; its properties simply replicate to everyone looking at the
--// board, same trust model WorldLeaderboardService already relies on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GlobalLeaderboardConfig"))
local Leaderboard = require(ServerScriptService:WaitForChild("GlobalLeaderboardService"))

local rowTemplate = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Templates"):WaitForChild("GlobalLeaderboardRow")

local REFRESH_INTERVAL = 30            -- seconds; fallback poll on top of instant OnUpdated refreshes, mirrors WorldLeaderboardService
local COIN_SPIN_SPEED = math.rad(90)   -- radians/sec

local GOLD = Color3.fromRGB(255, 208, 40)
local SILVER = Color3.fromRGB(191, 194, 199)
local BRONZE = Color3.fromRGB(205, 127, 50)
local DEFAULT_BG = Color3.fromRGB(16, 20, 32)
local DEFAULT_TEXT = Color3.new(1, 1, 1)
local DEFAULT_STROKE = Color3.fromRGB(55, 62, 84)
local COINS_TEXT_COLOR = Color3.fromRGB(255, 208, 40)

local MEDAL = { [1] = utf8.char(0x1F947), [2] = utf8.char(0x1F948), [3] = utf8.char(0x1F949) }

local NORMAL_ROW_SIZE = UDim2.new(1, 0, 0.084, 0)
local BIG_ROW_SIZE = UDim2.new(1, 0, 0.115, 0)

local FADE_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local REVEAL_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GLOW_TWEEN = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function rankColor(rank)
	if rank == 1 then return GOLD end
	if rank == 2 then return SILVER end
	if rank == 3 then return BRONZE end
	return nil
end

-- 1234567 -> "1,234,567"
local function formatCoins(amount)
	local formatted = tostring(math.floor(amount))
	local withCommas, count = formatted, 0
	repeat
		withCommas, count = withCommas:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return withCommas
end

--=============== SETUP ===============--
-- no placement logic here by design: the "GlobalLeaderboard" Model (a clone
-- of Templates.GlobalLeaderboardBoard) must already exist in workspace,
-- wherever it was hand-placed in Studio. This script never moves or creates it.
local model = workspace:FindFirstChild("GlobalLeaderboard")
if not model then
	warn("[GlobalWorldLeaderboardService] workspace.GlobalLeaderboard not found - "
		.. "place a clone of Templates.GlobalLeaderboardBoard in workspace, named \"GlobalLeaderboard\"")
	return
end

local boardPart = model:FindFirstChild("BoardPart")
local surfaceGui = boardPart and boardPart:FindFirstChild("WorldLeaderboardGui")
local board = surfaceGui and surfaceGui:FindFirstChild("Board")
local list = board and board:FindFirstChild("List")

if not list then
	warn("[GlobalWorldLeaderboardService] workspace.GlobalLeaderboard is missing BoardPart.WorldLeaderboardGui.Board.List - "
		.. "make sure it's an unmodified clone of Templates.GlobalLeaderboardBoard")
	return
end

local emptyLbl = list:WaitForChild("EmptyLbl")

--=============== ROW POOL (persistent - enables the fade-update animation) ===============--
local rows = {} -- 1..Config.TopCount -> { frame, rank, name, coins, stroke, scale, key }

local function buildRow(i)
	local row = rowTemplate:Clone()
	row.Name = "Row" .. i
	row.LayoutOrder = i
	row.Visible = false
	row.Parent = list

	local entry = {
		frame = row,
		rank = row:WaitForChild("RankLbl"),
		name = row:WaitForChild("NameLbl"),
		coins = row:WaitForChild("CoinsLbl"),
		stroke = row:FindFirstChildOfClass("UIStroke"),
		scale = row:FindFirstChildOfClass("UIScale"),
		key = nil,
	}
	rows[i] = entry

	if i == 1 then
		-- persistent pulsing glow for the #1 slot; harmless while the row is
		-- hidden. Owns BackgroundTransparency/Thickness exclusively from here
		-- on - applyStyle() below skips those two properties for rank 1 so it
		-- never fights this tween.
		if entry.stroke then
			TweenService:Create(entry.stroke, GLOW_TWEEN, { Thickness = 4 }):Play()
		end
		TweenService:Create(row, GLOW_TWEEN, { BackgroundTransparency = 0.55 }):Play()
	end

	return entry
end

for i = 1, Config.TopCount do
	buildRow(i)
end

--=============== RENDER ===============--
local function applyStyle(row, rank)
	local color = rankColor(rank)
	row.frame.Size = (rank <= 3) and BIG_ROW_SIZE or NORMAL_ROW_SIZE
	row.frame.BackgroundColor3 = color or DEFAULT_BG

	if rank ~= 1 then
		row.frame.BackgroundTransparency = color and 0.7 or 0.15
	end

	row.rank.TextColor3 = color or DEFAULT_TEXT
	row.name.TextColor3 = color or DEFAULT_TEXT
	row.coins.TextColor3 = color or COINS_TEXT_COLOR

	if row.stroke then
		row.stroke.Color = color or DEFAULT_STROKE
		if rank ~= 1 then
			row.stroke.Thickness = color and 2 or 1
		end
	end
end

local function setText(row, entry)
	row.rank.Text = MEDAL[entry.rank] or ("#" .. entry.rank)
	row.name.Text = entry.name
	row.coins.Text = formatCoins(entry.coins) .. " Coins"
end

-- smooth text update: fades the three labels out, swaps the text, fades back
-- in - replaces a hard destroy-and-reclone-every-refresh approach, which has
-- no way to animate a change
local function updateRow(row, entry)
	local newKey = entry.name .. ":" .. entry.coins
	applyStyle(row, entry.rank)

	if not row.frame.Visible then
		setText(row, entry)
		row.frame.Visible = true
		row.key = newKey
		if row.scale then
			row.scale.Scale = 0.85
			TweenService:Create(row.scale, REVEAL_TWEEN, { Scale = 1 }):Play()
		end
		return
	end

	if row.key == newKey then return end -- unchanged, nothing to animate
	row.key = newKey

	TweenService:Create(row.name, FADE_TWEEN, { TextTransparency = 1 }):Play()
	TweenService:Create(row.coins, FADE_TWEEN, { TextTransparency = 1 }):Play()
	local fadeOut = TweenService:Create(row.rank, FADE_TWEEN, { TextTransparency = 1 })
	fadeOut:Play()

	fadeOut.Completed:Connect(function()
		setText(row, entry)
		TweenService:Create(row.rank, REVEAL_TWEEN, { TextTransparency = 0 }):Play()
		TweenService:Create(row.name, REVEAL_TWEEN, { TextTransparency = 0 }):Play()
		TweenService:Create(row.coins, REVEAL_TWEEN, { TextTransparency = 0 }):Play()
	end)
end

local function render()
	local entries = Leaderboard.GetTop(Config.TopCount)
	emptyLbl.Visible = #entries == 0

	for i, row in ipairs(rows) do
		local entry = entries[i]
		if entry then
			updateRow(row, entry)
		elseif row.frame.Visible then
			row.frame.Visible = false
			row.key = nil
		end
	end
end

--=============== COIN DECORATION ===============--
-- purely cosmetic spin; particles (GlowAttachment.Sparkles) and the accent
-- SpotLight are just always-on template properties and need no script
local coin = model:FindFirstChild("CoinDecoration")
if coin then
	RunService.Heartbeat:Connect(function(dt)
		if coin.Parent then
			coin.CFrame = coin.CFrame * CFrame.Angles(0, COIN_SPIN_SPEED * dt, 0)
		end
	end)
end

--=============== REFRESH ===============--
render()

Leaderboard.OnUpdated:Connect(render) -- instant refresh whenever a batch actually writes

task.spawn(function()
	while true do
		task.wait(REFRESH_INTERVAL)
		render() -- fallback poll (catches rank/name drift the instant path wouldn't see)
	end
end)
