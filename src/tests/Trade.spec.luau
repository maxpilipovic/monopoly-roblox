--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local side, propose = GameFixtures.side, GameFixtures.propose
local PARK_PLACE, BOARDWALK, READING, ORIENTAL = 37, 39, 5, 6
local ACCEPT, DECLINE = { type = "AcceptTrade" }, { type = "DeclineTrade" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

local function proposed(state, fromId: string, toId: string, give, get)
	local ok, err = propose(state, fromId, toId, give, get)
	assert(ok, `propose failed: {err}`)
end

tests["proposing pauses the game on the receiver"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", BOARDWALK)
	proposed(state, "p1", "p2", side(nil, 100), side({ BOARDWALK }))
	Expect.equal(state.phase, "Trade")
	Expect.equal(Engine.actingPlayer(state), "p2")
	Expect.equal(state.tradeOffers.p1, 1, "offer counted")
	local event = GameFixtures.eventsOfType(state, "TradeProposed")[1]
	Expect.equal(event.from, "p1", "from")
	Expect.equal(event.to, "p2", "to")
	Expect.equal(event.get.properties[1], BOARDWALK, "get")
	Expect.equal(event.give.cash, 100, "give")
end

tests["accepting swaps deeds, cash and jail cards and returns to the turn"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", PARK_PLACE)
	GameFixtures.own(state, "p2", BOARDWALK)
	GameFixtures.own(state, "p2", ORIENTAL)
	player(state, "p1").jailCards = { "chance.jailFree" }
	proposed(state, "p1", "p2", side({ PARK_PLACE }, 100, 1), side({ BOARDWALK, ORIENTAL }, 50))
	act(state, "p2", ACCEPT)
	Expect.equal(state.properties[PARK_PLACE].owner, "p2", "park place")
	Expect.equal(state.properties[BOARDWALK].owner, "p1", "boardwalk")
	Expect.equal(state.properties[ORIENTAL].owner, "p1", "oriental")
	Expect.equal(player(state, "p1").money, 1450, "p1 cash")
	Expect.equal(player(state, "p2").money, 1550, "p2 cash")
	Expect.equal(player(state, "p2").jailCards[1], "chance.jailFree", "card moved")
	Expect.equal(#player(state, "p1").jailCards, 0, "p1 card gone")
	Expect.equal(state.phase, "Roll", "back to p1's roll")
	Expect.equal(state.trade, nil, "trade cleared")
	Expect.equal(GameFixtures.eventsOfType(state, "TradeAccepted")[1].to, "p2", "event")
	local reasons = 0
	for _, paid in GameFixtures.eventsOfType(state, "Paid") do
		if paid.reason == "Trade" then
			reasons += 1
		end
	end
	Expect.equal(reasons, 2, "cash both ways")
end

tests["declining changes nothing and returns to the turn"] = function()
	local state = GameFixtures.newGame(2)
	state.phase = "EndTurn"
	GameFixtures.own(state, "p2", BOARDWALK)
	proposed(state, "p1", "p2", side(nil, 100), side({ BOARDWALK }))
	act(state, "p2", DECLINE)
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(state.properties[BOARDWALK].owner, "p2", "unchanged")
	Expect.equal(player(state, "p1").money, 1500, "no cash moved")
	Expect.equal(state.trade, nil, "trade cleared")
	Expect.equal(GameFixtures.eventsOfType(state, "TradeDeclined")[1].from, "p1", "event")
end

tests["mortgaged deeds cost the receiver 10% interest"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", READING)
	state.properties[READING].mortgaged = true
	proposed(state, "p1", "p2", side(nil, 100), side({ READING }))
	act(state, "p2", ACCEPT)
	Expect.equal(state.properties[READING].owner, "p1", "owner")
	Expect.equal(state.properties[READING].mortgaged, true, "still mortgaged")
	Expect.equal(player(state, "p1").money, 1500 - 100 - 10, "price + interest")
end

tests["interest the receiver can't pay becomes a debt, then the turn resumes"] = function()
	local state = GameFixtures.newGame(2)
	player(state, "p1").money = 100
	GameFixtures.own(state, "p2", READING)
	state.properties[READING].mortgaged = true
	proposed(state, "p1", "p2", side(nil, 100), side({ READING }))
	act(state, "p2", ACCEPT)
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.resumePhase, "Roll")
	Expect.equal(state.debts[1].reason, "MortgageInterest", "interest owed")
	Expect.equal(Engine.actingPlayer(state), "p1")
	player(state, "p1").money = 10
	act(state, "p1", { type = "PayDebt" })
	Expect.equal(state.phase, "Roll")
end

tests["a debtor can trade for cash and then pay"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", ORIENTAL)
	GameFixtures.own(state, "p1", BOARDWALK)
	player(state, "p1").money = 3
	act(state, "p1", { type = "Roll" }) -- owes $6 rent
	Expect.equal(state.phase, "Debt")
	proposed(state, "p1", "p2", side({ BOARDWALK }), side(nil, 400))
	Expect.equal(state.phase, "Trade", "the debt hook must not take over")
	Expect.equal(Engine.actingPlayer(state), "p2")
	act(state, "p2", ACCEPT)
	Expect.equal(state.phase, "Debt", "back to the debt")
	Expect.equal(player(state, "p1").money, 403, "raised the cash")
	act(state, "p1", { type = "PayDebt" })
	Expect.equal(state.phase, "EndTurn")
end

tests["a debtor can't hand their deeds to another player"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p1", BOARDWALK)
	GameFixtures.inDebt(state, "p1", 1000)
	local ok, err = propose(state, "p1", "p2", side({ BOARDWALK }), side())
	assert(not ok, "gift accepted")
	Expect.equal(err, "while in debt you must get at least $200 in value")
	Expect.equal(state.phase, "Debt", "still in debt")
end

tests["a player with a queued debt can't sell cheap either"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p2", BOARDWALK)
	GameFixtures.inDebt(state, "p1", 1000)
	table.insert(state.debts, { debtor = "p2", creditor = "p1", amount = 50, reason = "Card" })
	local ok, err = propose(state, "p1", "p2", side(nil, 1), side({ BOARDWALK }))
	assert(not ok, "cheap buy accepted")
	Expect.equal(err, "Player 2 is in debt and must get at least $200 in value")
end

tests["only the receiver answers, and nothing else happens meanwhile"] = function()
	local state = GameFixtures.newGame(3)
	proposed(state, "p1", "p2", side(nil, 10), side())
	for _, case in {
		{ "p1", ACCEPT, "waiting for another player to answer a trade" },
		{ "p1", { type = "Roll" }, "waiting for another player to answer a trade" },
		{ "p3", DECLINE, "waiting for another player to answer a trade" },
		{ "p2", { type = "Roll" }, "answer the trade first" },
	} :: { any } do
		local ok, err = Engine.act(state, case[1], case[2])
		assert(not ok, `{case[1]} {case[2].type} accepted`)
		Expect.equal(err, case[3], `{case[1]} {case[2].type}`)
	end
	Expect.equal(state.phase, "Trade")
	act(state, "p2", ACCEPT)
end

tests["trades can't be proposed mid-decision, in an auction, or by someone else"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	assert(not propose(state, "p2", "p1", side(nil, 10), side()), "p2 proposed on p1's turn")
	act(state, "p1", { type = "Roll" }) -- BuyDecision on Oriental
	assert(not propose(state, "p1", "p2", side(nil, 10), side()), "proposed mid-decision")
	act(state, "p1", { type = "Decline" }) -- Auction
	assert(not propose(state, "p1", "p2", side(nil, 10), side()), "proposed in an auction")
	Expect.equal(state.phase, "Auction")
	Expect.equal(#GameFixtures.eventsOfType(state, "TradeProposed"), 0)

	state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 100)
	local ok, err = propose(state, "p2", "p1", side(nil, 10), side())
	assert(not ok, "a non-debtor proposed during a debt")
	Expect.equal(err, "waiting for another player to pay a debt")
end

tests["three offers per turn, reset when the turn ends"] = function()
	local state = GameFixtures.newGame(2)
	for _ = 1, Engine.MAX_TRADE_OFFERS do
		proposed(state, "p1", "p2", side(nil, 10), side())
		act(state, "p2", DECLINE)
	end
	local ok, err = propose(state, "p1", "p2", side(nil, 10), side())
	assert(not ok, "fourth offer accepted")
	Expect.equal(err, "no trade offers left this turn")
	Expect.equal(state.phase, "Roll")
	state.phase = "EndTurn"
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(state.tradeOffers.p1, nil, "count reset")
end

tests["an accept that is no longer legal is refused and the offer stays open"] = function()
	local state = GameFixtures.newGame(2)
	proposed(state, "p1", "p2", side(nil, 10), side(nil, 100))
	player(state, "p2").money = 50
	local ok, err = Engine.act(state, "p2", ACCEPT)
	assert(not ok, "accepted without the cash")
	Expect.equal(err, "Player 2 doesn't have that much cash")
	Expect.equal(state.phase, "Trade", "still open")
	act(state, "p2", DECLINE)
	Expect.equal(state.phase, "Roll")
end

tests["garbage offers change nothing"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", PARK_PLACE)
	for _, offer in {
		5,
		{},
		{ to = "p2", give = side(nil, 0 / 0), get = side() },
		{ to = "p2", give = side({ PARK_PLACE, PARK_PLACE }), get = side() },
		{ to = "p1", give = side(nil, 10), get = side() },
		{ to = "p2", give = side(nil, -5), get = side() },
	} :: { any } do
		assert(not Engine.act(state, "p1", { type = "ProposeTrade", offer = offer }), "garbage accepted")
	end
	assert(not Engine.act(state, "p1", { type = "ProposeTrade" }), "missing offer accepted")
	Expect.equal(state.phase, "Roll")
	Expect.equal(state.tradeOffers.p1, nil, "refused offers don't count")
	Expect.equal(#state.events, 1, "only TurnStarted")
end

tests["a receiver off their turn who can't pay interest owes it, then the turn carries on"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", READING)
	state.properties[READING].mortgaged = true
	player(state, "p2").money = 5
	proposed(state, "p1", "p2", side({ READING }), side())
	act(state, "p2", ACCEPT)
	Expect.equal(state.phase, "Debt")
	Expect.equal(Engine.actingPlayer(state), "p2", "the receiver owes $10")
	player(state, "p2").money = 20
	act(state, "p2", { type = "PayDebt" })
	Expect.equal(state.phase, "Roll", "back to p1's turn")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
end

tests["interest from a trade made during a debt queues behind that debt"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", BOARDWALK)
	GameFixtures.own(state, "p2", READING)
	state.properties[READING].mortgaged = true
	player(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 50)
	proposed(state, "p1", "p2", side({ BOARDWALK }), side({ READING }, 150)) -- $250 in value for $200
	act(state, "p2", ACCEPT)
	Expect.equal(state.phase, "Debt", "back to the debt")
	Expect.equal(#state.debts, 2, "the $50, then the interest")
	Expect.equal(state.debts[2].reason, "MortgageInterest")
	act(state, "p1", { type = "PayDebt" })
	act(state, "p1", { type = "PayDebt" })
	Expect.equal(player(state, "p1").money, 90, "$150 - $50 - $10")
	Expect.equal(state.phase, "Roll", "the turn resumes")
end

return tests
