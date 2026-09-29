--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local TurnClock = require(ServerScriptService.Server.Game.TurnClock)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["a human's decision gets a deadline that resets on their move or a new decision"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.actor, "p1", "actor")
	Expect.equal(clock.deadline, 1060, "started")
	TurnClock.update(clock, state, 60, 1010, nil)
	Expect.equal(clock.deadline, 1060, "same decision keeps its deadline")
	TurnClock.update(clock, state, 60, 1015, "p2")
	Expect.equal(clock.deadline, 1060, "someone else's move doesn't reset it")
	TurnClock.update(clock, state, 60, 1020, "p1")
	Expect.equal(clock.deadline, 1080, "their own move restarts it")
	Engine.act(state, "p1", { type = "Roll" }) -- BuyDecision on Oriental
	TurnClock.update(clock, state, 60, 1030, nil)
	Expect.equal(clock.deadline, 1090, "a new phase restarts it")
end

tests["auction bids get a third of the timer"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 20, 2000, "p1")
	Expect.equal(clock.deadline, 2007, "p1 bids")
	Engine.act(state, "p1", { type = "Bid", amount = 10 })
	TurnClock.update(clock, state, 20, 2001, "p1")
	Expect.equal(clock.actor, "p2", "next bidder")
	Expect.equal(clock.deadline, 2008, "fresh deadline for p2")
end

tests["bots, a timer set to Off and a finished game get no deadline"] = function()
	local state = GameFixtures.newGame(2)
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 0, 1000, nil)
	Expect.equal(clock.deadline, nil, "timer off")

	local p1: any = Engine.getPlayer(state, "p1")
	p1.isBot = true
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.deadline, nil, "bot")

	state.phase = "GameOver"
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.deadline, nil, "game over")
	Expect.equal(clock.actor, nil, "nobody acting")
end

tests["a human replaced by a bot stops the clock"] = function()
	local state = GameFixtures.newGame(2)
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.deadline, 1060)
	local p1: any = Engine.getPlayer(state, "p1")
	p1.isBot = true -- same phase, same player id: only isBot changed
	TurnClock.update(clock, state, 60, 1005, nil)
	Expect.equal(clock.deadline, nil)
end

return tests
