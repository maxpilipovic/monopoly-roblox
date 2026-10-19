--!strict
-- The lobby's three boards, all from ranked play: most ranked wins, highest Elo, best win streak. Scores go to OrderedDataStores
-- whenever a profile changes; the top ten of each are read every minute and published as JSON on
-- ReplicatedStorage (attribute "Leaderboards") for clients to draw. Without DataStores, the boards
-- rank the players in this server.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)

local Leaderboards = {}

Leaderboards.ATTRIBUTE = "Leaderboards"
Leaderboards.REFRESH_SECONDS = 60
local TOP = 10
local BOARDS = {
	{ id = "wins", store = "RankedWins_v1", stat = "rankedWins" },
	{ id = "elo", store = "Elo_v1", stat = "elo" },
	{ id = "streak", store = "BestStreak_v1", stat = "bestStreak" },
}

local stores: { [string]: OrderedDataStore } = {}
local available = true -- false only where OrderedDataStores can't be used at all (Studio without API access)
local lastGlobal: { [string]: any }? = nil -- the last boards read from the store, kept through a failed refresh
local names: { [number]: string } = {}

local function storeFor(name: string): OrderedDataStore?
	if not available then
		return nil
	end
	if not stores[name] then
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		if not ok then
			available = false
			return nil
		end
		stores[name] = result
	end
	return stores[name]
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then result else `Player {userId}`
	return names[userId]
end

local function publish(boards: { [string]: { { name: string, value: number } } })
	ReplicatedStorage:SetAttribute(Leaderboards.ATTRIBUTE, HttpService:JSONEncode(boards))
end

-- Ranks the players in this server (used when DataStores aren't there).
local function localBoards(): { [string]: { { name: string, value: number } } }
	local boards = {}
	for _, board in BOARDS do
		local rows = {}
		for _, player in Players:GetPlayers() do
			local profile = PlayerData.peek(player)
			if profile then
				table.insert(rows, { name = player.DisplayName, value = (profile.stats :: any)[board.stat] })
			end
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
		boards[board.id] = { table.unpack(rows, 1, math.min(#rows, TOP)) }
	end
	return boards
end

local function refresh()
	if not available then
		publish(localBoards())
		return
	end
	local boards = {}
	for _, board in BOARDS do
		local store = storeFor(board.store)
		local ok, pages = false, nil
		if store then
			ok, pages = pcall(store.GetSortedAsync, store, false, TOP)
		end
		if not ok or not pages then
			if tostring(pages):find("Studio access", 1, true) then
				available = false
			end
			-- A throttled or failed read: keep showing the last good boards and try next time.
			publish(lastGlobal or localBoards())
			return
		end
		local rows = {}
		for _, entry in (pages :: DataStorePages):GetCurrentPage() do
			local userId = tonumber((entry.key :: string):match("%d+"))
			if userId then
				table.insert(rows, { name = nameOf(userId), value = entry.value })
			end
		end
		boards[board.id] = rows
	end
	lastGlobal = boards
	publish(boards)
end

local function record(player: Player, profile: any)
	if not available then
		return
	end
	for _, board in BOARDS do
		local store = storeFor(board.store)
		if store then
			local value = math.floor(profile.stats[board.stat])
			local ok, err = pcall(store.SetAsync, store, `player_{player.UserId}`, value)
			if not ok then
				if tostring(err):find("Studio access", 1, true) then
					available = false
				end
				return -- a failed write is retried when their scores next change
			end
		end
	end
end

function Leaderboards.start()
	publish({ wins = {}, elo = {}, streak = {} })
	-- Only scores that can change (after a game) are worth writing; joining writes once too.
	local lastWritten: { [Player]: string } = {}
	PlayerData.onChanged(function(player, profile)
		-- A stand-in profile (their data couldn't be read) must not overwrite their real scores.
		if PlayerData.isUnreadable(player) then
			return
		end
		local signature = `{profile.stats.rankedWins}:{profile.stats.elo}:{profile.stats.bestStreak}`
		if lastWritten[player] ~= signature then
			lastWritten[player] = signature
			record(player, profile)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastWritten[player] = nil
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(Leaderboards.REFRESH_SECONDS)
		end
	end)
end

return Leaderboards
