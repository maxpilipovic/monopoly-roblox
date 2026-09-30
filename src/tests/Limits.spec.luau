--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- Ends the current player's turn straight away (these tests don't need the roll).
local function pass(state)
	state.phase = "EndTurn"
	act(state, Engine.currentPlayer(state).id, { type = "EndTurn" })
end

tests["new games start in round 1 and take a round limit"] = function()
	local infos = { { id = "a", name = "A", isBot = false }, { id = "b", name = "B", isBot = false } }
	local state = Engine.new(infos, GameFixtures.scriptedDice({}), nil, 25)
	Expect.equal(state.round, 1, "round")
	Expect.equal(state.roundLimit, 25, "limit")
	Expect.equal(state.timeUp, false, "time")
	Expect.equal(Engine.new(infos, GameFixtures.scriptedDice({})).roundLimit, nil, "no limit by default")
end

tests["rounds count up when play wraps back to the first seat"] = function()
	local state = GameFixtures.newGame(3)
	pass(state)
	pass(state)
	Expect.equal(state.round, 1, "p3's turn is still round 1")
	pass(state)
	Expect.equal(state.round, 2, "back to p1")
end

tests["a wrap past bankrupt seats still counts one round"] = function()
	local state = GameFixtures.newGame(3)
	player(state, "p1").bankrupt = true
	state.currentIndex = 2
	pass(state) -- p2 -> p3
	Expect.equal(state.round, 1)
	pass(state) -- p3 -> (p1 skipped) -> p2
	Expect.equal(Engine.currentPlayer(state).id, "p2")
	Expect.equal(state.round, 2)
end

tests["the round limit ends the game after the last turn of the last round"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 2
	GameFixtures.own(state, "p2", 39)
	pass(state) -- p1 -> p2
	pass(state) -- round 2
	pass(state) -- p1 -> p2
	Expect.equal(state.phase, "Roll", "p2 still plays round 2")
	pass(state)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p2", "Boardwalk makes p2 richer")
	Expect.equal(state.winReason, "RoundLimit")
	Expect.equal(GameFixtures.eventsOfType(state, "GameOver")[1].reason, "RoundLimit", "event")
	Expect.equal(#GameFixtures.eventsOfType(state, "TurnStarted"), 4, "no turn starts after the limit")
end

tests["at a limit, ties go to the earlier seat and bankrupt players can't win"] = function()
	local state = GameFixtures.newGame(3)
	player(state, "p1").bankrupt = true
	player(state, "p1").money = 5000
	state.currentIndex = 2
	Engine.markTimeUp(state)
	pass(state)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p2", "p2 and p3 tie on $1500")
	Expect.equal(state.winReason, "TimeLimit")
end

tests["time running out lets the current turn finish, doubles included"] = function()
	local state = GameFixtures.newGame(2, { { 5, 5 }, { 2, 1 } })
	Engine.markTimeUp(state)
	act(state, "p1", { type = "Roll" }) -- doubles: just visiting jail
	Expect.equal(state.phase, "Roll", "doubles roll again")
	act(state, "p1", { type = "Roll" }) -- States Avenue
	act(state, "p1", { type = "Buy" })
	Expect.equal(state.phase, "EndTurn", "still p1's turn")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p1", "$1360 + States Avenue $140 ties p2's $1500; earlier seat wins")
end

tests["time running out waits for a debt and an open trade"] = function()
	local state = GameFixtures.newGame(2)
	state.phase = "EndTurn"
	GameFixtures.inDebt(state, "p1", 100)
	Engine.markTimeUp(state)
	act(state, "p1", { type = "PayDebt" })
	Expect.equal(state.phase, "EndTurn", "back to p1's turn")
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 10), GameFixtures.side()))
	act(state, "p2", { type = "DeclineTrade" })
	Expect.equal(state.phase, "EndTurn", "the offer was answered")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winReason, "TimeLimit")
end

tests["a bankruptcy ending says so"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 5000)
	act(state, "p1", { type = "Bankrupt" })
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winReason, "Bankruptcy")
	Expect.equal(GameFixtures.eventsOfType(state, "GameOver")[1].reason, "Bankruptcy", "event")
end

tests["marking time up after the game is over changes nothing"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 1
	pass(state)
	pass(state)
	Expect.equal(state.phase, "GameOver")
	Engine.markTimeUp(state)
	Expect.equal(state.timeUp, false)
	Expect.equal(state.winReason, "RoundLimit")
end

tests["time running out waits for an auction to finish"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	Engine.markTimeUp(state)
	act(state, "p1", { type = "PassBid" })
	act(state, "p2", { type = "PassBid" })
	Expect.equal(state.phase, "EndTurn", "the auction ended, the turn goes on")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(state.phase, "GameOver")
end

return tests
