--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Rooms = require(ServerScriptService.Server.Rooms)
local Expect = require(script.Parent.Expect)

local tests = {}

local function names(room: Rooms.Room): string
	local list = {}
	for _, member in room.members do
		table.insert(list, member.id)
	end
	return table.concat(list, ",")
end

tests["a player creates a room and is its host"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", { maxPlayers = 3 }))
	Expect.equal(room.hostId, "a")
	Expect.equal(room.name, "Ana's game")
	Expect.equal(room.status, "Waiting")
	Expect.equal(room.settings.maxPlayers, 3)
	Expect.equal(Rooms.roomOf(reg, "a"), room)
	local again, err = Rooms.create(reg, "a", "Ana", nil)
	Expect.equal(again, nil, "one room at a time")
	Expect.equal(err ~= nil, true)
end

tests["others join until it's full"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", { maxPlayers = 2 }))
	Expect.equal((Rooms.join(reg, room.id, "b", "Ben")), true)
	Expect.equal(names(room), "a,b")
	local ok, err = Rooms.join(reg, room.id, "c", "Cy")
	Expect.equal(ok, false, "full")
	Expect.equal(err, "that game is full")
	Expect.equal((Rooms.join(reg, 999, "c", "Cy")), false, "no such room")
end

tests["a member can't join a second room, and nobody joins a game in progress"] = function()
	local reg = Rooms.new()
	local first = assert(Rooms.create(reg, "a", "Ana", nil))
	local second = assert(Rooms.create(reg, "b", "Ben", nil))
	Expect.equal((Rooms.join(reg, second.id, "a", "Ana")), false)
	first.status = "Playing"
	Expect.equal((Rooms.join(reg, first.id, "c", "Cy")), false)
end

tests["the host leaving hands the room on; the last one out closes it"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", nil))
	Rooms.join(reg, room.id, "b", "Ben")
	Rooms.leave(reg, "a")
	Expect.equal(room.hostId, "b")
	Expect.equal(room.name, "Ben's game")
	Expect.equal(Rooms.roomOf(reg, "a"), nil)
	Rooms.leave(reg, "b")
	Expect.equal(#Rooms.list(reg), 0, "closed")
end

tests["only the waiting room's host changes settings, never below its member count"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", nil))
	Rooms.join(reg, room.id, "b", "Ben")
	Rooms.join(reg, room.id, "c", "Cy")
	Expect.equal((Rooms.updateSettings(reg, "b", { startingMoney = 3000 })), false, "not the host")
	Expect.equal((Rooms.updateSettings(reg, "a", { startingMoney = 3000, maxPlayers = 2 })), true)
	Expect.equal(room.settings.startingMoney, 3000)
	Expect.equal(room.settings.maxPlayers, 3, "kept room for everyone already in")
	room.status = "Playing"
	Expect.equal((Rooms.updateSettings(reg, "a", { startingMoney = 500 })), false, "not mid-game")
end

tests["only the host starts, and only a waiting room"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", nil))
	Rooms.join(reg, room.id, "b", "Ben")
	Expect.equal((Rooms.canStart(reg, "b")), false)
	Expect.equal((Rooms.canStart(reg, "a")), true)
	room.status = "Playing"
	Expect.equal((Rooms.canStart(reg, "a")), false)
end

tests["without bots a room needs two players to start"] = function()
	local reg = Rooms.new()
	assert(Rooms.create(reg, "a", "Ana", { bots = false }))
	local ok, err = Rooms.canStart(reg, "a")
	Expect.equal(ok, false)
	Expect.equal(err, "waiting for another player")
end

tests["the list shows each room's summary in creation order"] = function()
	local reg = Rooms.new()
	local one = assert(Rooms.create(reg, "a", "Ana", { maxPlayers = 5 }))
	assert(Rooms.create(reg, "b", "Ben", nil))
	Rooms.join(reg, one.id, "c", "Cy")
	local list = Rooms.list(reg)
	Expect.equal(#list, 2)
	Expect.equal(list[1].name, "Ana's game")
	Expect.equal(list[1].players, 2)
	Expect.equal(list[1].maxPlayers, 5)
	Expect.equal(list[1].status, "Waiting")
	Expect.equal(list[1].hostName, "Ana")
	Expect.equal(list[2].hostName, "Ben")
end

tests["a hosted ranked room is listed, joined and set up like any other, and needs two people to start"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", { maxPlayers = 4, startingMoney = 3000, bots = true }, true))
	Expect.equal(room.ranked, true)
	Expect.equal(room.name, "Ana's ranked game")
	Expect.equal(room.settings.startingMoney, 3000, "any settings")
	Expect.equal(Rooms.list(reg)[1].ranked, true, "listed, marked ranked")
	Expect.equal((Rooms.canStart(reg, "a")), false, "not alone, even with bots")
	Expect.equal((Rooms.join(reg, room.id, "b", "Ben")), true)
	Expect.equal((Rooms.updateSettings(reg, "a", { maxPlayers = 6, freeParking = true })), true, "the host changes the settings")
	Expect.equal((Rooms.canStart(reg, "a")), true)
	Expect.equal(Rooms.list(reg)[1].ranked, true)
end

tests["a ranked room is only real players with no game length, whatever the host asks for"] = function()
	local reg = Rooms.new()
	local room = assert(Rooms.create(reg, "a", "Ana", { bots = true, length = "Rounds100" }, true))
	Expect.equal(room.settings.bots, false, "no bots on create")
	Expect.equal(room.settings.length, "Off", "no length on create")
	assert(Rooms.updateSettings(reg, "a", { bots = true, length = "Rounds300", startingMoney = 2000 }))
	Expect.equal(room.settings.bots, false, "no bots on update")
	Expect.equal(room.settings.length, "Off", "no length on update")
	Expect.equal(room.settings.startingMoney, 2000, "other settings still the host's")
	local casual = assert(Rooms.create(reg, "b", "Ben", { bots = true, length = "Rounds100" }))
	Expect.equal(casual.settings.bots, true, "casual keeps bots")
	Expect.equal(casual.settings.length, "Rounds100", "casual keeps its length")
end

tests["a queue-matched ranked room holds its matched players, isn't listed and can't be joined"] = function()
	local reg = Rooms.new()
	local room = Rooms.createRanked(reg, { { id = "a", name = "Ana" }, { id = "b", name = "Ben" } }, { maxPlayers = 2 })
	Expect.equal(room.ranked, true)
	Expect.equal(Rooms.roomOf(reg, "b"), room)
	Expect.equal(#Rooms.list(reg), 0, "not in the casual list")
	Expect.equal((Rooms.join(reg, room.id, "c", "Cy")), false)
	Expect.equal((Rooms.updateSettings(reg, "a", { startingMoney = 5000 })), false, "ranked rules are fixed")
end

return tests
