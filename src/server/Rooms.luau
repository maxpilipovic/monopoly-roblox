--!strict
-- The games open on this server, casual and ranked: who hosts each, who's in it, its settings and
-- whether it's playing. A ranked room is hosted and joined like a casual one (any settings) but rated,
-- and needs at least two people to start. Pure bookkeeping; RoomService runs the games.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)

export type Member = { id: string, name: string }

export type Room = {
	id: number,
	name: string,
	hostId: string,
	members: { Member },
	settings: RoomSettings.Settings,
	status: string, -- "Waiting" | "Playing"
	ranked: boolean, -- rated: results move everyone's Elo
	matched: boolean, -- made by the ranked queue for the players it matched: never listed or joinable
	session: any?, -- the GameSession while playing (owned by RoomService)
}

export type RoomView = {
	id: number,
	name: string,
	hostName: string,
	players: number,
	maxPlayers: number,
	status: string,
	settings: RoomSettings.Settings,
	members: { Member },
	ranked: boolean,
}

export type Registry = { rooms: { Room }, nextId: number }

local Rooms = {}

function Rooms.new(): Registry
	return { rooms = {}, nextId = 1 }
end

function Rooms.byId(reg: Registry, id: any): Room?
	for _, room in reg.rooms do
		if room.id == id then
			return room
		end
	end
	return nil
end

function Rooms.roomOf(reg: Registry, playerId: string): Room?
	for _, room in reg.rooms do
		for _, member in room.members do
			if member.id == playerId then
				return room
			end
		end
	end
	return nil
end

local function hostName(room: Room): string
	for _, member in room.members do
		if member.id == room.hostId then
			return member.name
		end
	end
	return "?"
end

local function rename(room: Room)
	room.name = if room.ranked then `{hostName(room)}'s ranked game` else `{hostName(room)}'s game`
end

-- A room hosted by `hostId`; `ranked` rooms are rated.
function Rooms.create(reg: Registry, hostId: string, name: string, raw: any, ranked: boolean?): (Room?, string?)
	if Rooms.roomOf(reg, hostId) then
		return nil, "you're already in a game"
	end
	local room: Room = {
		id = reg.nextId,
		name = "",
		hostId = hostId,
		members = { { id = hostId, name = name } },
		settings = if ranked == true then RoomSettings.forRanked(RoomSettings.validate(raw)) else RoomSettings.validate(raw),
		status = "Waiting",
		ranked = ranked == true,
		matched = false,
		session = nil,
	}
	reg.nextId += 1
	rename(room)
	table.insert(reg.rooms, room)
	return room, nil
end

-- A room for players the ranked queue matched, with the fixed ranked rules.
function Rooms.createRanked(reg: Registry, members: { Member }, raw: any): Room
	local room: Room = {
		id = reg.nextId,
		name = "Ranked game",
		hostId = members[1].id,
		members = table.clone(members),
		settings = RoomSettings.validate(raw),
		status = "Waiting",
		ranked = true,
		matched = true,
		session = nil,
	}
	reg.nextId += 1
	table.insert(reg.rooms, room)
	return room
end

function Rooms.join(reg: Registry, roomId: any, playerId: string, name: string): (boolean, string?)
	local room = Rooms.byId(reg, roomId)
	if not room then
		return false, "that game has closed"
	elseif Rooms.roomOf(reg, playerId) then
		return false, "you're already in a game"
	elseif room.status ~= "Waiting" then
		return false, "that game has already started"
	elseif room.matched then
		return false, "that game was made for the players it matched"
	elseif #room.members >= room.settings.maxPlayers then
		return false, "that game is full"
	end
	table.insert(room.members, { id = playerId, name = name })
	return true, nil
end

-- Takes a player out of their room. The next member becomes host; an empty room closes.
-- Returns the room they left, if any.
function Rooms.leave(reg: Registry, playerId: string): Room?
	local room = Rooms.roomOf(reg, playerId)
	if not room then
		return nil
	end
	for index, member in room.members do
		if member.id == playerId then
			table.remove(room.members, index)
			break
		end
	end
	if #room.members == 0 then
		table.remove(reg.rooms, table.find(reg.rooms, room) :: number)
	elseif room.hostId == playerId then
		room.hostId = room.members[1].id
		if not room.matched then
			rename(room)
		end
	end
	return room
end

function Rooms.updateSettings(reg: Registry, playerId: string, raw: any): (boolean, string?)
	local room = Rooms.roomOf(reg, playerId)
	if not room or room.hostId ~= playerId then
		return false, "only the host can change the settings"
	elseif room.matched then
		return false, "matched games use fixed rules"
	elseif room.status ~= "Waiting" then
		return false, "the game has already started"
	end
	local settings = RoomSettings.validate(raw)
	if room.ranked then
		settings = RoomSettings.forRanked(settings) -- real players only, played to the end
	end
	-- Never fewer seats than people already in the room.
	settings.maxPlayers = math.max(settings.maxPlayers, #room.members)
	room.settings = settings
	return true, nil
end

function Rooms.canStart(reg: Registry, playerId: string): (boolean, string?)
	local room = Rooms.roomOf(reg, playerId)
	if not room or room.hostId ~= playerId then
		return false, "only the host can start the game"
	elseif room.status ~= "Waiting" then
		return false, "the game has already started"
	elseif (room.ranked or not room.settings.bots) and #room.members < 2 then
		-- A ranked game needs a real opponent: no farming rating off bots alone.
		return false, if room.ranked then "a ranked game needs at least two players" else "waiting for another player"
	end
	return true, nil
end

function Rooms.list(reg: Registry): { RoomView }
	local views = {}
	for _, room in reg.rooms do
		if room.matched then
			continue
		end
		table.insert(views, {
			id = room.id,
			name = room.name,
			hostName = hostName(room),
			players = #room.members,
			maxPlayers = room.settings.maxPlayers,
			status = room.status,
			settings = room.settings,
			members = table.clone(room.members),
			ranked = room.ranked,
		})
	end
	return views
end

return Rooms
