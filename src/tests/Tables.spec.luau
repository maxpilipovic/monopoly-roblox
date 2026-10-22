--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Tables = require(ServerScriptService.Server.Lobby.Tables)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["assign takes the lowest free table of the room's kind"] = function()
	local s = Tables.new()
	Expect.equal(Tables.assign(s, 1, false), 1)
	Expect.equal(Tables.assign(s, 2, false), 2)
	Expect.equal(Tables.assign(s, 3, true), 5)
	Expect.equal(Tables.tableOf(s, 2), 2)
	Expect.equal(Tables.roomAt(s, 5), 3)
end

tests["assign honours a wanted free table and refuses a busy or wrong-kind one"] = function()
	local s = Tables.new()
	Expect.equal(Tables.assign(s, 1, false, 3), 3)
	Expect.equal(Tables.assign(s, 2, false, 3), 1, "3 is taken: the lowest free instead")
	Expect.equal(Tables.assign(s, 3, false, 6), 2, "6 is a ranked table")
end

tests["assign returns nil when every table of that kind is taken"] = function()
	local s = Tables.new()
	for room = 1, 4 do
		assert(Tables.assign(s, room, false), `room {room} got no table`)
	end
	Expect.equal(Tables.assign(s, 5, false), nil, "fifth casual room")
	Expect.equal(Tables.assign(s, 6, true), 5, "ranked still free")
end

tests["sync frees the tables of closed rooms only"] = function()
	local s = Tables.new()
	Tables.assign(s, 1, false)
	Tables.assign(s, 2, false)
	Tables.sit(s, 1, 1, "a")
	Tables.sit(s, 2, 1, "b")
	Tables.sync(s, { [2] = true })
	Expect.equal(Tables.tableOf(s, 1), nil)
	Expect.equal(Tables.roomAt(s, 1), nil)
	Expect.equal(Tables.chairOf(s, "a"), nil, "chairs at the freed table cleared")
	Expect.equal(Tables.tableOf(s, 2), 2)
	Expect.equal(select(2, Tables.chairOf(s, "b")), 1)
end

tests["free chairs go lowest first, within the player limit"] = function()
	local s = Tables.new()
	Tables.assign(s, 1, false)
	Tables.sit(s, 1, 1, "a")
	Tables.sit(s, 1, 2, "b")
	Expect.equal(Tables.freeChair(s, 1, 4), 3)
	Tables.sit(s, 1, 3, "c")
	Tables.sit(s, 1, 4, "d")
	Expect.equal(Tables.freeChair(s, 1, 4), nil, "four-player room is full")
	Expect.equal(Tables.freeChair(s, 1, 6), 5)
end

tests["standing frees the chair and says which"] = function()
	local s = Tables.new()
	Tables.assign(s, 1, false)
	Tables.sit(s, 1, 2, "a")
	local tableId, chair = Tables.stand(s, "a")
	Expect.equal(tableId, 1)
	Expect.equal(chair, 2)
	Expect.equal(Tables.chairOf(s, "a"), nil)
	Expect.equal(Tables.stand(s, "a"), nil, "standing twice")
	Expect.equal(Tables.freeChair(s, 1, 4), 1)
end

tests["standing up during a game frees the chair but the room keeps its table"] = function()
	local s = Tables.new()
	Tables.assign(s, 1, false)
	Tables.sit(s, 1, 1, "a")
	Tables.stand(s, "a")
	Expect.equal(Tables.tableOf(s, 1), 1)
end

tests["sitting somewhere new moves you out of your old chair"] = function()
	local s = Tables.new()
	Tables.assign(s, 1, false)
	Tables.sit(s, 1, 1, "a")
	Tables.sit(s, 1, 3, "a")
	Expect.equal(Tables.freeChair(s, 1, 6), 1)
	Expect.equal(select(2, Tables.chairOf(s, "a")), 3)
end

local function room(id: number, ranked: boolean, status: string, players: number): Tables.RoomInfo
	return { id = id, ranked = ranked, status = status, players = players, maxPlayers = 4 }
end

tests["quick play joins the fullest open casual room, else hosts at a free casual table"] = function()
	local s = Tables.new()
	for id = 1, 3 do
		Tables.assign(s, id, false) -- casual tables 1-3
	end
	Tables.assign(s, 4, true) -- ranked table 5
	local rooms = {
		room(1, false, "Waiting", 2),
		room(2, false, "Waiting", 3),
		room(3, false, "Playing", 1),
		room(4, true, "Waiting", 1),
	}
	local pick = Tables.quickPlay(s, rooms) :: any
	Expect.equal(pick.join, 2, "fullest open casual room")
	local closed = { room(1, false, "Waiting", 4), rooms[3], rooms[4] }
	pick = Tables.quickPlay(s, closed) :: any
	Expect.equal(pick.host, 4, "the free casual table")
	Tables.assign(s, 9, false)
	Expect.equal(Tables.quickPlay(s, closed), nil, "every casual table busy")
end

tests["quick play skips a room with no table"] = function()
	local s = Tables.new()
	local pick = Tables.quickPlay(s, { room(7, false, "Waiting", 2) }) :: any
	Expect.equal(pick.join, nil)
	Expect.equal(pick.host, 1)
end

return tests
