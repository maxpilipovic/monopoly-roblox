--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local EventText = require(StarterPlayer.StarterPlayerScripts.Client.Hud.EventText)
local Expect = require(script.Parent.Expect)

local tests = {}

local NAMES = { p1 = "Ana", p2 = "Bot 1" }

tests["describes the events players care about"] = function()
	local cases = {
		{ { type = "TurnStarted", player = "p1" }, "Ana's turn" },
		{ { type = "Rolled", player = "p1", dice = { 3, 4 } }, "Ana rolled 3 + 4" },
		{ { type = "Paid", from = nil, to = "p1", amount = 200, reason = "Go" }, "Ana collected $200 for passing Go" },
		{ { type = "Paid", from = "p1", to = "p2", amount = 6, reason = "Rent" }, "Ana paid $6 rent to Bot 1" },
		{ { type = "Paid", from = "p1", to = nil, amount = 200, reason = "Tax" }, "Ana paid $200 tax" },
		{ { type = "Bought", player = "p1", position = 6, price = 100 }, "Ana bought Oriental Avenue for $100" },
		{ { type = "AuctionStarted", position = 6, bidders = { "p1", "p2" } }, "Auction for Oriental Avenue" },
		{ { type = "BidPlaced", player = "p2", amount = 30 }, "Bot 1 bid $30" },
		{ { type = "BidPassed", player = "p2" }, "Bot 1 passed" },
		{ { type = "AuctionEnded", position = 6, winner = "p2", amount = 30 }, "Bot 1 won Oriental Avenue for $30" },
		{ { type = "AuctionEnded", position = 6, winner = nil, amount = 0 }, "Nobody bought Oriental Avenue" },
		{ { type = "PlayerReplaced", player = "p1" }, "Ana left; a bot takes over" },
		{ { type = "TradeProposed", from = "p1", to = "p2", give = { properties = {}, cash = 100, jailCards = 0 }, get = { properties = { 39 }, cash = 0, jailCards = 0 } }, "Ana offered Bot 1 $100 for Boardwalk" },
		{ { type = "TradeProposed", from = "p1", to = "p2", give = { properties = { 37, 5 }, cash = 50, jailCards = 2 }, get = { properties = {}, cash = 0, jailCards = 0 } }, "Ana offered Bot 1 Park Place + Reading Railroad + $50 + 2 jail cards for nothing" },
		{ { type = "TradeProposed", from = "p1", to = "p2", give = { properties = {}, cash = 0, jailCards = 1 }, get = { properties = {}, cash = 20, jailCards = 0 } }, "Ana offered Bot 1 1 jail card for $20" },
		{ { type = "TradeAccepted", from = "p1", to = "p2" }, "Bot 1 accepted the trade" },
		{ { type = "TradeDeclined", from = "p1", to = "p2" }, "Bot 1 declined the trade" },
		{ { type = "SentToJail", player = "p1", reason = "GoToJail" }, "Ana went to jail" },
		{ { type = "SentToJail", player = "p1", reason = "Card" }, "Ana went to jail" },
		{ { type = "SentToJail", player = "p1", reason = "Doubles" }, "Ana rolled doubles three times and went to jail" },
		{ { type = "LeftJail", player = "p1", reason = "Doubles" }, "Ana rolled doubles and got out of jail" },
		{ { type = "LeftJail", player = "p1", reason = "Fine" }, "Ana paid $50 and got out of jail" },
		{ { type = "LeftJail", player = "p1", reason = "Card" }, "Ana used a Get Out of Jail Free card" },
		{ { type = "LeftJail", player = "p1", reason = "FineOwed" }, "Ana left jail owing the $50 fine" },
		{
			{ type = "CardDrawn", player = "p1", deck = "CommunityChest", card = "chest.doctor" },
			"Ana drew Community Chest: Doctor's fee. Pay $50.",
		},
		{ { type = "Paid", from = "p1", to = "p2", amount = 50, reason = "Card" }, "Ana paid $50 to Bot 1" },
		{ { type = "Built", player = "p1", position = 1, amount = 50, hotel = false }, "Ana built a house on Mediterranean Avenue" },
		{ { type = "Built", player = "p1", position = 1, amount = 50, hotel = true }, "Ana built a hotel on Mediterranean Avenue" },
		{ { type = "BuildingSold", player = "p1", position = 3, amount = 25, hotel = false }, "Ana sold a house on Baltic Avenue" },
		{ { type = "BuildingSold", player = "p1", position = 3, amount = 25, hotel = true }, "Ana sold a hotel on Baltic Avenue" },
		{ { type = "Mortgaged", player = "p1", position = 5, amount = 100 }, "Ana mortgaged Reading Railroad for $100" },
		{ { type = "Unmortgaged", player = "p1", position = 5, amount = 110 }, "Ana paid $110 to unmortgage Reading Railroad" },
		{ { type = "DebtOwed", debtor = "p1", creditor = "p2", amount = 340, reason = "Rent" }, "Ana owes Bot 1 $340 in rent" },
		{ { type = "DebtOwed", debtor = "p1", creditor = nil, amount = 200, reason = "Tax" }, "Ana owes the bank $200 in tax" },
		{ { type = "DebtOwed", debtor = "p1", creditor = nil, amount = 50, reason = "JailFine" }, "Ana owes the bank $50 for the jail fine" },
		{ { type = "DebtOwed", debtor = "p1", creditor = "p2", amount = 50, reason = "Card" }, "Ana owes Bot 1 $50 for a card" },
		{ { type = "DebtOwed", debtor = "p2", creditor = nil, amount = 10, reason = "MortgageInterest" }, "Bot 1 owes the bank $10 in mortgage interest" },
		{ { type = "WentBankrupt", player = "p1", creditor = "p2" }, "Ana went bankrupt to Bot 1" },
		{ { type = "WentBankrupt", player = "p1", creditor = nil }, "Ana went bankrupt to the bank" },
		{ { type = "GameOver", winner = "p2" }, "Bot 1 wins!" },
	}
	for _, case in cases :: { any } do
		Expect.equal(EventText.describe(case[1], NAMES), case[2], case[1].type)
	end
end

tests["skips events that have no log line"] = function()
	for _, event in {
		{ type = "Moved", player = "p1", from = 0, to = 6, passedGo = false },
		{ type = "OfferedPurchase", player = "p1", position = 6 },
		{ type = "Paid", from = "p1", to = nil, amount = 100, reason = "Purchase" },
		{ type = "Paid", from = "p1", to = nil, amount = 30, reason = "Auction" },
		{ type = "Paid", from = "p1", to = nil, amount = 50, reason = "JailFine" },
		{ type = "Paid", from = nil, to = "p1", amount = 50, reason = "Card" },
		{ type = "CardDrawn", player = "p1", deck = "Chance", card = "no.such.card" },
		{ type = "Paid", from = "p1", to = nil, amount = 50, reason = "Building" },
		{ type = "Paid", from = nil, to = "p1", amount = 100, reason = "Mortgage" },
		{ type = "DebtPaid", debtor = "p1", creditor = "p2", amount = 6, reason = "Rent" },
		{ type = "Paid", from = "p1", to = "p2", amount = 53, reason = "Bankruptcy" },
		{ type = "Paid", from = "p2", to = nil, amount = 10, reason = "MortgageInterest" },
		{ type = "Mystery" },
	} :: { any } do
		Expect.equal(EventText.describe(event, NAMES), nil, event.type)
	end
end

tests["unknown player ids fall back to the id"] = function()
	Expect.equal(EventText.describe({ type = "TurnStarted", player = "ghost" }, NAMES), "ghost's turn")
end

return tests
