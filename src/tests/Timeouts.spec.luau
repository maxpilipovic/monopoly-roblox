--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Timeouts = require(ServerScriptService.Server.Game.Timeouts)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function default(state, playerId: string): string?
	local action = Timeouts.defaultAction(state, playerId)
	return if action then action.type else nil
end

tests["the default move in each phase is the safe one"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Expect.equal(default(state, "p1"), "Roll", "roll")
	Expect.equal(default(state, "p2"), nil, "not the acting player")
	act(state, "p1", { type = "Roll" }) -- Oriental Avenue
	Expect.equal(default(state, "p1"), "Decline", "don't buy")
	act(state, "p1", { type = "Decline" })
	Expect.equal(default(state, "p1"), "PassBid", "auction")
	act(state, "p1", { type = "PassBid" })
	act(state, "p2", { type = "PassBid" })
	Expect.equal(default(state, "p1"), "EndTurn", "end turn")
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 10), GameFixtures.side()))
	Expect.equal(default(state, "p2"), "DeclineTrade", "trade")

	local jailed = GameFixtures.newGame(2)
	local p1: any = Engine.getPlayer(jailed, "p1")
	p1.inJail = true
	Expect.equal(default(jailed, "p1"), "Roll", "in jail: try for doubles")

	jailed.phase = "GameOver"
	Expect.equal(default(jailed, "p1"), nil, "nothing after the game")
end

tests["in debt the default pays, else sells, else mortgages, else goes bankrupt"] = function()
	local state = GameFixtures.newGame(2)
	local p1: any = Engine.getPlayer(state, "p1")
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3, 1)
	p1.money = 0
	GameFixtures.inDebt(state, "p1", 80)

	local sell = Timeouts.defaultAction(state, "p1") :: any
	Expect.equal(sell.type, "SellBuilding", "sell first")
	Expect.equal(sell.position, 3, "the built lot")
	act(state, "p1", sell)

	local mortgage = Timeouts.defaultAction(state, "p1") :: any
	Expect.equal(mortgage.type, "Mortgage", "then mortgage")
	act(state, "p1", mortgage) -- $55, still short of $80
	act(state, "p1", Timeouts.defaultAction(state, "p1") :: any) -- the other brown lot
	Expect.equal(p1.money, 25 + 30 + 30, "house sold for $25, two lots mortgaged for $30 each")
	Expect.equal(default(state, "p1"), "PayDebt", "now it can pay")

	local broke = GameFixtures.newGame(2)
	local b1: any = Engine.getPlayer(broke, "p1")
	b1.money = 0
	GameFixtures.inDebt(broke, "p1", 50)
	Expect.equal(default(broke, "p1"), "Bankrupt", "nothing left to raise")
end

return tests
