--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local PAY = { type = "PayDebt" }
local BANKRUPT = { type = "Bankrupt" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 ($3) lands on p2's Oriental Avenue and owes $6 rent.
local function owesRent(playerCount: number)
	local state = GameFixtures.newGame(playerCount, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	player(state, "p1").money = 3
	return state
end

-- p1 ($100) rolls onto Income Tax ($200) and owes the bank.
local function owesTax(playerCount: number)
	local state = GameFixtures.newGame(playerCount, { { 1, 3 } })
	player(state, "p1").money = 100
	return state
end

tests["Bankrupt is refused while you can pay"] = function()
	local state = owesRent(2)
	act(state, "p1", ROLL)
	player(state, "p1").money = 10
	local ok, err = Engine.act(state, "p1", BANKRUPT)
	assert(not ok, "went bankrupt while able to pay")
	Expect.equal(err, "you can pay this debt")
	assert(not player(state, "p1").bankrupt, "flagged bankrupt")
	Expect.equal(#state.debts, 1, "debt kept")
end

tests["going bankrupt to a player hands over cash, deeds and jail cards"] = function()
	local state = owesRent(3)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3, 1)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	state.bankHouses = 30
	player(state, "p1").jailCards = { "chance.jailFree" }
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)

	local p1, p2 = player(state, "p1"), player(state, "p2")
	assert(p1.bankrupt, "p1 not bankrupt")
	Expect.equal(p1.money, 0, "p1 cash")
	-- $3 cash + 2 houses sold at $25 each, minus $10 interest on Reading Railroad.
	Expect.equal(p2.money, 1500 + 3 + 50 - 10, "p2 cash")
	for _, position in { 1, 3, 5 } do
		Expect.equal(state.properties[position].owner, "p2", `owner of {position}`)
	end
	Expect.equal(state.properties[1].houses, 0, "houses sold")
	Expect.equal(state.bankHouses, 32, "houses back in the bank")
	Expect.equal(state.properties[5].mortgaged, true, "mortgage kept")
	Expect.equal(p2.jailCards[1], "chance.jailFree", "jail card passed on")
	Expect.equal(#p1.jailCards, 0, "p1 has no cards")
	local went = GameFixtures.eventsOfType(state, "WentBankrupt")[1]
	Expect.equal(went.player, "p1", "event player")
	Expect.equal(went.creditor, "p2", "event creditor")
	local reasons = {}
	for _, paid in GameFixtures.eventsOfType(state, "Paid") do
		reasons[paid.reason] = paid.amount
	end
	Expect.equal(reasons.Bankruptcy, 53, "cash handed over")
	Expect.equal(reasons.MortgageInterest, 10, "interest")
	Expect.equal(Engine.currentPlayer(state).id, "p2", "turn passed on")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#state.debts, 0, "no debts left")
end

tests["a creditor who can't afford the interest owes it to the bank, then the turn passes on"] = function()
	local state = owesRent(3)
	GameFixtures.own(state, "p1", 5)
	GameFixtures.own(state, "p1", 15)
	state.properties[5].mortgaged = true
	state.properties[15].mortgaged = true
	act(state, "p1", ROLL)
	player(state, "p2").money = 0
	act(state, "p1", BANKRUPT)

	Expect.equal(state.phase, "Debt")
	Expect.equal(Engine.actingPlayer(state), "p2", "creditor must settle")
	Expect.equal(#state.debts, 2, "interest on both deeds")
	Expect.equal(state.debts[1].creditor, nil, "owed to the bank")
	Expect.equal(state.debts[1].reason, "MortgageInterest")
	player(state, "p2").money = 100
	act(state, "p2", PAY)
	act(state, "p2", PAY)
	Expect.equal(player(state, "p2").money, 80, "paid 2 x $10")
	Expect.equal(Engine.currentPlayer(state).id, "p2", "bankrupt p1's turn is over")
	Expect.equal(state.phase, "Roll")
end

tests["going bankrupt to the bank returns buildings and cards, then auctions each deed"] = function()
	local state = owesTax(3)
	GameFixtures.own(state, "p1", 1, 2)
	GameFixtures.own(state, "p1", 3, 2)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	state.bankHouses = 28
	player(state, "p1").jailCards = { "chest.jailFree" }
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)

	Expect.equal(player(state, "p1").money, 0, "cash gone")
	Expect.equal(state.bankHouses, 32, "houses back")
	local chest = state.decks.CommunityChest
	Expect.equal(chest[#chest], "chest.jailFree", "card back under the deck")
	Expect.equal(GameFixtures.eventsOfType(state, "WentBankrupt")[1].creditor, nil, "to the bank")

	Expect.equal(state.phase, "Auction")
	Expect.equal(state.auction.position, 1, "first deed in board order")
	Expect.equal(table.concat(state.auction.bidders, ","), "p2,p3", "bankrupt p1 doesn't bid")
	Expect.equal(state.properties[1], nil, "released to the bank")
	act(state, "p2", { type = "Bid", amount = 10 })
	act(state, "p3", { type = "PassBid" })
	Expect.equal(state.properties[1].owner, "p2", "p2 won Mediterranean")
	Expect.equal(state.properties[1].houses, 0, "sold bare")

	Expect.equal(state.auction.position, 3, "next deed")
	act(state, "p2", { type = "PassBid" })
	act(state, "p3", { type = "PassBid" })
	Expect.equal(state.properties[3], nil, "no bids: stays with the bank")

	Expect.equal(state.auction.position, 5, "last deed")
	act(state, "p2", { type = "PassBid" })
	act(state, "p3", { type = "Bid", amount = 50 })
	Expect.equal(state.properties[5].owner, "p3", "p3 won Reading")
	Expect.equal(state.properties[5].mortgaged, false, "sold unmortgaged")

	Expect.equal(state.auction, nil, "auctions over")
	Expect.equal(Engine.currentPlayer(state).id, "p2", "turn passed on")
	Expect.equal(state.phase, "Roll")
end

tests["bankruptcy on someone else's turn lets that turn carry on"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 14
	player(state, "p2").money = 5
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.birthday" })
	act(state, "p1", ROLL)
	Expect.equal(Engine.actingPlayer(state), "p2")
	act(state, "p2", BANKRUPT)
	assert(player(state, "p2").bankrupt, "p2 not bankrupt")
	Expect.equal(player(state, "p1").money, 1500 + 10 + 5, "p3's $10 and p2's last $5")
	Expect.equal(state.phase, "EndTurn", "p1's turn resumes")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(Engine.currentPlayer(state).id, "p3", "bankrupt p2 is skipped")
end

tests["a bankrupt player's other debts are dropped"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 4
	player(state, "p1").money = 20
	GameFixtures.stackDeck(state, "Chance", { "chance.chairman" })
	act(state, "p1", ROLL)
	Expect.equal(#state.debts, 2, "owes p2 and p3")
	act(state, "p1", BANKRUPT)
	Expect.equal(#state.debts, 0, "debt to p3 dropped")
	Expect.equal(player(state, "p2").money, 1520, "p2 got the $20")
	Expect.equal(player(state, "p3").money, 1500, "p3 got nothing")
	Expect.equal(Engine.currentPlayer(state).id, "p2")
	Expect.equal(state.phase, "Roll")
end

tests["the last player standing wins"] = function()
	local state = owesTax(2)
	GameFixtures.own(state, "p1", 1)
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p2")
	Expect.equal(GameFixtures.eventsOfType(state, "GameOver")[1].winner, "p2", "event")
	Expect.equal(state.auction, nil, "no auction once the game is over")
	Expect.equal(#state.auctionQueue, 0, "queue discarded")
	Expect.equal(Engine.actingPlayer(state), nil)
	local ok, err = Engine.act(state, "p2", ROLL)
	assert(not ok, "acted after game over")
	Expect.equal(err, "the game is over")
end

tests["when the last human goes bankrupt the richest remaining player wins"] = function()
	local state = owesTax(3)
	player(state, "p2").isBot = true
	player(state, "p3").isBot = true
	player(state, "p3").money = 1400
	GameFixtures.own(state, "p3", 39) -- $1400 + $400 beats p2's $1500
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p3")
end

tests["net worth ties go to the earlier seat"] = function()
	local state = owesTax(3)
	player(state, "p2").isBot = true
	player(state, "p3").isBot = true
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.winner, "p2")
end

tests["a bot going bankrupt doesn't end the game while a human plays on"] = function()
	local state = owesTax(3)
	player(state, "p1").isBot = true
	player(state, "p3").isBot = true
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.phase, "Roll")
	Expect.equal(state.winner, nil)
	Expect.equal(Engine.currentPlayer(state).id, "p2")
end

return tests
