--!strict
-- What the host of a casual game picks: how many seats, the starting money, the house rules
-- (auctions, the Free Parking pot), bots, and the speed and map options. Shared so the lobby shows
-- exactly what the server accepts; the server validates every request through here.

local MatchSettings = require(script.Parent.MatchSettings)

export type Settings = {
	maxPlayers: number, -- 2-6 seats
	startingMoney: number,
	auctions: boolean, -- off: a declined property stays with the bank
	freeParking: boolean, -- on: fines and fees pile up on Free Parking for whoever lands there
	bots: boolean, -- fill seats nobody took
	timer: string,
	length: string,
	map: string,
}

local RoomSettings = {}

RoomSettings.MIN_PLAYERS = 2
RoomSettings.MAX_PLAYERS = 6
RoomSettings.MONEY_MIN = 500
RoomSettings.MONEY_MAX = 5000
RoomSettings.MONEY_STEP = 250

RoomSettings.DEFAULT = table.freeze({
	maxPlayers = 4,
	startingMoney = 1500,
	auctions = true,
	freeParking = false,
	bots = true,
	timer = MatchSettings.DEFAULT.timer,
	length = MatchSettings.DEFAULT.length,
	map = MatchSettings.DEFAULT.map,
}) :: Settings

local function number(raw: any, key: string, fallback: number): number
	local value = if typeof(raw) == "table" then raw[key] else nil
	return if typeof(value) == "number" and value == value then value else fallback
end

local function switch(raw: any, key: string, fallback: boolean): boolean
	local value = if typeof(raw) == "table" then raw[key] else nil
	return if typeof(value) == "boolean" then value else fallback
end

function RoomSettings.validate(raw: any): Settings
	local defaults = RoomSettings.DEFAULT
	local players = math.clamp(math.round(number(raw, "maxPlayers", defaults.maxPlayers)), RoomSettings.MIN_PLAYERS, RoomSettings.MAX_PLAYERS)
	local step = RoomSettings.MONEY_STEP
	local money = math.round(number(raw, "startingMoney", defaults.startingMoney) / step) * step
	local match = MatchSettings.validate(raw)
	return {
		maxPlayers = players,
		startingMoney = math.clamp(money, RoomSettings.MONEY_MIN, RoomSettings.MONEY_MAX),
		auctions = switch(raw, "auctions", defaults.auctions),
		freeParking = switch(raw, "freeParking", defaults.freeParking),
		bots = switch(raw, "bots", defaults.bots),
		timer = match.timer,
		length = match.length,
		map = match.map,
	}
end

-- The fixed rules every ranked game is played under, like a chess time control: standard money and
-- auctions, no house rules, no bots, a turn timer and a time limit.
function RoomSettings.ranked(seats: number): Settings
	return RoomSettings.validate({
		maxPlayers = seats,
		startingMoney = 1500,
		auctions = true,
		freeParking = false,
		bots = false,
		timer = "Relaxed",
		length = if seats <= 2 then "Minutes30" else "Minutes60",
		map = "Classic",
	})
end

-- The engine's house rules.
function RoomSettings.rules(settings: Settings): { startingMoney: number, auctions: boolean, freeParking: boolean }
	return { startingMoney = settings.startingMoney, auctions = settings.auctions, freeParking = settings.freeParking }
end

-- The speed and map options the game session already understands.
function RoomSettings.match(settings: Settings): MatchSettings.Settings
	return { timer = settings.timer, length = settings.length, map = settings.map }
end

-- Short labels for a room's card in the games list: what's different about it.
function RoomSettings.chips(settings: Settings): { string }
	local chips = { `${settings.startingMoney}` }
	if not settings.auctions then
		table.insert(chips, "No auctions")
	end
	if settings.freeParking then
		table.insert(chips, "Free Parking pot")
	end
	if settings.timer ~= "Off" then
		table.insert(chips, `{settings.timer} timer`)
	end
	if settings.length ~= "Off" then
		table.insert(chips, (MatchSettings.lengthLabel(settings.length):gsub("^Length: ", "")))
	end
	if settings.map ~= MatchSettings.DEFAULT.map then
		table.insert(chips, settings.map)
	end
	return chips
end

return RoomSettings
