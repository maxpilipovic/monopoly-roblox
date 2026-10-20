--!strict
-- A player's saved data and the rules for changing it: lifetime stats (every game's wins; ranked
-- rating, peak, wins and win streaks), owned items with counts, what's equipped, recent purchase
-- ids so no purchase is granted twice, and progression (coins, counters, chest keys, the day's
-- challenges, achievement tiers and the Empire Tree; its rules live in Shared.Progress.Progress).
-- Only ranked games move the rating and the streak.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)

export type Stats = {
	wins: number, -- every game
	games: number,
	elo: number, -- ranked rating
	peakElo: number,
	rankedGames: number,
	rankedWins: number,
	streak: number, -- ranked wins in a row
	bestStreak: number,
}

export type Equipped = { piece: string, rentEffect: string?, aura: string?, dice: string?, title: string? }

export type Profile = {
	version: number,
	stats: Stats,
	inventory: { [string]: number }, -- item id -> how many owned
	equipped: Equipped,
	receipts: { string }, -- the most recent purchase ids, oldest first
	retired: { [string]: number }, -- owned items the catalogue no longer lists, kept so a save never drops them
	coins: number,
	counters: { [string]: number }, -- lifetime counts every challenge is measured on (Shared.Progress.Stats)
	keys: { [string]: number }, -- chest id -> free openings
	daily: Progress.DailyState,
	achievements: { [string]: number }, -- track id -> tiers claimed
	tree: { claimed: { [string]: boolean }, starts: { [string]: number } },
}


local Profile = {}

-- The equip slot each kind of item goes in.
Profile.SLOTS = table.freeze({ Piece = "piece", RentEffect = "rentEffect", Aura = "aura", Dice = "dice", Title = "title" })

Profile.VERSION = 2
Profile.START_ELO = 1000
Profile.ELO_FLOOR = 100
Profile.RECEIPTS_KEPT = 50

function Profile.new(): Profile
	return {
		version = Profile.VERSION,
		stats = {
			wins = 0,
			games = 0,
			elo = Profile.START_ELO,
			peakElo = Profile.START_ELO,
			rankedGames = 0,
			rankedWins = 0,
			streak = 0,
			bestStreak = 0,
		},
		inventory = {},
		equipped = { piece = Catalog.DEFAULT_PIECE, rentEffect = nil },
		receipts = {},
		retired = {},
		coins = 0,
		counters = {},
		keys = {},
		daily = Progress.newDaily(),
		achievements = {},
		tree = { claimed = {}, starts = { Root = 0 } },
	}
end

local function numberOr(value: any, fallback: number): number
	return if typeof(value) == "number" and value == value then value else fallback
end

