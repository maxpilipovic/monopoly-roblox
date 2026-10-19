--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Elo = require(ServerScriptService.Server.Data.Elo)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["beating an equal player gains what they lose"] = function()
	local changes = Elo.changes({ { id = "a", rating = 1000 }, { id = "b", rating = 1000 } }, "a")
	Expect.equal(changes.a, 16)
	Expect.equal(changes.b, -16)
end

tests["an upset gains more than an expected win"] = function()
	local upset = Elo.changes({ { id = "low", rating = 900 }, { id = "high", rating = 1300 } }, "low")
	local expected = Elo.changes({ { id = "low", rating = 900 }, { id = "high", rating = 1300 } }, "high")
	Expect.equal(upset.low > expected.high, true, `upset {upset.low} vs expected {expected.high}`)
	Expect.equal(upset.low > 0 and upset.high < 0, true)
end

tests["in a bigger game the winner gains and everyone else loses a share"] = function()
	local changes = Elo.changes({
		{ id = "a", rating = 1000 },
		{ id = "b", rating = 1000 },
		{ id = "c", rating = 1000 },
		{ id = "d", rating = 1000 },
	}, "a")
	Expect.equal(changes.a, 16)
	Expect.equal(changes.b < 0 and changes.c < 0 and changes.d < 0, true)
	Expect.equal(changes.b, changes.c, "the losers are treated alike")
end

tests["bots count as fixed 1000 opponents and get no change"] = function()
	local changes = Elo.changes({ { id = "me", rating = 1000 }, { id = "bot1", rating = 1000, isBot = true } }, "me")
	Expect.equal(changes.me, 16)
	Expect.equal(changes.bot1, nil)
end

tests["a game nobody won (time limit with no winner) changes nothing"] = function()
	local changes = Elo.changes({ { id = "a", rating = 1000 }, { id = "b", rating = 1200 } }, nil)
	Expect.equal(changes.a, 0)
	Expect.equal(changes.b, 0)
end

return tests
