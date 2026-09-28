--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local BUY = { type = "Buy" }
local END_TURN = { type = "EndTurn" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function money(state, id: string): number
	return (Engine.getPlayer(state, id) :: any).money
end

tests["new game gives each player 1500 at Go and the first player rolls"] = function()
	local state = GameFixtures.newGame(3)
	for _, player in state.players do
		Expect.equal(player.money, 1500, `{player.id} money`)
		Expect.equal(player.position, 0, `{player.id} position`)
	end
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
	Expect.equal(GameFixtures.eventsOfType(state, "TurnStarted")[1].player, "p1")
end

tests["new game requires 2 to 6 players with unique ids"] = function()
	local dice = GameFixtures.scriptedDice({})
	local function infos(count: number)
		local list = {}
		for i = 1, count do
			table.insert(list, { id = `p{i}`, name = `P{i}`, isBot = false })
		end
		return list
	end
	assert(not pcall(Engine.new, infos(1), dice), "1 player accepted")
	assert(not pcall(Engine.new, infos(7), dice), "7 players accepted")
	assert(pcall(Engine.new, infos(6), dice), "6 players rejected")
	local duplicate = infos(2)
	duplicate[2].id = "p1"
	assert(not pcall(Engine.new, duplicate, dice), "duplicate ids accepted")
end

tests["rolling moves the current player by the dice total"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", ROLL)
	Expect.equal(Engine.getPlayer(state, "p1").position, 6)
	local rolled = GameFixtures.eventsOfType(state, "Rolled")[1]
	Expect.equal(rolled.dice[1] + rolled.dice[2], 6, "rolled event")
	local moved = GameFixtures.eventsOfType(state, "Moved")[1]
	Expect.equal(moved.from, 0, "moved from")
	Expect.equal(moved.to, 6, "moved to")
end

tests["only the current player can roll, and only in the Roll phase"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	assert(not Engine.act(state, "p2", ROLL), "p2 rolled on p1's turn")
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "BuyDecision")
	assert(not Engine.act(state, "p1", ROLL), "rolled during BuyDecision")
end

tests["passing Go collects 200"] = function()
	local state = GameFixtures.newGame(2, { { 3, 2 } })
	Engine.getPlayer(state, "p1").position = 38
	act(state, "p1", ROLL)
	Expect.equal(Engine.getPlayer(state, "p1").position, 3)
	Expect.equal(money(state, "p1"), 1700)
	assert(GameFixtures.eventsOfType(state, "Moved")[1].passedGo, "passedGo flag")
end

tests["landing exactly on Go collects 200 once"] = function()
	local state = GameFixtures.newGame(2, { { 2, 3 } })
	Engine.getPlayer(state, "p1").position = 35
	act(state, "p1", ROLL)
	Expect.equal(Engine.getPlayer(state, "p1").position, 0)
	Expect.equal(money(state, "p1"), 1700)
end

tests["buying an unowned property"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", ROLL)
	Expect.equal(GameFixtures.eventsOfType(state, "OfferedPurchase")[1].position, 6, "offer")
	act(state, "p1", BUY)
	Expect.equal(money(state, "p1"), 1400)
	Expect.equal(state.properties[6].owner, "p1")
	Expect.equal(state.phase, "EndTurn")
end

tests["cannot buy without enough money"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.getPlayer(state, "p1").money = 50
	act(state, "p1", ROLL)
	local ok, err = Engine.act(state, "p1", BUY)
	assert(not ok, "bought without money")
	Expect.equal(err, "not enough money")
	Expect.equal(state.phase, "BuyDecision")
	Expect.equal(state.properties[6], nil, "ownership")
end

tests["landing on another player's property pays rent"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1494)
	Expect.equal(money(state, "p2"), 1506)
	Expect.equal(state.phase, "EndTurn")
end

tests["landing on your own property costs nothing"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p1", 6)
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500)
	Expect.equal(state.phase, "EndTurn")
end

tests["utility rent uses the dice just rolled"] = function()
	local state = GameFixtures.newGame(2, { { 5, 7 } }) -- 12 -> Electric Company
	GameFixtures.own(state, "p2", 12)
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500 - 48)
end

tests["rent is paid even if it leaves the player in debt"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	Engine.getPlayer(state, "p1").money = 3
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), -3)
	Expect.equal(money(state, "p2"), 1506)
end

tests["tax tiles charge their amount"] = function()
	local state = GameFixtures.newGame(2, { { 1, 3 } })
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1300)
	Expect.equal(state.phase, "EndTurn")
end

tests["other tiles just end the move"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } }) -- 7 -> Chance
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500)
	Expect.equal(state.phase, "EndTurn")
end

tests["doubles give the same player another roll"] = function()
	local state = GameFixtures.newGame(2, { { 1, 1 } }) -- 2 -> Community Chest
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
end

tests["end turn passes to the next player and wraps around"] = function()
	local state = GameFixtures.newGame(3, { { 3, 4 }, { 3, 4 }, { 3, 4 } })
	for _, id in { "p1", "p2", "p3" } do
		Expect.equal(Engine.currentPlayer(state).id, id, "current")
		act(state, id, ROLL)
		act(state, id, END_TURN)
	end
	Expect.equal(Engine.currentPlayer(state).id, "p1", "wrapped")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#GameFixtures.eventsOfType(state, "TurnStarted"), 4, "TurnStarted events")
end

tests["end turn skips bankrupt players"] = function()
	local state = GameFixtures.newGame(3, { { 3, 4 } })
	Engine.getPlayer(state, "p2").bankrupt = true
	act(state, "p1", ROLL)
	act(state, "p1", END_TURN)
	Expect.equal(Engine.currentPlayer(state).id, "p3")
end

tests["rejects malformed actions without changing state"] = function()
	local state = GameFixtures.newGame(2, {})
	assert(not Engine.act(state, "p1", nil :: any), "accepted nil")
	for _, bad in { 5, {}, { type = 5 }, { type = "Fly" } } :: { any } do
		assert(not Engine.act(state, "p1", bad), `accepted {tostring(bad)}`)
	end
	assert(not Engine.act(state, "nobody", ROLL), "unknown player accepted")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#state.events, 1, "only the TurnStarted event")
end

tests["acting player is the current player, or the bidder during an auction"] = function()
	local state = GameFixtures.newGame(3, { { 2, 4 } })
	Expect.equal(Engine.actingPlayer(state), "p1", "roll phase")
	act(state, "p1", ROLL)
	act(state, "p1", { type = "Decline" })
	act(state, "p1", { type = "PassBid" })
	Expect.equal(Engine.actingPlayer(state), "p2", "auction")
	state.phase = "GameOver"
	Expect.equal(Engine.actingPlayer(state), nil, "game over")
end

return tests
