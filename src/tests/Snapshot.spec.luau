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

tests["snapshot shows the open debt, the winner and each player's net worth"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
	local snapshot = Snapshot.fromState(state)
	local debt = snapshot.debt :: any
	Expect.equal(debt.debtor, "p1", "debtor")
	Expect.equal(debt.creditor, "p2", "creditor")
	Expect.equal(debt.amount, 200, "amount")
	Expect.equal(debt.reason, "Rent", "reason")
	Expect.equal(snapshot.players[1].netWorth, 1560, "cash + Mediterranean")
	Expect.equal(snapshot.winner, nil, "no winner yet")
	state.winner = "p2"
	state.phase = "GameOver"
	state.debts = {}
	Expect.equal(Snapshot.fromState(state).winner, "p2", "winner")
	Expect.equal(Snapshot.fromState(state).debt, nil, "no debt")
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

tests["snapshot shows the open trade and the offers left"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", 39)
	Expect.equal(Snapshot.fromState(state).tradeOffersLeft, 3, "fresh turn")
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 100), GameFixtures.side({ 39 })))
	local snapshot = Snapshot.fromState(state)
	local trade = snapshot.trade :: any
	Expect.equal(trade.from, "p1", "from")
	Expect.equal(trade.to, "p2", "to")
	Expect.equal(trade.give.cash, 100, "give cash")
	Expect.equal(trade.get.properties[1], 39, "get deed")
	Expect.equal(snapshot.tradeOffersLeft, 3, "p2 is acting and has offered nothing")
	Engine.act(state, "p2", { type = "DeclineTrade" })
	snapshot = Snapshot.fromState(state)
	Expect.equal(snapshot.trade, nil, "closed")
	Expect.equal(snapshot.tradeOffersLeft, 2, "p1 used one")
end

tests["snapshot carries the match settings, round and deadlines"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 25
	local snapshot = Snapshot.fromState(state, { timer = "Fast", length = "Rounds25", endsAt = nil, turnDeadline = 123 })
	Expect.equal(snapshot.match.timer, "Fast", "timer")
	Expect.equal(snapshot.match.length, "Rounds25", "length")
	Expect.equal(snapshot.match.round, 1, "round")
	Expect.equal(snapshot.match.roundLimit, 25, "limit")
	Expect.equal(snapshot.match.turnDeadline, 123, "deadline")
	Expect.equal(snapshot.match.endsAt, nil, "no minutes limit")

	local plain = Snapshot.fromState(state)
	Expect.equal(plain.match.timer, "Off", "no match info")
	Expect.equal(plain.match.length, "Off")
	Expect.equal(plain.match.turnDeadline, nil)
	Expect.equal(plain.winReason, nil, "no winner yet")
	state.winReason = "TimeLimit"
	Expect.equal(Snapshot.fromState(state).winReason, "TimeLimit", "reason")
end

tests["snapshot names the acting player, jail attempts, and the bank for a bankrupt creditor"] = function()
	local state = GameFixtures.newGame(3, { { 2, 4 } })
	Expect.equal(Snapshot.fromState(state).acting, "p1", "roll")
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	Expect.equal(Snapshot.fromState(state).acting, "p1", "decliner bids first")
	Engine.act(state, "p1", { type = "PassBid" })
	Expect.equal(Snapshot.fromState(state).acting, "p2", "next bidder")

	local jailed = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(jailed, "p1") :: any
	p1.inJail = true
	p1.jailAttempts = 2
	Expect.equal(Snapshot.fromState(jailed).players[1].jailAttempts, 2, "jail attempts")

	local owing = GameFixtures.newGame(3)
	GameFixtures.inDebt(owing, "p1", 100, "p2", "Rent")
	Expect.equal((Snapshot.fromState(owing).debt :: any).creditor, "p2", "live creditor")
	Engine.getPlayer(owing, "p2").bankrupt = true
	Expect.equal((Snapshot.fromState(owing).debt :: any).creditor, nil, "bankrupt creditor: owed to the bank")
	owing.phase = "GameOver"
	Expect.equal(Snapshot.fromState(owing).acting, nil, "game over")
end

tests["the snapshot says which map is in play"] = function()
	Expect.equal(Snapshot.fromState(GameFixtures.newGame(2)).map, "Classic")
	local state = GameFixtures.newGame(2)
	state.map = "College"
	Expect.equal(Snapshot.fromState(state).map, "College")
end

return tests
