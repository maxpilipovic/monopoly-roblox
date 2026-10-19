--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local RankedQueue = require(ServerScriptService.Server.RankedQueue)
local Expect = require(script.Parent.Expect)

local tests = {}

local function ids(match: RankedQueue.Match): string
	local list = table.clone(match.ids)
	table.sort(list)
	return table.concat(list, ",")
end

tests["two duellists close in rating are matched at once"] = function()
	local q = RankedQueue.new()
	RankedQueue.join(q, "a", 1000, "Duel", 0)
	RankedQueue.join(q, "b", 1060, "Duel", 0)
	local matches = RankedQueue.match(q, 0)
	Expect.equal(#matches, 1)
	Expect.equal(matches[1].mode, "Duel")
	Expect.equal(ids(matches[1]), "a,b")
	Expect.equal(RankedQueue.entryOf(q, "a"), nil, "matched players leave the queue")
end

tests["far apart ratings wait until the window has widened enough"] = function()
	local q = RankedQueue.new()
	RankedQueue.join(q, "a", 1000, "Duel", 0)
	RankedQueue.join(q, "b", 1300, "Duel", 0)
	Expect.equal(#RankedQueue.match(q, 0), 0, "300 apart: too far at first")
	Expect.equal(RankedQueue.window(0), 100)
	local wait = 0
	while RankedQueue.window(wait) < 300 do
		wait += 1
	end
	Expect.equal(#RankedQueue.match(q, wait), 1, `matched once both have waited {wait}s`)
end

tests["the window never grows past its cap"] = function()
	Expect.equal(RankedQueue.window(100000), RankedQueue.MAX_WINDOW)
end

tests["a table needs four, and modes don't mix"] = function()
	local q = RankedQueue.new()
	for index, id in { "a", "b", "c" } do
		RankedQueue.join(q, id, 1000 + index, "Table", 0)
	end
	RankedQueue.join(q, "d", 1000, "Duel", 0)
	Expect.equal(#RankedQueue.match(q, 0), 0, "three at the table, one duellist")
	RankedQueue.join(q, "e", 1010, "Table", 0)
	local matches = RankedQueue.match(q, 0)
	Expect.equal(#matches, 1)
	Expect.equal(ids(matches[1]), "a,b,c,e")
	Expect.equal(RankedQueue.entryOf(q, "d") ~= nil, true, "the duellist still waits")
end

tests["the longest waiting player is matched with the closest ratings"] = function()
	local q = RankedQueue.new()
	RankedQueue.join(q, "old", 1000, "Duel", 0)
	RankedQueue.join(q, "far", 1090, "Duel", 5)
	RankedQueue.join(q, "near", 1010, "Duel", 6)
	local matches = RankedQueue.match(q, 6)
	Expect.equal(ids(matches[1]), "near,old")
end

tests["joining again changes mode; leaving removes"] = function()
	local q = RankedQueue.new()
	RankedQueue.join(q, "a", 1000, "Duel", 0)
	RankedQueue.join(q, "a", 1000, "Table", 3)
	Expect.equal((RankedQueue.entryOf(q, "a") :: any).mode, "Table")
	RankedQueue.leave(q, "a")
	Expect.equal(RankedQueue.entryOf(q, "a"), nil)
	Expect.equal(RankedQueue.SIZES.Duel, 2)
	Expect.equal(RankedQueue.SIZES.Table, 4)
end

return tests
