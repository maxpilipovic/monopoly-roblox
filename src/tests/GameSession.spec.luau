--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameSession = require(ServerScriptService.Server.Game.GameSession)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)
local Maps = require(game:GetService("ReplicatedStorage").Shared.Board.Maps)
local MatchSettings = require(game:GetService("ReplicatedStorage").Shared.Rules.MatchSettings)

local tests = {}

local function humans(count: number)
	local list = {}
	for i = 1, count do
		table.insert(list, { id = `h{i}`, name = `Human {i}` })
	end
	return list
end

local function ids(session): string
	local list = {}
	for _, player in session.state.players do
		table.insert(list, player.id)
	end
	return table.concat(list, ",")
end

tests["humans take the first seats and bots fill the rest"] = function()
	local session = GameSession.new(humans(2), 4, GameFixtures.scriptedDice({}))
	Expect.equal(ids(session), "h1,h2,bot1,bot2")
	Expect.equal(session.state.players[3].name, "Bot 1")
	assert(session.state.players[3].isBot and not session.state.players[1].isBot, "isBot flags")
end

tests["seats are clamped to 2-6 and never fewer than the humans"] = function()
	local dice = GameFixtures.scriptedDice({})
	Expect.equal(#GameSession.new(humans(1), 1, dice).state.players, 2, "min 2")
	Expect.equal(#GameSession.new(humans(1), 9, dice).state.players, 6, "max 6")
	Expect.equal(#GameSession.new(humans(3), 2, dice).state.players, 3, "grows to humans")
	Expect.equal(#GameSession.new(humans(8), 4, dice).state.players, 6, "extra humans spectate")
	Expect.equal(#GameSession.new(humans(1), 0 / 0, dice).state.players, 2, "NaN seats")
end

tests["takeNewEvents returns each event once"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 3, 4 } }))
	Expect.equal(#GameSession.takeNewEvents(session), 1, "TurnStarted")
	Expect.equal(#GameSession.takeNewEvents(session), 0, "nothing new")
	assert(GameSession.act(session, "h1", { type = "Roll" }))
	local events = GameSession.takeNewEvents(session)
	Expect.equal(events[1].type, "Rolled")
end

tests["stepBot acts only for bots"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 3, 4 }, { 3, 4 } }))
	assert(not GameSession.stepBot(session), "acted for the human")
	assert(GameSession.act(session, "h1", { type = "Roll" }))
	assert(GameSession.act(session, "h1", { type = "EndTurn" }))
	assert(GameSession.stepBot(session), "bot did not roll")
	Expect.equal(Engine.getPlayer(session.state, "bot1").position, 7)
end

tests["bots play until a human must act"] = function()
	local random = Random.new(42)
	local session = GameSession.new(humans(1), 4, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	assert(GameSession.act(session, "h1", { type = "Roll" }))
	-- Whatever h1 landed on, settle it without buying so the bots take over.
	if session.state.phase == "BuyDecision" then
		assert(GameSession.act(session, "h1", { type = "Decline" }))
	end
	local guard = 0
	repeat
		if Engine.actingPlayer(session.state) == "h1" and session.state.phase ~= "Roll" then
			local phase = session.state.phase
			local action = if phase == "Auction"
				then { type = "PassBid" }
				elseif phase == "Debt" then { type = "PayDebt" }
				else { type = "EndTurn" }
			assert(GameSession.act(session, "h1", action))
		end
		guard += 1
	until not GameSession.stepBot(session) and Engine.actingPlayer(session.state) == "h1" and session.state.phase == "Roll"
		or guard > 500
	assert(guard <= 500, "bots never handed the turn back")
	Expect.equal(Engine.currentPlayer(session.state).id, "h1")
end

tests["a leaving player is replaced by a bot who then acts"] = function()
	local session = GameSession.new(humans(2), 2, GameFixtures.scriptedDice({ { 3, 4 } }))
	GameSession.replaceWithBot(session, "h1")
	local h1 = Engine.getPlayer(session.state, "h1") :: any
	assert(h1.isBot, "not a bot")
	Expect.equal(h1.name, "Human 1 (bot)")
	Expect.equal(GameFixtures.eventsOfType(session.state, "PlayerReplaced")[1].player, "h1")
	assert(GameSession.hasHumans(session), "h2 is still human")
	assert(GameSession.stepBot(session), "replacement bot did not act")
	GameSession.replaceWithBot(session, "h2")
	assert(not GameSession.hasHumans(session), "no humans left")
end

tests["a player who rejoins cannot act for the bot that took their seat"] = function()
	local session = GameSession.new(humans(2), 2, GameFixtures.scriptedDice({ { 3, 4 } }))
	GameSession.replaceWithBot(session, "h1")
	local ok, err = GameSession.act(session, "h1", { type = "Roll" })
	assert(not ok, "rejoined player rolled for the bot")
	Expect.equal(err, "a bot is playing this seat")
end

tests["a bot with no idea what to do still keeps the game moving"] = function()
	local Bot = require(ServerScriptService.Server.Game.Bot)
	local original = Bot.chooseAction
	Bot.chooseAction = function()
		return nil
	end
	local ok, err = pcall(function()
		local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 3, 4 }, { 3, 4 } }))
		assert(GameSession.act(session, "h1", { type = "Roll" }))
		assert(GameSession.act(session, "h1", { type = "EndTurn" }))
		assert(GameSession.stepBot(session), "bot did not roll")
		assert(GameSession.stepBot(session), "bot did not end its turn")
		Expect.equal(Engine.currentPlayer(session.state).id, "h1", "turn back to the human")
	end)
	Bot.chooseAction = original
	assert(ok, err)
end

