--!strict
-- What the host of a game picks: how many seats, the starting money, the house rules
-- (auctions, the Free Parking pot, Crazy Chance), bots, and the speed and map options. Shared so the lobby shows
-- exactly what the server accepts; the server validates every request through here.

local MatchSettings = require(script.Parent.MatchSettings)
local Scenes = require(script.Parent.Parent.Board.Scenes)

export type Settings = {
	maxPlayers: number, -- 2-6 seats
	startingMoney: number,
	auctions: boolean, -- off: a declined property stays with the bank
	freeParking: boolean, -- on: fines and fees pile up on Free Parking for whoever lands there
	crazyChance: boolean, -- on: a third of Chance draws are wild Crazy Chance cards
	bots: boolean, -- fill seats nobody took
	timer: string,
	length: string,
	map: string,
	scene: string, -- Scenes id: what surrounds the board
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
	freeParking = true,
	crazyChance = false,
	bots = true,
	timer = MatchSettings.DEFAULT.timer,
	length = MatchSettings.DEFAULT.length,
	map = MatchSettings.DEFAULT.map,
	scene = "Boardwalk",
}) :: Settings

local function number(raw: any, key: string, fallback: number): number
	local value = if typeof(raw) == "table" then raw[key] else nil
	return if typeof(value) == "number" and value == value then value else fallback
end

local function switch(raw: any, key: string, fallback: boolean): boolean
	local value = if typeof(raw) == "table" then raw[key] else nil
	return if typeof(value) == "boolean" then value else fallback
end

-- The scene a map is played in: the asked-for one if the map may use it, else the map's first
-- (its own scene, or the default).
local function sceneFor(map: string, asked: any): string
	local allowed = Scenes.forMap(map)
	if typeof(asked) == "string" and table.find(allowed, asked) then
		return asked
	end
	return if table.find(allowed, RoomSettings.DEFAULT.scene) then RoomSettings.DEFAULT.scene else allowed[1]
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
		crazyChance = switch(raw, "crazyChance", defaults.crazyChance),
		bots = switch(raw, "bots", defaults.bots),
		timer = match.timer,
		length = match.length,
		map = match.map,
		scene = sceneFor(match.map, if typeof(raw) == "table" then raw.scene else nil),
	}
end

-- The fixed rules every ranked game is played under, like a chess time control: standard money and
-- auctions, no house rules, no bots, a turn timer and no game length.
function RoomSettings.ranked(seats: number): Settings
	return RoomSettings.validate({
		maxPlayers = seats,
		startingMoney = 1500,
		auctions = true,
		freeParking = false,
		bots = false,
		timer = "Relaxed",
		length = "Off",
		map = "Classic",
	})
end

-- A hosted ranked game's settings: the host's choices, except that ranked is real players only
-- (no bots) and plays to the end (no game length).
function RoomSettings.forRanked(settings: Settings): Settings
	local ranked = table.clone(settings)
	ranked.bots = false
	ranked.length = "Off"
	return ranked
end

-- The engine's house rules.
function RoomSettings.rules(settings: Settings): { startingMoney: number, auctions: boolean, freeParking: boolean, crazyChance: boolean }
	return { startingMoney = settings.startingMoney, auctions = settings.auctions, freeParking = settings.freeParking, crazyChance = settings.crazyChance }
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
	if settings.crazyChance then
		table.insert(chips, "Crazy Chance")
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
	if settings.scene ~= RoomSettings.DEFAULT.scene and Scenes.byId[settings.scene] then
		table.insert(chips, Scenes.byId[settings.scene].name)
	end
	return chips
end

return RoomSettings
