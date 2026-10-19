--!strict
-- The casual games open on this server: who hosts each, who's in it, its settings and whether it's
-- playing. Pure bookkeeping; RoomService runs the games and talks to clients.

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
	room.name = `{hostName(room)}'s game`
end

function Rooms.create(reg: Registry, hostId: string, name: string, raw: any): (Room?, string?)
	if Rooms.roomOf(reg, hostId) then
		return nil, "you're already in a game"
	end
	local room: Room = {
		id = reg.nextId,
		name = "",
		hostId = hostId,
		members = { { id = hostId, name = name } },
		settings = RoomSettings.validate(raw),
		status = "Waiting",
		session = nil,
	}
	reg.nextId += 1
	rename(room)
	table.insert(reg.rooms, room)
	return room, nil
end

function Rooms.join(reg: Registry, roomId: any, playerId: string, name: string): (boolean, string?)
	local room = Rooms.byId(reg, roomId)
	if not room then
		return false, "that game has closed"
	elseif Rooms.roomOf(reg, playerId) then
		return false, "you're already in a game"
	elseif room.status ~= "Waiting" then
		return false, "that game has already started"
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
		rename(room)
	end
	return room
end

function Rooms.updateSettings(reg: Registry, playerId: string, raw: any): (boolean, string?)
	local room = Rooms.roomOf(reg, playerId)
	if not room or room.hostId ~= playerId then
		return false, "only the host can change the settings"
	elseif room.status ~= "Waiting" then
		return false, "the game has already started"
	end
	local settings = RoomSettings.validate(raw)
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
	elseif not room.settings.bots and #room.members < 2 then
		return false, "waiting for another player"
	end
	return true, nil
end

function Rooms.list(reg: Registry): { RoomView }
	local views = {}
	for _, room in reg.rooms do
		table.insert(views, {
			id = room.id,
			name = room.name,
			hostName = hostName(room),
			players = #room.members,
			maxPlayers = room.settings.maxPlayers,
			status = room.status,
			settings = room.settings,
			members = table.clone(room.members),
		})
	end
	return views
end

return Rooms