-- Turns whatever was saved (possibly older, partial or damaged) into a whole profile.
function Profile.reconcile(raw: any): Profile
	local profile = Profile.new()
	if typeof(raw) ~= "table" then
		return profile
	end
	if typeof(raw.stats) == "table" then
		for key, value in profile.stats do
			profile.stats[key] = numberOr(raw.stats[key], value)
		end
	end
	if typeof(raw.inventory) == "table" then
		for id, count in raw.inventory do
			if typeof(id) == "string" and typeof(count) == "number" and count > 0 then
				if Catalog.byId[id] then
					profile.inventory[id] = count
				else
					profile.retired[id] = count
				end
			end
		end
	end
	if typeof(raw.retired) == "table" then
		for id, count in raw.retired do
			if typeof(id) == "string" and typeof(count) == "number" and count > 0 then
				if Catalog.byId[id] then
					profile.inventory[id] = (profile.inventory[id] or 0) + count -- an item that came back
				else
					profile.retired[id] = count
				end
			end
		end
	end
	if typeof(raw.equipped) == "table" then
		for kind, slot in Profile.SLOTS do
			local id = raw.equipped[slot]
			local item = if typeof(id) == "string" then Catalog.byId[id] else nil
			if item and item.kind == kind and Profile.owns(profile, id) then
				(profile.equipped :: any)[slot] = id
			end
		end
	end
	profile.coins = math.max(0, math.floor(numberOr(raw.coins, 0)))
	if typeof(raw.counters) == "table" then
		for stat, n in raw.counters do
			if typeof(stat) == "string" and typeof(n) == "number" and n == n then
				profile.counters[stat] = n
			end
		end
	else
		-- Saved before progression: the games already played count toward lifetime achievements.
		profile.counters.games = profile.stats.games
		profile.counters.wins = profile.stats.wins
		profile.counters.rankedWins = profile.stats.rankedWins
	end
	if typeof(raw.keys) == "table" then
		for chest, n in raw.keys do
			if typeof(chest) == "string" and typeof(n) == "number" and n > 0 then
				profile.keys[chest] = math.floor(n)
			end
		end
	end
	if typeof(raw.achievements) == "table" then
		for track, n in raw.achievements do
			if typeof(track) == "string" and typeof(n) == "number" then
				profile.achievements[track] = n
			end
		end
	end
	local daily = raw.daily
	if typeof(daily) == "table" and typeof(daily.day) == "number" and typeof(daily.ids) == "table" then
		local ids, starts, claimed = {}, {}, {}
		for index, id in daily.ids do
			if typeof(id) == "string" then
				ids[index] = id
				starts[index] = numberOr(typeof(daily.starts) == "table" and daily.starts[index], 0)
				claimed[index] = typeof(daily.claimed) == "table" and daily.claimed[index] == true
			end
		end
		profile.daily = {
			day = daily.day,
			ids = ids,
			starts = starts,
			claimed = claimed,
			swaps = numberOr(daily.swaps, 0),
			bonus = daily.bonus == true,
		}
	end
	if typeof(raw.tree) == "table" then
		if typeof(raw.tree.claimed) == "table" then
			for id, value in raw.tree.claimed do
				if typeof(id) == "string" and value == true then
					profile.tree.claimed[id] = true
				end
			end
		end
		if typeof(raw.tree.starts) == "table" then
			for id, n in raw.tree.starts do
				if typeof(id) == "string" and typeof(n) == "number" then
					profile.tree.starts[id] = n
				end
			end
		end
	end
	if typeof(raw.receipts) == "table" then
		for _, id in raw.receipts do
			if typeof(id) == "string" then
				table.insert(profile.receipts, id)
			end
		end
	end
	return profile
end

function Profile.recordGame(profile: Profile, won: boolean, eloDelta: number, ranked: boolean)
	local stats = profile.stats
	stats.games += 1
	if won then
		stats.wins += 1
	end
	if not ranked then
		return
	end
	stats.rankedGames += 1
	if won then
		stats.rankedWins += 1
		stats.streak += 1
		stats.bestStreak = math.max(stats.bestStreak, stats.streak)
	else
		stats.streak = 0
	end
	stats.elo = math.max(Profile.ELO_FLOOR, stats.elo + eloDelta)
	stats.peakElo = math.max(stats.peakElo, stats.elo)
end

function Profile.owns(profile: Profile, id: string): boolean
	local item = Catalog.byId[id]
	return item ~= nil and (item.default == true or (profile.inventory[id] or 0) > 0)
end

-- Adds one of `id`; returns how many are now owned.
function Profile.grant(profile: Profile, id: string): number
	assert(Catalog.byId[id], `no item {id}`)
	profile.inventory[id] = (profile.inventory[id] or 0) + 1
	return profile.inventory[id]
end

function Profile.equip(profile: Profile, id: string): (boolean, string?)
	local item = Catalog.byId[id]
	if not item then
		return false, "no such item"
	elseif not Profile.owns(profile, id) then
		return false, "you don't own that yet"
	end
	(profile.equipped :: any)[Profile.SLOTS[item.kind]] = id
	return true, nil
end

-- Takes off whatever is in `kind`'s slot (a piece can't be taken off; dice go back to ivory).
function Profile.unequip(profile: Profile, kind: string)
	if kind == "RentEffect" or kind == "Aura" or kind == "Title" or kind == "Dice" then
		(profile.equipped :: any)[Profile.SLOTS[kind]] = nil
	end
end

function Profile.unequipRentEffect(profile: Profile)
	Profile.unequip(profile, "RentEffect")
end

function Profile.hasReceipt(profile: Profile, purchaseId: string): boolean
	return table.find(profile.receipts, purchaseId) ~= nil
end

function Profile.addReceipt(profile: Profile, purchaseId: string)
	table.insert(profile.receipts, purchaseId)
	while #profile.receipts > Profile.RECEIPTS_KEPT do
		table.remove(profile.receipts, 1)
	end
end

return Profile
