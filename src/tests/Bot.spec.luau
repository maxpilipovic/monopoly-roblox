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

tests["two bots eventually build"] = function()
	local random = Random.new(99)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	for step = 1, 4000 do
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
		if #GameFixtures.eventsOfType(state, "Built") > 0 then
			return
		end
	end
	error("no bot built anything in 4000 steps")
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
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
	end
	for _, eventType in { "SentToJail", "LeftJail", "CardDrawn" } do
		assert(#GameFixtures.eventsOfType(state, eventType) > 0, `no {eventType} in 2000 steps`)
	end
end

return tests
