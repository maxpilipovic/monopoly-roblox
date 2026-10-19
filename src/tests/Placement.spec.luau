--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Placement = require(ServerScriptService.Server.Game.Placement)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function describe(places: { [string]: number }): string
	local ids = {}
	for id in places do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		table.insert(parts, `{id}={places[id]}`)
	end
	return table.concat(parts, " ")
end

tests["the winner is first, the others by net worth, the bankrupt last in reverse order of going broke"] = function()
	local state = GameFixtures.bareState(5)
	state.players[1].money = 900
	state.players[2].money = 2000
	state.players[3].money = 400
	state.players[4].bankrupt = true
	state.players[5].bankrupt = true
	state.bankruptOrder = { "p5", "p4" } -- p5 went broke first
	state.winner = "p2"
	Expect.equal(describe(Placement.of(state)), "p1=2 p2=1 p3=3 p4=4 p5=5")
end

tests["equal net worth shares a place, and the next place skips"] = function()
	local state = GameFixtures.bareState(4)
	state.players[1].money = 1000
	state.players[2].money = 700
	state.players[3].money = 700
	state.players[4].money = 100
	state.winner = "p1"
	Expect.equal(describe(Placement.of(state)), "p1=1 p2=2 p3=2 p4=4")
end

tests["the winner stays first even on a tie of net worth"] = function()
	local state = GameFixtures.bareState(2)
	state.winner = "p2"
	Expect.equal(describe(Placement.of(state)), "p1=2 p2=1")
end

tests["a player leaving places behind everyone still in, ahead of anyone already broke"] = function()
	local state = GameFixtures.bareState(4)
	state.players[1].money = 50
	state.players[2].money = 3000
	state.players[3].money = 800
	state.players[4].bankrupt = true
	state.bankruptOrder = { "p4" }
	Expect.equal(describe(Placement.leaving(state, "p1")), "p1=3 p2=1 p3=2 p4=4")
end

tests["the ordinal reads like a scoreboard"] = function()
	Expect.equal(Placement.ordinal(1), "1st")
	Expect.equal(Placement.ordinal(2), "2nd")
	Expect.equal(Placement.ordinal(3), "3rd")
	Expect.equal(Placement.ordinal(4), "4th")
	Expect.equal(Placement.ordinal(11), "11th")
end

return tests
