--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Elo = require(ServerScriptService.Server.Data.Elo)
local Expect = require(script.Parent.Expect)

local tests = {}

local function even(count: number): { Elo.Entry }
	local entries = {}
	for index = 1, count do
		table.insert(entries, { id = `p{index}`, rating = 1000 })
	end
	return entries
end

tests["beating an equal player gains what they lose"] = function()
	local changes = Elo.changes(even(2), { p1 = 1, p2 = 2 })
	Expect.equal(changes.p1, 16)
	Expect.equal(changes.p2, -16)
end

tests["an upset gains more than an expected win"] = function()
	local entries = { { id = "low", rating = 900 }, { id = "high", rating = 1300 } }
	local upset = Elo.changes(entries, { low = 1, high = 2 })
	local expected = Elo.changes(entries, { high = 1, low = 2 })
	Expect.equal(upset.low > expected.high, true, `upset {upset.low} vs expected {expected.high}`)
	Expect.equal(upset.low > 0 and upset.high < 0, true)
end

tests["every place counts: second gains, third loses a little, last loses most"] = function()
	local changes = Elo.changes(even(4), { p1 = 1, p2 = 2, p3 = 3, p4 = 4 })
	Expect.equal(changes.p1 > changes.p2, true, "first beats second")
	Expect.equal(changes.p2 > 0, true, `second still gains ({changes.p2})`)
	Expect.equal(changes.p3 < 0, true, `third loses ({changes.p3})`)
	Expect.equal(changes.p4 < changes.p3, true, "last loses most")
	Expect.equal(changes.p1 + changes.p2 + changes.p3 + changes.p4, 0, "equal players: rating is only passed around")
end

tests["a shared place is a draw between those players"] = function()
	local changes = Elo.changes(even(3), { p1 = 1, p2 = 2, p3 = 2 })
	Expect.equal(changes.p2, changes.p3)
	Expect.equal(changes.p1 > 0 and changes.p2 < 0, true)
end

tests["bots count as fixed 1000 opponents and get no change"] = function()
	local changes = Elo.changes({ { id = "me", rating = 1000 }, { id = "bot1", rating = 1000, isBot = true } }, { me = 1, bot1 = 2 })
	Expect.equal(changes.me, 16)
	Expect.equal(changes.bot1, nil)
end

tests["no placings, no change"] = function()
	local changes = Elo.changes(even(2), nil)
	Expect.equal(changes.p1, 0)
	Expect.equal(changes.p2, 0)
end

tests["each player moves by their own K: a provisional player swings more"] = function()
	local changes = Elo.changes({ { id = "new", rating = 1000, k = 40 }, { id = "vet", rating = 1000, k = 20 } }, { new = 1, vet = 2 })
	Expect.equal(changes.new, 20)
	Expect.equal(changes.vet, -10)
end

return tests
