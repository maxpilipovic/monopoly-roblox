--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["players keep their seat order and public fields"] = function()
	local state = GameFixtures.newGame(3)
	local snapshot = Snapshot.fromState(state)
	Expect.equal(#snapshot.players, 3)
	for seat, view in snapshot.players do
		Expect.equal(view.id, `p{seat}`, "id")
		Expect.equal(view.seat, seat, "seat")
		Expect.equal(view.money, 1500, "money")
	end
	Expect.equal(snapshot.phase, "Roll")
	Expect.equal(snapshot.currentPlayer, "p1")
	Expect.equal(snapshot.auction, nil)
end

tests["properties become an array sorted by position"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", 39)
	GameFixtures.own(state, "p1", 6)
	GameFixtures.own(state, "p1", 12)
	local snapshot = Snapshot.fromState(state)
	Expect.equal(#snapshot.properties, 3)
	Expect.equal(snapshot.properties[1].position, 6)
	Expect.equal(snapshot.properties[2].position, 12)
	Expect.equal(snapshot.properties[3].position, 39)
	Expect.equal(snapshot.properties[3].owner, "p2")
end

tests["auction view names who bids next"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	Engine.act(state, "p1", { type = "Bid", amount = 30 })
	local auction = Snapshot.fromState(state).auction :: any
	Expect.equal(auction.position, 6)
	Expect.equal(auction.highBid, 30)
	Expect.equal(auction.highBidder, "p1")
	Expect.equal(auction.currentBidder, "p2")
end

tests["players show jail status and how many jail cards they hold"] = function()
	local state = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(state, "p1") :: any
	p1.inJail = true
	p1.jailCards = { "chance.jailFree", "chest.jailFree" }
	local view = Snapshot.fromState(state).players[1]
	Expect.equal(view.inJail, true, "inJail")
	Expect.equal(view.jailCards, 2, "jailCards")
	Expect.equal(Snapshot.fromState(state).players[2].inJail, false, "p2")
end

tests["snapshot shares no tables with the game state"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	local snapshot = Snapshot.fromState(state)
	snapshot.players[1].money = 0;
	(snapshot.lastRoll :: { number })[1] = 99
	Expect.equal(state.players[1].money, 1500, "player money")
	Expect.equal((state.lastRoll :: { number })[1], 2, "last roll")
end

return tests
