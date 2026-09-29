--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local END_TURN = { type = "EndTurn" }
local PAY_FINE = { type = "PayJailFine" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- A 2-player game where p1 starts their turn in jail.
local function jailed(rolls: { { number } })
	local state = GameFixtures.newGame(2, rolls)
	local p1 = player(state, "p1")
	p1.position = Engine.JAIL_POSITION
	p1.inJail = true
	return state
end

tests["landing on Go To Jail sends you to jail without passing Go and ends the turn"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 } })
	player(state, "p1").position = 24 -- 24 + 6 = 30, Go To Jail
	act(state, "p1", ROLL)
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 10, "position")
	assert(p1.inJail, "not in jail")
	Expect.equal(p1.money, 1500, "no Go salary")
	Expect.equal(state.phase, "EndTurn", "doubles give no extra roll")
	local moves = GameFixtures.eventsOfType(state, "Moved")
	Expect.equal(moves[1].style, "Walk", "dice move style")
	Expect.equal(moves[2].style, "ToJail", "jail move style")
	Expect.equal(moves[2].from, 30, "jail move from")
	Expect.equal(moves[2].passedGo, false, "jail move passedGo")
	Expect.equal(GameFixtures.eventsOfType(state, "SentToJail")[1].reason, "GoToJail")
end

tests["landing on Jail from a roll is just visiting"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	player(state, "p1").position = 3
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").position, 10)
	assert(not player(state, "p1").inJail, "jailed while visiting")
	Expect.equal(state.phase, "EndTurn")
end

tests["three doubles in one turn send you to jail without moving the third time"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 }, { 1, 1 }, { 2, 2 } })
	GameFixtures.own(state, "p1", 6)
	GameFixtures.own(state, "p1", 8)
	act(state, "p1", ROLL) -- 6
	act(state, "p1", ROLL) -- 8
	act(state, "p1", ROLL) -- third doubles: jail instead of 12
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 10, "position")
	assert(p1.inJail, "not in jail")
	Expect.equal(state.phase, "EndTurn")
	local moves = GameFixtures.eventsOfType(state, "Moved")
	Expect.equal(#moves, 3, "two walks and the jail move")
	Expect.equal(moves[3].from, 8, "jailed from where they stood")
	Expect.equal(GameFixtures.eventsOfType(state, "SentToJail")[1].reason, "Doubles")
end

tests["the doubles count starts over each turn"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 }, { 1, 1 }, { 1, 2 }, { 1, 2 }, { 2, 2 } })
	for _, position in { 3, 6, 8, 11, 15 } do
		GameFixtures.own(state, "p1", position)
	end
	act(state, "p1", ROLL) -- 6, doubles
	act(state, "p1", ROLL) -- 8, doubles
	act(state, "p1", ROLL) -- 11
	act(state, "p1", END_TURN)
	act(state, "p2", ROLL) -- 3, pays rent
	act(state, "p2", END_TURN)
	act(state, "p1", ROLL) -- 15, doubles: only the first this turn
	assert(not player(state, "p1").inJail, "jailed for doubles from an earlier turn")
	Expect.equal(state.phase, "Roll")
end

tests["rolling doubles in jail frees you and moves you, with no extra roll"] = function()
	local state = jailed({ { 3, 3 } })
	GameFixtures.own(state, "p1", 16)
	act(state, "p1", ROLL)
	local p1 = player(state, "p1")
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.position, 16, "moved by the roll")
	Expect.equal(state.phase, "EndTurn", "no extra roll")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Doubles")
end

tests["a failed roll keeps you in jail and ends the turn"] = function()
	local state = jailed({ { 1, 2 } })
	act(state, "p1", ROLL)
	local p1 = player(state, "p1")
	assert(p1.inJail, "left jail without doubles")
	Expect.equal(p1.position, 10, "did not move")
	Expect.equal(p1.jailAttempts, 1, "attempts")
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(#GameFixtures.eventsOfType(state, "Moved"), 0, "no move")
end

tests["the third failed roll forces the fine and moves you"] = function()
	local state = jailed({ { 1, 2 } })
	GameFixtures.own(state, "p1", 13)
	local p1 = player(state, "p1")
	p1.jailAttempts = 2
	p1.money = 20
	act(state, "p1", ROLL)
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.money, 20, "fine owed, not taken")
	Expect.equal(p1.position, 13, "moved by the roll")
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.debts[1].reason, "JailFine", "debt reason")
	Expect.equal(state.debts[1].amount, 50, "debt amount")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Fine")
end

tests["paying the fine frees you, then you roll normally"] = function()
	local state = jailed({ { 1, 2 } })
	GameFixtures.own(state, "p1", 13)
	act(state, "p1", PAY_FINE)
	local p1 = player(state, "p1")
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.money, 1450, "fine paid")
	Expect.equal(state.phase, "Roll", "still has to roll")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Fine")
	act(state, "p1", ROLL)
	Expect.equal(p1.position, 13, "moved")
end

tests["can't pay the fine without $50"] = function()
	local state = jailed({})
	player(state, "p1").money = 40
	local ok, err = Engine.act(state, "p1", PAY_FINE)
	assert(not ok, "paid without the money")
	Expect.equal(err, "not enough money")
	assert(player(state, "p1").inJail, "left jail")
	Expect.equal(player(state, "p1").money, 40, "money unchanged")
end

tests["paying the fine is refused outside jail or after rolling"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	assert(not Engine.act(state, "p1", PAY_FINE), "paid while free")
	state = jailed({ { 1, 2 } })
	act(state, "p1", ROLL)
	assert(not Engine.act(state, "p1", PAY_FINE), "paid after rolling")
	Expect.equal(player(state, "p1").money, 1500, "money unchanged")
end

tests["a jailed player still collects rent"] = function()
	local state = jailed({ { 1, 2 }, { 2, 4 } })
	GameFixtures.own(state, "p1", 6)
	act(state, "p1", ROLL) -- no doubles, stays in jail
	act(state, "p1", END_TURN)
	act(state, "p2", ROLL) -- 6, p1's property
	local p1 = player(state, "p1")
	assert(p1.inJail, "p1 left jail")
	Expect.equal(p1.money, 1506, "rent while in jail")
end

return tests
