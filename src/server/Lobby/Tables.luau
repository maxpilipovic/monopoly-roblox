--!strict
-- Which room sits at which lobby table, and who sits in which chair. Pure bookkeeping beside Rooms:
-- a waiting or playing room keeps its table until the room closes (sync), and a chair is a
-- player's for as long as they sit in it. Quick play picks the table to send a player to.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableLayout = require(ReplicatedStorage.Shared.Lobby.TableLayout)

export type Seating = {
	tableOfRoom: { [number]: number },
	roomAtTable: { [number]: number },
	chairs: { [number]: { [number]: string } }, -- table id -> chair -> player id
}

export type RoomInfo = { id: number, ranked: boolean, status: string, players: number, maxPlayers: number }

local Tables = {}

function Tables.new(): Seating
	return { tableOfRoom = {}, roomAtTable = {}, chairs = {} }
end

local function freeTable(s: Seating, ranked: boolean): number?
	for _, id in TableLayout.ids(if ranked then "Ranked" else "Casual") do
		if not s.roomAtTable[id] then
			return id
		end
	end
	return nil
end

-- Gives the room a table: `wanted` if it's free and of the room's kind, else the lowest free one.
function Tables.assign(s: Seating, roomId: number, ranked: boolean, wanted: number?): number?
	local kind = if ranked then "Ranked" else "Casual"
	local id = if wanted and wanted >= 1 and wanted <= TableLayout.COUNT and TableLayout.kind(wanted) == kind and not s.roomAtTable[wanted]
		then wanted
		else freeTable(s, ranked)
	if id then
		s.tableOfRoom[roomId] = id
		s.roomAtTable[id] = roomId
	end
	return id
end

function Tables.tableOf(s: Seating, roomId: number): number?
	return s.tableOfRoom[roomId]
end

function Tables.roomAt(s: Seating, tableId: number): number?
	return s.roomAtTable[tableId]
end

-- Frees the tables (and chairs) of rooms that no longer exist.
function Tables.sync(s: Seating, liveRoomIds: { [number]: boolean })
	for roomId, tableId in table.clone(s.tableOfRoom) do
		if not liveRoomIds[roomId] then
			s.tableOfRoom[roomId] = nil
			s.roomAtTable[tableId] = nil
			s.chairs[tableId] = nil
		end
	end
end

function Tables.freeChair(s: Seating, tableId: number, maxPlayers: number): number?
	local taken = s.chairs[tableId] or {}
	for chair = 1, math.min(maxPlayers, TableLayout.CHAIRS) do
		if not taken[chair] then
			return chair
		end
	end
	return nil
end

function Tables.chairOf(s: Seating, playerId: string): (number?, number?)
	for tableId, chairs in s.chairs do
		for chair, id in chairs do
			if id == playerId then
				return tableId, chair
			end
		end
	end
	return nil, nil
end

-- Takes the player out of whatever chair they're in; says which it was.
function Tables.stand(s: Seating, playerId: string): (number?, number?)
	local tableId, chair = Tables.chairOf(s, playerId)
	if tableId and chair then
		s.chairs[tableId][chair] = nil
	end
	return tableId, chair
end

function Tables.sit(s: Seating, tableId: number, chair: number, playerId: string)
	Tables.stand(s, playerId)
	local chairs = s.chairs[tableId] or {}
	chairs[chair] = playerId
	s.chairs[tableId] = chairs
end

-- Where quick play sends someone: the fullest waiting casual room with a table and a free seat
-- (ties to the lowest id), else an empty casual table to host at; nil when every table is busy.
function Tables.quickPlay(s: Seating, rooms: { RoomInfo }): { join: number?, host: number? }?
	local best: RoomInfo? = nil
	for _, room in rooms do
		local open = not room.ranked and room.status == "Waiting" and room.players < room.maxPlayers and s.tableOfRoom[room.id] ~= nil
		if open and (not best or room.players > best.players or (room.players == best.players and room.id < best.id)) then
			best = room
		end
	end
	if best then
		return { join = best.id }
	end
	local free = freeTable(s, false)
	return if free then { host = free } else nil
end

return Tables