tests["a bot with no plan in debt still settles it"] = function()
	local Bot = require(ServerScriptService.Server.Game.Bot)
	local original = Bot.chooseAction
	Bot.chooseAction = function()
		return nil
	end
	local ok, err = pcall(function()
		local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
		session.state.currentIndex = 2
		GameFixtures.inDebt(session.state, "bot1", 100)
		assert(GameSession.stepBot(session), "rich bot did not pay")
		Expect.equal(#session.state.debts, 0, "paid")
		GameFixtures.inDebt(session.state, "bot1", 5000)
		assert(GameSession.stepBot(session), "broke bot did not go bankrupt")
		assert(Engine.getPlayer(session.state, "bot1").bankrupt, "bot1 still in")
	end)
	Bot.chooseAction = original
	assert(ok, err)
end

tests["a bot with no plan still answers a trade"] = function()
	local Bot = require(ServerScriptService.Server.Game.Bot)
	local original = Bot.chooseAction
	Bot.chooseAction = function()
		return nil
	end
	local ok, err = pcall(function()
		local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
		assert(GameSession.act(session, "h1", {
			type = "ProposeTrade",
			offer = { to = "bot1", give = GameFixtures.side(nil, 10), get = GameFixtures.side() },
		}))
		assert(GameSession.stepBot(session), "bot did not answer")
		Expect.equal(session.state.phase, "Roll", "back to h1")
		Expect.equal(#GameFixtures.eventsOfType(session.state, "TradeDeclined"), 1, "declined")
	end)
	Bot.chooseAction = original
	assert(ok, err)
end

tests["a timeout plays one safe move outside a debt"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 2, 4 } }))
	assert(GameSession.timeout(session, "h1"), "roll")
	Expect.equal(session.state.phase, "BuyDecision", "rolled once, didn't buy yet")
	assert(GameSession.timeout(session, "h1"), "decline")
	Expect.equal(session.state.phase, "Auction")
	assert(not GameSession.timeout(session, "bot1"), "only the acting player times out")
end

tests["a timeout settles a whole debt in one go"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	local state = session.state
	GameFixtures.own(state, "h1", 1)
	GameFixtures.own(state, "h1", 3)
	local h1: any = Engine.getPlayer(state, "h1")
	h1.money = 0
	GameFixtures.inDebt(state, "h1", 50)
	assert(GameSession.timeout(session, "h1"))
	Expect.equal(state.properties[1].mortgaged, true, "Mediterranean")
	Expect.equal(state.properties[3].mortgaged, true, "Baltic")
	Expect.equal(h1.money, 10, "$60 raised, $50 paid")
	Expect.equal(state.phase, "Roll", "back to the turn")
end

tests["a timeout with nothing to raise goes bankrupt"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	local h1: any = Engine.getPlayer(session.state, "h1")
	h1.money = 0
	GameFixtures.inDebt(session.state, "h1", 50)
	assert(GameSession.timeout(session, "h1"))
	Expect.equal(h1.bankrupt, true)
	Expect.equal(session.state.phase, "GameOver", "the last human went bankrupt")
end

tests["sessions keep their settings and take the round limit from them"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}), nil, { timer = "Fast", length = "Rounds15" })
	Expect.equal(session.settings.timer, "Fast")
	Expect.equal(session.state.roundLimit, 15)
	Expect.equal(session.endsAt, nil)
	local plain = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	Expect.equal(plain.settings.timer, "Relaxed", "default settings")
	Expect.equal(plain.state.roundLimit, nil)
	GameSession.markTimeUp(plain)
	Expect.equal(plain.state.timeUp, true)
end

tests["a timeout never plays for a bot seat"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	session.state.currentIndex = 2 -- bot1's turn
	assert(not GameSession.timeout(session, "bot1"), "timed out a bot")
	Expect.equal(session.state.phase, "Roll", "nothing played")
end

tests["players who share a display name are told apart"] = function()
	local list = { { id = "h1", name = "Sam" }, { id = "h2", name = "Sam" }, { id = "h3", name = "Ana" }, { id = "h4", name = "Sam" } }
	local session = GameSession.new(list, 4, GameFixtures.scriptedDice({}))
	local names = {}
	for _, player in session.state.players do
		table.insert(names, player.name)
	end
	Expect.equal(table.concat(names, ","), "Sam,Sam (2),Ana,Sam (3)")
end

tests["isPlayer is true for anyone seated, even after they went bankrupt or left"] = function()
	local session = GameSession.new(humans(2), 3, GameFixtures.scriptedDice({}))
	assert(GameSession.isPlayer(session, "h1"), "seated")
	Engine.getPlayer(session.state, "h1").bankrupt = true
	assert(GameSession.isPlayer(session, "h1"), "bankrupt")
	GameSession.replaceWithBot(session, "h2")
	assert(GameSession.isPlayer(session, "h2"), "replaced by a bot")
	assert(not GameSession.isPlayer(session, "watcher"), "spectator")
end

tests["leaving after the game is over leaves the results as they were"] = function()
	local session = GameSession.new(humans(2), 2, GameFixtures.scriptedDice({}))
	session.state.phase = "GameOver"
	session.state.winner = "h1"
	local events = #session.state.events
	GameSession.replaceWithBot(session, "h1")
	local h1 = Engine.getPlayer(session.state, "h1") :: any
	Expect.equal(h1.name, "Human 1", "winner keeps their name")
	assert(not h1.isBot, "no bot takes a finished seat")
	Expect.equal(#session.state.events, events, "no PlayerReplaced line")
end

tests["the session starts the map from the settings"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}), nil, MatchSettings.validate({ map = "College" }))
	local map = session.state.map
	Maps.use("Classic")
	Expect.equal(map, "College")
end

return tests
