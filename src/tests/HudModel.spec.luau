--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local HudModel = require(StarterPlayer.StarterPlayerScripts.Client.Hud.HudModel)
local ColorGroups = require(game:GetService("ReplicatedStorage").Shared.Board.ColorGroups)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function labels(buttons): string
	local list = {}
	for _, button in buttons do
		table.insert(list, button.label)
	end
	return table.concat(list, "|")
end

tests["no buttons when it is someone else's move"] = function()
	local snapshot = Snapshot.fromState(GameFixtures.newGame(2))
	Expect.equal(#HudModel.buttons(snapshot, "p2"), 0)
	Expect.equal(HudModel.status(snapshot, "p2"), "Waiting for Player 1")
end

tests["roll, buy, and end turn buttons follow the phase"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	local snapshot = Snapshot.fromState(state)
	Expect.equal(labels(HudModel.buttons(snapshot, "p1")), "Roll dice")
	Expect.equal(HudModel.buttons(snapshot, "p1")[1].action.type, "Roll")
	Expect.equal(HudModel.status(snapshot, "p1"), "Your turn")

	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(labels(HudModel.buttons(Snapshot.fromState(state), "p1")), "Buy for $100|Don't buy")

	Engine.act(state, "p1", { type = "Buy" })
	Expect.equal(labels(HudModel.buttons(Snapshot.fromState(state), "p1")), "End turn")
end

tests["buy is hidden when the player cannot afford it"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.getPlayer(state, "p1").money = 50
	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(labels(HudModel.buttons(Snapshot.fromState(state), "p1")), "Don't buy")
end

tests["auction offers affordable bid steps and pass to the bidder only"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	Engine.act(state, "p1", { type = "Bid", amount = 20 })
	Engine.getPlayer(state, "p2").money = 80
	local snapshot = Snapshot.fromState(state)
	local buttons = HudModel.buttons(snapshot, "p2")
	Expect.equal(labels(buttons), "Bid $30|Bid $70|Pass")
	Expect.equal(buttons[2].action.amount, 70)
	Expect.equal(#HudModel.buttons(snapshot, "p1"), 0, "p1 is not bidding now")
	Expect.equal(HudModel.status(snapshot, "p1"), "Auction: Oriental Avenue — high bid $20 (Player 1)")
end

tests["jail buttons follow what the player can do"] = function()
	Expect.equal(HudModel.JAIL_FINE, Engine.JAIL_FINE, "fine matches the engine")
	local state = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(state, "p1") :: any
	p1.inJail = true
	local snapshot = Snapshot.fromState(state)
	Expect.equal(labels(HudModel.buttons(snapshot, "p1")), "Try for doubles|Pay $50 fine")
	Expect.equal(HudModel.status(snapshot, "p1"), "Your turn — you're in jail")

	p1.jailCards = { "chance.jailFree" }
	p1.money = 40
	local buttons = HudModel.buttons(Snapshot.fromState(state), "p1")
	Expect.equal(labels(buttons), "Try for doubles|Use jail card", "broke, with a card")
	Expect.equal(buttons[1].action.type, "Roll")
	Expect.equal(buttons[2].action.type, "UseJailCard")
end

local function rowLabels(row): string
	return labels(row.buttons)
end

tests["property rows list your deeds: streets, then railroads, then utilities"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 12, 5, 3, 1 } do
		GameFixtures.own(state, "p1", position)
	end
	GameFixtures.own(state, "p2", 6)
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(#rows, 4, "only p1's deeds")
	local order = {}
	for _, row in rows do
		table.insert(order, `{row.position}:{row.group}`)
	end
	Expect.equal(table.concat(order, ","), "1:Brown,3:Brown,5:Railroad,12:Utility")
	Expect.equal(rows[1].name, "Mediterranean Avenue", "name")
end

tests["property rows offer the legal actions with prices on your turn"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "−🏠 +$25", "ahead: sell only")
	Expect.equal(rowLabels(rows[2]), "+🏠 $50", "behind: build only")
	Expect.equal(rowLabels(rows[3]), "Unmortgage $110", "mortgaged railroad")
	Expect.equal(rows[2].buttons[1].action.type, "Build", "action type")
	Expect.equal(rows[2].buttons[1].action.position, 3, "action position")

	state.properties[1].houses = 0
	rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "+🏠 $50|Mortgage +$30", "bare full set")
end

tests["property rows label hotels"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 4)
	GameFixtures.own(state, "p1", 3, 5)
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "+🏨 $50", "build the hotel")
	Expect.equal(rowLabels(rows[2]), "−🏨 +$25", "sell the hotel")
	Expect.equal(HudModel.buildingText(rows[2]), "🏨", "hotel text")
	Expect.equal(HudModel.buildingText(rows[1]), "🏠🏠🏠🏠", "houses text")
	state.bankHouses = 3
	rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[2]), "−🏨 +$50", "short bank: the refund covers the extra house sold")
end

tests["property rows have no buttons off your turn or mid-decision"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	state.properties[3].mortgaged = true
	Expect.equal(#HudModel.propertyRows(Snapshot.fromState(state), "p2"), 0, "p2 owns nothing")
	Engine.act(state, "p1", { type = "Roll" }) -- BuyDecision on Oriental
	for _, row in HudModel.propertyRows(Snapshot.fromState(state), "p1") do
		Expect.equal(#row.buttons, 0, `row {row.position} during a buy decision`)
	end
	Expect.equal(HudModel.buildingText(HudModel.propertyRows(Snapshot.fromState(state), "p1")[2]), "MORTGAGED")
	state.phase = "Roll"
	state.currentIndex = 2
	for _, row in HudModel.propertyRows(Snapshot.fromState(state), "p1") do
		Expect.equal(#row.buttons, 0, `row {row.position} on p2's turn`)
	end
end

tests["the properties toggle hides during auctions so the bid buttons fit"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	assert(HudModel.showsPropertiesToggle(Snapshot.fromState(state)), "roll phase")
	Engine.act(state, "p1", { type = "Roll" })
	assert(HudModel.showsPropertiesToggle(Snapshot.fromState(state)), "buy decision: you may want to check your deeds")
	Engine.act(state, "p1", { type = "Decline" })
	assert(not HudModel.showsPropertiesToggle(Snapshot.fromState(state)), "auction")
end

tests["a debtor is offered Pay when they can afford it, else a confirmed bankruptcy"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
	local snapshot = Snapshot.fromState(state)
	local buttons = HudModel.buttons(snapshot, "p1")
	Expect.equal(labels(buttons), "Pay $200")
	Expect.equal(buttons[1].action.type, "PayDebt")
	Expect.equal(buttons[1].confirm, nil, "no confirm to pay")
	Expect.equal(#HudModel.buttons(snapshot, "p2"), 0, "creditor waits")
	assert(HudModel.isDebtor(snapshot, "p1"), "p1 is the debtor")
	assert(not HudModel.isDebtor(snapshot, "p2"), "p2 is not")

	Engine.getPlayer(state, "p1").money = 120
	buttons = HudModel.buttons(Snapshot.fromState(state), "p1")
	Expect.equal(labels(buttons), "Go bankrupt")
	Expect.equal(buttons[1].action.type, "Bankrupt")
	Expect.equal(buttons[1].confirm, "Confirm bankruptcy?")
end

tests["debt status tells the debtor what they owe and everyone else who they wait on"] = function()
	local state = GameFixtures.newGame(2)
	Engine.getPlayer(state, "p1").money = 300
	GameFixtures.inDebt(state, "p1", 2000, "p2", "Rent")
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.status(snapshot, "p1"), "You owe Player 2 $2000. You have $300.")
	Expect.equal(HudModel.status(snapshot, "p2"), "Waiting for Player 1 to raise $2000…")
	state.debts[1].creditor = nil
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "You owe the bank $2000. You have $300.")
end

tests["in debt, property rows offer only selling and mortgaging, and only to the debtor"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	GameFixtures.own(state, "p2", 12)
	state.currentIndex = 2 -- a debt on someone else's turn
	GameFixtures.inDebt(state, "p1", 500, "p2")
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "−🏠 +$25", "sell, no build")
	Expect.equal(rowLabels(rows[2]), "", "Baltic: set has a house, can't mortgage or build")
	Expect.equal(rowLabels(rows[3]), "", "no unmortgage in debt")
	for _, row in HudModel.propertyRows(Snapshot.fromState(state), "p2") do
		Expect.equal(#row.buttons, 0, "the creditor can't act")
	end
end

tests["game over: the winner is announced and standings rank by net worth"] = function()
	local state = GameFixtures.newGame(3)
	Engine.getPlayer(state, "p1").bankrupt = true
	Engine.getPlayer(state, "p1").money = 0
	Engine.getPlayer(state, "p2").money = 900
	GameFixtures.own(state, "p3", 39) -- $1500 + $400
	state.phase = "GameOver"
	state.winner = "p3"
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.status(snapshot, "p1"), "Player 3 wins!")
	Expect.equal(#HudModel.buttons(snapshot, "p3"), 0, "no buttons")
	assert(not HudModel.showsPropertiesToggle(snapshot), "no properties toggle at game over")
	local order = {}
	for _, standing in HudModel.standings(snapshot) do
		table.insert(order, `{standing.name}:{standing.netWorth}:{standing.bankrupt}:{standing.winner}`)
	end
	Expect.equal(table.concat(order, ","), "Player 3:1900:false:true,Player 2:900:false:false,Player 1:0:true:false")
end

tests["names maps ids to display names"] = function()
	local names = HudModel.names(Snapshot.fromState(GameFixtures.newGame(2)))
	Expect.equal(names.p1, "Player 1")
	Expect.equal(names.p2, "Player 2")
end

tests["the Trade button shows only when you may propose"] = function()
	local state = GameFixtures.newGame(3, { { 2, 4 } })
	assert(HudModel.canTrade(Snapshot.fromState(state), "p1"), "your roll")
	assert(not HudModel.canTrade(Snapshot.fromState(state), "p2"), "someone else's turn")
	state.tradeOffers.p1 = Engine.MAX_TRADE_OFFERS
	assert(not HudModel.canTrade(Snapshot.fromState(state), "p1"), "no offers left")
	state.tradeOffers.p1 = nil
	Engine.getPlayer(state, "p2").bankrupt = true
	Engine.getPlayer(state, "p3").bankrupt = true
	assert(not HudModel.canTrade(Snapshot.fromState(state), "p1"), "nobody to trade with")
	Engine.getPlayer(state, "p2").bankrupt = false
	Engine.act(state, "p1", { type = "Roll" }) -- BuyDecision
	assert(not HudModel.canTrade(Snapshot.fromState(state), "p1"), "mid-decision")

	state = GameFixtures.newGame(2)
	state.currentIndex = 2
	GameFixtures.inDebt(state, "p1", 100)
	assert(HudModel.canTrade(Snapshot.fromState(state), "p1"), "the debtor may trade")
	assert(not HudModel.canTrade(Snapshot.fromState(state), "p2"), "the current player waits on the debt")
end

tests["the receiver sees the offer with Accept and Decline"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p2", 39)
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 100), GameFixtures.side({ 39 })))
	local snapshot = Snapshot.fromState(state)
	local buttons = HudModel.buttons(snapshot, "p2")
	Expect.equal(labels(buttons), "Accept|Decline")
	Expect.equal(buttons[1].action.type, "AcceptTrade")
	Expect.equal(buttons[2].action.type, "DeclineTrade")
	Expect.equal(#HudModel.buttons(snapshot, "p1"), 0, "proposer waits")
	Expect.equal(HudModel.status(snapshot, "p2"), "Player 1 offers you a trade")
	Expect.equal(HudModel.status(snapshot, "p3"), "Waiting for Player 2 to answer Player 1's offer")
	local summary = HudModel.tradeSummary(snapshot, "p2") :: any
	Expect.equal(summary.give, "Boardwalk", "receiver gives")
	Expect.equal(summary.get, "$100", "receiver gets")
	Expect.equal(HudModel.tradeSummary(snapshot, "p1"), nil, "only for the receiver")
	assert(not HudModel.canTrade(snapshot, "p1"), "no new offer while one is open")
end

tests["the receiver's summary marks mortgaged deeds"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side({ 5 }), GameFixtures.side(nil, 50)))
	local summary = HudModel.tradeSummary(Snapshot.fromState(state), "p2") :: any
	Expect.equal(summary.get, "Reading Railroad (mortgaged)", "receiver gets")
	Expect.equal(summary.give, "$50", "receiver gives")
end

local function snapshotWith(info)
	return Snapshot.fromState(GameFixtures.newGame(2), info)
end

tests["the countdown shows minutes and seconds and turns urgent in the last five"] = function()
	local snapshot = snapshotWith({ timer = "Fast", length = "Off", turnDeadline = 100 })
	local text, urgent = HudModel.countdown(snapshot, 58.5)
	Expect.equal(text, "0:42", "rounds up")
	Expect.equal(urgent, false)
	text, urgent = HudModel.countdown(snapshot, 95.2)
	Expect.equal(text, "0:05", "five left")
	Expect.equal(urgent, true)
	text, urgent = HudModel.countdown(snapshot, 130)
	Expect.equal(text, "0:00", "never below zero")
	Expect.equal(urgent, true)
	text = HudModel.countdown(snapshotWith({ timer = "Relaxed", length = "Off", turnDeadline = 100 }), 30)
	Expect.equal(text, "1:10", "over a minute")
	text, urgent = HudModel.countdown(snapshotWith({ timer = "Fast", length = "Off" }), 30)
	Expect.equal(text, nil, "no deadline")
	Expect.equal(urgent, false)
end

tests["the match line shows the timer and the limit"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 25
	state.round = 7
	Expect.equal(HudModel.matchLine(Snapshot.fromState(state, { timer = "Fast", length = "Rounds25" }), 0), "Fast · Round 7 of 25")
	state.round = 26 -- at GameOver after the last round
	Expect.equal(HudModel.matchLine(Snapshot.fromState(state, { timer = "Off", length = "Rounds25" }), 0), "Round 25 of 25", "clamped")

	local timed = snapshotWith({ timer = "Relaxed", length = "Minutes30", endsAt = 2000 })
	Expect.equal(HudModel.matchLine(timed, 2000 - 1390), "Relaxed · 23:10 left", "time left")
	Expect.equal(HudModel.matchLine(timed, 2001), "Relaxed · Final turn", "time's up")
	Expect.equal(HudModel.matchLine(snapshotWith({ timer = "Fast", length = "Off" }), 0), "Fast", "timer only")
	Expect.equal(HudModel.matchLine(snapshotWith({ timer = "Off", length = "Off" }), 0), nil, "nothing to show")
end

tests["the results title says how the game ended"] = function()
	local state = GameFixtures.newGame(2)
	state.phase = "GameOver"
	state.winner = "p2"
	state.winReason = "TimeLimit"
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "Time's up — Player 2 wins!")
	state.winReason = "RoundLimit"
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "Round limit reached — Player 2 wins!")
	state.winReason = "Bankruptcy"
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "Player 2 wins!")
end

tests["a player whose seat a bot took gets no buttons, rows or trade"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	local p1 = Engine.getPlayer(state, "p1") :: any
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.noPropertiesText(snapshot, "p2"), "You don't own any property yet", "a player")
	p1.isBot = true
	snapshot = Snapshot.fromState(state)
	Expect.equal(#HudModel.buttons(snapshot, "p1"), 0, "buttons")
	Expect.equal(#HudModel.propertyRows(snapshot, "p1"), 0, "rows")
	assert(not HudModel.canTrade(snapshot, "p1"), "trade")
	Expect.equal(HudModel.noPropertiesText(snapshot, "p1"), "You're not playing in this game", "bot seat")
	Expect.equal(HudModel.noPropertiesText(snapshot, "watcher"), "You're not playing in this game", "spectator")
end

tests["status tells you when it's your bid and when it's your last try in jail"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.status(snapshot, "p1"), "Auction: Oriental Avenue — no bids yet · your bid", "bidder")
	Expect.equal(HudModel.status(snapshot, "p2"), "Auction: Oriental Avenue — no bids yet", "waiting")

	local jailed = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(jailed, "p1") :: any
	p1.inJail = true
	p1.jailAttempts = 1
	Expect.equal(HudModel.status(Snapshot.fromState(jailed), "p1"), "Your turn — you're in jail", "second try")
	p1.jailAttempts = 2
	Expect.equal(HudModel.status(Snapshot.fromState(jailed), "p1"), "Your turn — last try in jail: miss and you pay $50", "third try")
	Expect.equal(HudModel.JAIL_MAX_ATTEMPTS, Engine.JAIL_MAX_ATTEMPTS, "mirrors the engine")
end

tests["the match line is gone once the game is over"] = function()
	local state = GameFixtures.newGame(2)
	state.phase = "GameOver"
	state.winner = "p1"
	Expect.equal(HudModel.matchLine(Snapshot.fromState(state, { timer = "Fast", length = "Minutes30", endsAt = 50 }), 0), nil)
end

tests["build buttons disappear when the bank is out of houses"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	state.bankHouses = 0
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "Mortgage +$30", "no +🏠")
end

tests["someone watching a bot-held seat is told what a spectator is told"] = function()
	local state = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(state, "p1") :: any
	p1.isBot = true
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.status(snapshot, "p1"), HudModel.status(snapshot, "watcher"), "not \"Your turn\"")
end

tests["player rows carry what the player list shows, in seat order"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p2", 1)
	GameFixtures.own(state, "p2", 3)
	GameFixtures.own(state, "p3", 5)
	state.players[2].inJail = true
	state.players[3].bankrupt = true
	local rows = HudModel.playerRows(Snapshot.fromState(state), "p2")
	Expect.equal(#rows, 3)
	Expect.equal(rows[1].id, "p1")
	Expect.equal(rows[1].seat, 1)
	Expect.equal(rows[1].isCurrent, true, "p1 is up")
	Expect.equal(rows[1].isYou, false)
	Expect.equal(rows[1].deeds, 0)
	Expect.equal(rows[2].isYou, true)
	Expect.equal(rows[2].isCurrent, false)
	Expect.equal(rows[2].inJail, true)
	Expect.equal(rows[2].deeds, 2)
	Expect.equal(rows[2].money, 1500)
	Expect.equal(rows[3].bankrupt, true)
	Expect.equal(rows[3].deeds, 1)
	for _, row in HudModel.playerRows(Snapshot.fromState(state), "watcher") do
		Expect.equal(row.isYou, false, "a spectator is nobody's row")
	end
end

tests["the deed in focus is the tile being bought or auctioned"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Expect.equal(HudModel.deedFocus(Snapshot.fromState(state)), nil, "rolling")
	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(HudModel.deedFocus(Snapshot.fromState(state)), 6, "buy decision: Oriental Avenue")
	Engine.act(state, "p1", { type = "Decline" })
	Expect.equal(HudModel.deedFocus(Snapshot.fromState(state)), 6, "auction")
	state.phase = "GameOver"
	state.auction = nil
	Expect.equal(HudModel.deedFocus(Snapshot.fromState(state)), nil, "game over")
end

local function sideText(side): string
	local chips = {}
	for _, chip in side.chips do
		table.insert(chips, chip.name .. (if chip.mortgaged then "*" else ""))
	end
	return `{side.title}: [{table.concat(chips, ",")}] ${side.cash} cards={side.jailCards}`
end

tests["an open offer reads from each viewer's side of the table"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p2", 39)
	GameFixtures.own(state, "p2", 5)
	state.properties[5].mortgaged = true
	Expect.equal(HudModel.tradeOffer(Snapshot.fromState(state), "p1"), nil, "no offer open")
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 100), GameFixtures.side({ 39, 5 })))
	local snapshot = Snapshot.fromState(state)

	local receiver = HudModel.tradeOffer(snapshot, "p2") :: HudModel.Offer
	Expect.equal(receiver.title, "Player 1 offers you a trade")
	Expect.equal(sideText(receiver.left), "You give: [Reading Railroad*,Boardwalk] $0 cards=0")
	Expect.equal(sideText(receiver.right), "You get: [] $100 cards=0")
	Expect.equal(receiver.left.chips[2].color, ColorGroups.DarkBlue.color, "chips carry their set colour")
	Expect.equal(receiver.left.chips[1].color, nil, "railroads have none")

	local proposer = HudModel.tradeOffer(snapshot, "p1") :: HudModel.Offer
	Expect.equal(proposer.title, "Your offer to Player 2")
	Expect.equal(sideText(proposer.left), "You give: [] $100 cards=0")
	Expect.equal(sideText(proposer.right), "You get: [Reading Railroad*,Boardwalk] $0 cards=0")

	local watcher = HudModel.tradeOffer(snapshot, "p3") :: HudModel.Offer
	Expect.equal(watcher.title, "Player 1 offers Player 2 a trade")
	Expect.equal(watcher.left.title, "Player 1 gives")
	Expect.equal(watcher.right.title, "Player 2 gives")
	Expect.equal(watcher.left.cash, 100)
end

tests["properties group into their sets with how much of each is owned"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 1, 6, 8, 9, 5, 15, 12 } do
		GameFixtures.own(state, "p1", position)
	end
	local groups = HudModel.propertyGroups(HudModel.propertyRows(Snapshot.fromState(state), "p1"))
	local summary = {}
	for _, group in groups do
		table.insert(summary, `{group.title} {group.owned}/{group.size} rows={#group.rows}`)
	end
	Expect.equal(
		table.concat(summary, " | "),
		"Brown 1/2 rows=1 | Light Blue 3/3 rows=3 | Railroads 2/4 rows=2 | Utilities 1/2 rows=1"
	)
	Expect.equal(groups[1].color, ColorGroups.Brown.color)
	Expect.equal(groups[3].color, nil)
	Expect.equal(groups[2].rows[1].name, "Oriental Avenue")
	Expect.equal(#HudModel.propertyGroups({}), 0)
end

tests["money deltas are the cash changes of players in both snapshots"] = function()
	local state = GameFixtures.newGame(3)
	local before = Snapshot.fromState(state)
	Engine.getPlayer(state, "p1").money = 1700
	Engine.getPlayer(state, "p2").money = 1450
	local after = Snapshot.fromState(state)
	local deltas = HudModel.moneyDeltas(before, after)
	Expect.equal(deltas.p1, 200)
	Expect.equal(deltas.p2, -50)
	Expect.equal(deltas.p3, nil, "no change, no entry")
	Expect.equal(next(HudModel.moneyDeltas(nil, after)), nil, "a new game shows nothing")
	table.remove(before.players, 1)
	Expect.equal(HudModel.moneyDeltas(before, after).p1, nil, "a player who wasn't there before")
end

tests["the turn banner is for the moment the turn becomes yours"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 }, { 1, 2 } })
	local start = Snapshot.fromState(state)
	Expect.equal(HudModel.becameMyTurn(nil, start, "p1"), true, "first turn of the game")
	Expect.equal(HudModel.becameMyTurn(nil, start, "p2"), false, "not theirs")
	Expect.equal(HudModel.becameMyTurn(start, start, "p1"), false, "already theirs")
	Expect.equal(HudModel.becameMyTurn(nil, start, "watcher"), false, "spectator")

	Engine.act(state, "p1", { type = "Roll" }) -- doubles onto Oriental Avenue
	local deciding = Snapshot.fromState(state)
	Expect.equal(HudModel.becameMyTurn(start, deciding, "p1"), false, "mid-turn")
	Engine.act(state, "p1", { type = "Buy" })
	local again = Snapshot.fromState(state)
	Expect.equal(again.phase, "Roll", "doubles: rolls again")
	Expect.equal(HudModel.becameMyTurn(deciding, again, "p1"), false, "doubles isn't a new turn")

	local other = table.clone(start)
	other.currentPlayer = "p2"
	Expect.equal(HudModel.becameMyTurn(other, start, "p1"), true, "after someone else")
end

tests["the timer fraction is the share of the decision time left"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Expect.equal(HudModel.timerFraction(Snapshot.fromState(state), 100), nil, "no timer")
	local info = { timer = "Fast", length = "Off", turnDeadline = 110 }
	Expect.near(HudModel.timerFraction(Snapshot.fromState(state, info), 100) :: number, 0.5, "10 of 20 s left")
	Expect.near(HudModel.timerFraction(Snapshot.fromState(state, info), 85) :: number, 1, "never above full")
	Expect.near(HudModel.timerFraction(Snapshot.fromState(state, info), 130) :: number, 0, "never below empty")
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	-- Fast is 20 s a turn; a bid gets a third of that, rounded up: 7 s.
	Expect.near(HudModel.timerFraction(Snapshot.fromState(state, info), 103) :: number, 1, "auction: 7 of 7 s left")
	Expect.near(HudModel.timerFraction(Snapshot.fromState(state, info), 106.5) :: number, 0.5, "auction: half")
end

return tests
