--!strict
-- A player's saved data and the rules for changing it: lifetime stats (wins, streaks, Elo), owned
-- items with counts, what's equipped, and recent purchase ids so no purchase is granted twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)

export type Stats = { wins: number, games: number, streak: number, bestStreak: number, elo: number }

export type Profile = {
	version: number,
	stats: Stats,
	inventory: { [string]: number }, -- item id -> how many owned
	equipped: { piece: string, rentEffect: string? },
	receipts: { string }, -- the most recent purchase ids, oldest first
}

local Profile = {}

Profile.VERSION = 1
Profile.START_ELO = 1000
Profile.ELO_FLOOR = 100
Profile.RECEIPTS_KEPT = 50

function Profile.new(): Profile
	return {
		version = Profile.VERSION,
		stats = { wins = 0, games = 0, streak = 0, bestStreak = 0, elo = Profile.START_ELO },
		inventory = {},
		equipped = { piece = Catalog.DEFAULT_PIECE, rentEffect = nil },
		receipts = {},
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
			if typeof(id) == "string" and Catalog.byId[id] and typeof(count) == "number" and count > 0 then
				profile.inventory[id] = count
			end
		end
	end
	if typeof(raw.equipped) == "table" then
		if typeof(raw.equipped.piece) == "string" and Profile.owns(profile, raw.equipped.piece) then
			profile.equipped.piece = raw.equipped.piece
		end
		if typeof(raw.equipped.rentEffect) == "string" and Profile.owns(profile, raw.equipped.rentEffect) then
			profile.equipped.rentEffect = raw.equipped.rentEffect
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

function Profile.recordGame(profile: Profile, won: boolean, eloDelta: number)
	local stats = profile.stats
	stats.games += 1
	if won then
		stats.wins += 1
		stats.streak += 1
		stats.bestStreak = math.max(stats.bestStreak, stats.streak)
	else
		stats.streak = 0
	end
	stats.elo = math.max(Profile.ELO_FLOOR, stats.elo + eloDelta)
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
	if item.kind == "Piece" then
		profile.equipped.piece = id
	else
		profile.equipped.rentEffect = id
	end
	return true, nil
end

function Profile.unequipRentEffect(profile: Profile)
	profile.equipped.rentEffect = nil
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
