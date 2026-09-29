--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Bot = require(ServerScriptService.Server.Game.Bot)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

tests["bot rolls on its turn and does nothing on others' turns"] = function()
	local state = GameFixtures.newGame(2)
	Expect.equal(Bot.chooseAction(state, "p1").type, "Roll")
	Expect.equal(Bot.chooseAction(state, "p2"), nil)
end

tests["bot buys when it keeps its cash reserve, otherwise declines"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 }, { 2, 4 } }) -- Oriental Avenue, $100
	act(state, "p1", { type = "Roll" })
	Expect.equal(Bot.chooseAction(state, "p1").type, "Buy", "rich bot")

	state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.getPlayer(state, "p1").money = 200
	act(state, "p1", { type = "Roll" })
	Expect.equal(Bot.chooseAction(state, "p1").type, "Decline", "poor bot")
end

tests["bot bids in steps up to the price and then passes"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Bid")
	Expect.equal(action.amount, 10)
	state.auction.highBid = 95
	Expect.equal(Bot.chooseAction(state, "p1").type, "PassBid", "next bid would exceed price")
	state.auction.highBid = 20
	Engine.getPlayer(state, "p1").money = 170
	Expect.equal(Bot.chooseAction(state, "p1").type, "PassBid", "next bid would break the reserve")
end

tests["bot ends its turn"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	act(state, "p1", { type = "Roll" })
	Expect.equal(Bot.chooseAction(state, "p1").type, "EndTurn")
end

tests["a jailed bot uses its card, else pays if it can spare it, else rolls"] = function()
	local state = GameFixtures.newGame(2)
	local me = Engine.getPlayer(state, "p1") :: any
	me.inJail = true
	me.jailCards = { "chance.jailFree" }
	Expect.equal(Bot.chooseAction(state, "p1").type, "UseJailCard", "has a card")
	me.jailCards = {}
	Expect.equal(Bot.chooseAction(state, "p1").type, "PayJailFine", "rich")
	me.money = Bot.CASH_RESERVE + 49
	Expect.equal(Bot.chooseAction(state, "p1").type, "Roll", "poor")
end

tests["a bot with a full set builds evenly while it keeps its reserve"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Build", "builds")
	Expect.equal(action.position, 1, "lowest position first")
	act(state, "p1", action)
	Expect.equal(Bot.chooseAction(state, "p1").position, 3, "then evens out")
	Engine.getPlayer(state, "p1").money = Bot.CASH_RESERVE + 49
	Expect.equal(Bot.chooseAction(state, "p1").type, "Roll", "keeps the reserve")
end

tests["a bot builds its cheapest set first"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 37, 39, 1, 3 } do -- dark blue ($200 houses) and brown ($50)
		GameFixtures.own(state, "p1", position)
	end
	Expect.equal(Bot.chooseAction(state, "p1").position, 1)
end

tests["a rich bot lifts its cheapest mortgage before building"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3)
	GameFixtures.own(state, "p1", 5)
	GameFixtures.own(state, "p1", 12)
	state.properties[5].mortgaged = true -- costs 110
	state.properties[12].mortgaged = true -- costs 83
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Unmortgage", "unmortgages")
	Expect.equal(action.position, 12, "cheapest first")
	Engine.getPlayer(state, "p1").money = 3 * Bot.CASH_RESERVE + 82 -- 83 would leave 449
	Expect.equal(Bot.chooseAction(state, "p1").type, "Build", "not rich enough: builds instead")
end

tests["a bot in debt pays as soon as it can"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 100)
	Expect.equal(Bot.chooseAction(state, "p1").type, "PayDebt")
	Expect.equal(Bot.chooseAction(state, "p2"), nil, "not p2's move")
end

tests["a bot in debt sells its most expensive building first"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 1, 3, 37, 39 } do
		GameFixtures.own(state, "p1", position, 1)
	end
	Engine.getPlayer(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 100)
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "SellBuilding", "sells")
	Expect.equal(action.position, 39, "a $200 house before a $50 one")
end

tests["a bot in debt with no buildings mortgages its cheapest deed"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 5) -- mortgage value 100
	GameFixtures.own(state, "p1", 12) -- 75
	GameFixtures.own(state, "p1", 1) -- 30
	Engine.getPlayer(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 100)
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Mortgage")
	Expect.equal(action.position, 1)
end

tests["a bot sells hotels even in a house shortage, and goes bankrupt with nothing left"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 5)
	GameFixtures.own(state, "p1", 3, 5)
	state.bankHouses = 0
	Engine.getPlayer(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 100)
	Expect.equal(Bot.chooseAction(state, "p1").type, "SellBuilding", "hotels still sell")
	state.properties = {}
	Expect.equal(Bot.chooseAction(state, "p1").type, "Bankrupt", "owns nothing")
end

tests["two bots eventually build"] = function()
	local random = Random.new(99)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	for step = 1, 4000 do
		if state.phase == "GameOver" then
			break
		end
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
		if #GameFixtures.eventsOfType(state, "Built") > 0 then
			return
		end
	end
	error("no bot built anything before the game ended or 4000 steps")
end

tests["an all-bot game keeps making legal moves"] = function()
	local random = Random.new(1234)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
		{ id = "b3", name = "B3", isBot = true },
		{ id = "b4", name = "B4", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end, function(ids)
		for i = #ids, 2, -1 do
			local j = random:NextInteger(1, i)
			ids[i], ids[j] = ids[j], ids[i]
		end
	end)
	for step = 1, 2000 do
		if state.phase == "GameOver" then
			break
		end
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
	end
	for _, eventType in { "SentToJail", "LeftJail", "CardDrawn" } do
		assert(#GameFixtures.eventsOfType(state, eventType) > 0, `no {eventType} in 2000 steps`)
	end
end

tests["an all-bot game on short money ends with a winner"] = function()
	local random = Random.new(7)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
		{ id = "b3", name = "B3", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	for _, bot in state.players do
		bot.money = 300
	end
	for step = 1, 20000 do
		if state.phase == "GameOver" then
			break
		end
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
	end
	Expect.equal(state.phase, "GameOver", "game never ended")
	assert(state.winner, "no winner")
	Expect.equal(#GameFixtures.eventsOfType(state, "WentBankrupt"), 2, "two bots went out")
	for _, bot in state.players do
		assert(bot.money >= 0, `{bot.id} went negative`)
	end
end

local side = GameFixtures.side

-- p1 offers p2 (the bot) a trade; returns what the bot answers.
local function botAnswer(state, give, get): string
	local ok, err = GameFixtures.propose(state, "p1", "p2", give, get)
	assert(ok, `propose failed: {err}`)
	return Bot.chooseAction(state, "p2").type
end

tests["a bot accepts a trade worth 10% more to it"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", 12) -- Electric Company, $150
	Expect.equal(botAnswer(state, side(nil, 165), side({ 12 })), "AcceptTrade", "$165 for $150")
	Engine.act(state, "p2", { type = "AcceptTrade" })

	state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", 12)
	Expect.equal(botAnswer(state, side(nil, 160), side({ 12 })), "DeclineTrade", "$160 is short of 10%")
end

tests["a bot wants a premium for completing your set"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 37)
	GameFixtures.own(state, "p2", 39) -- Boardwalk completes p1's dark blues: counts $800
	Expect.equal(botAnswer(state, side(nil, 800), side({ 39 })), "DeclineTrade", "$800")
	Engine.act(state, "p2", { type = "DeclineTrade" })
	Expect.equal(botAnswer(state, side(nil, 880), side({ 39 })), "AcceptTrade", "$880")
end

tests["a bot values completing its own set"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", 37)
	GameFixtures.own(state, "p1", 39) -- Boardwalk completes the bot's set: counts $800
	Expect.equal(botAnswer(state, side({ 39 }), side(nil, 700)), "AcceptTrade")
end

tests["a bot keeps its cash reserve in trades"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 39)
	Engine.getPlayer(state, "p2").money = 400
	Expect.equal(botAnswer(state, side({ 39 }), side(nil, 300)), "DeclineTrade", "would leave $100")
end

tests["a bot counts mortgaged deeds at price minus the unmortgage cost"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 5) -- $200 - $110 = $90
	state.properties[5].mortgaged = true
	Expect.equal(botAnswer(state, side({ 5 }), side(nil, 82)), "DeclineTrade", "90 < 1.1 x 82")
	Engine.act(state, "p2", { type = "DeclineTrade" })
	Expect.equal(botAnswer(state, side({ 5 }), side(nil, 81)), "AcceptTrade", "90 >= 1.1 x 81")
end

tests["a bot accepts gifts"] = function()
	local state = GameFixtures.newGame(2)
	Expect.equal(botAnswer(state, side(nil, 10), side()), "AcceptTrade")
end

return tests
