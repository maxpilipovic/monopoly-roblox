--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Tally = require(ServerScriptService.Server.Game.Tally)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["dice, moves, buys, building, rent, jail, cards, trades and ruin are counted per player"] = function()
	local state = GameFixtures.bareState(2)
	local counts = Tally.count(Tally.new(), {
		{ type = "Rolled", player = "p1", dice = { 1, 1 } },
		{ type = "Rolled", player = "p1", dice = { 6, 6 } },
		{ type = "Rolled", player = "p1", dice = { 2, 5 } },
		{ type = "Rolled", player = "p1", dice = { 3, 3 }, forCard = true },
		{ type = "Moved", player = "p1", from = 38, to = 2, passedGo = true },
		{ type = "Moved", player = "p2", from = 2, to = 5, passedGo = false },
		{ type = "Bought", player = "p1", position = 1, price = 60 },
		{ type = "AuctionEnded", position = 3, winner = "p2", amount = 30 },
		{ type = "AuctionEnded", position = 5, winner = nil, amount = 0 },
		{ type = "Built", player = "p1", position = 1, hotel = false },
		{ type = "Built", player = "p1", position = 1, hotel = true },
		{ type = "Paid", from = "p2", to = "p1", amount = 250, reason = "Rent" },
		{ type = "Paid", from = "p2", to = nil, amount = 200, reason = "Tax" },
		{ type = "Paid", from = "p1", to = "p2", amount = 50, reason = "Card" },
		{ type = "SentToJail", player = "p2", reason = "GoToJail" },
		{ type = "LeftJail", player = "p2", reason = "Doubles" },
		{ type = "LeftJail", player = "p2", reason = "Fine" },
		{ type = "CardDrawn", player = "p2", deck = "Chance", card = "x" },
		{ type = "TradeAccepted", from = "p1", to = "p2" },
		{ type = "Mortgaged", player = "p2", position = 3 },
		{ type = "WentBankrupt", player = "p2", creditor = "p1" },
		{ type = "WentBankrupt", player = "p2", creditor = nil },
	}, state)
	local p1, p2 = counts.p1, counts.p2
	Expect.equal(p1.rolls, 3, "a card's roll isn't a turn's roll")
	Expect.equal(p1.doubles, 2)
	Expect.equal(p1.snakeEyes, 1)
	Expect.equal(p1.boxcars, 1)
	Expect.equal(p1.passGo, 1)
	Expect.equal(p2.passGo, nil)
	Expect.equal(p1.propertiesBought, 1)
	Expect.equal(p2.propertiesBought, 1, "an auction win is a buy")
	Expect.equal(p2.auctionsWon, 1)
	Expect.equal(p1.housesBuilt, 1)
	Expect.equal(p1.hotelsBuilt, 1)
	Expect.equal(p1.rentCollected, 250, "only rent counts")
	Expect.equal(p2.rentCollected, nil)
	Expect.equal(p2.jailVisits, 1)
	Expect.equal(p2.jailEscapes, 1, "only a doubles escape")
	Expect.equal(p2.cardsDrawn, 1)
	Expect.equal(p1.tradesMade, 1)
	Expect.equal(p2.tradesMade, 1)
	Expect.equal(p2.mortgages, 1)
	Expect.equal(p1.bankruptcies, 1, "ruined by p1; the bank's ruin is nobody's")
end

tests["a completed colour set counts once a game"] = function()
	local state = GameFixtures.bareState(2)
	local tally = Tally.new()
	GameFixtures.own(state, "p1", 1)
	Expect.equal(Tally.count(tally, {}, state).p1, nil, "half the browns")
	GameFixtures.own(state, "p1", 3)
	Expect.equal(Tally.count(tally, {}, state).p1.monopolies, 1)
	Expect.equal(Tally.count(tally, {}, state).p1, nil, "already counted")
	GameFixtures.own(state, "p2", 3)
	GameFixtures.own(state, "p2", 1)
	Expect.equal(Tally.count(tally, {}, state).p2.monopolies, 1, "another player's set counts for them")
end

return tests
