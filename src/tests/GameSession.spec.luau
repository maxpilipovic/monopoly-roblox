--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameSession = require(ServerScriptService.Server.Game.GameSession)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

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
			local action = if session.state.phase == "Auction" then { type = "PassBid" } else { type = "EndTurn" }
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

return tests
