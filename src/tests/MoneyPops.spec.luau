--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local MoneyPops = require(StarterPlayer.StarterPlayerScripts.Client.MoneyPops)
local Expect = require(script.Parent.Expect)

local tests = {}

local function describe(pops: { MoneyPops.Pop }): string
	local parts = {}
	for _, pop in pops do
		table.insert(parts, `{pop.player}{if pop.amount >= 0 then "+" else ""}{pop.amount}`)
	end
	return table.concat(parts, " ")
end

tests["rent between players pops on both tokens"] = function()
	local pops = MoneyPops.fromEvent({ type = "Paid", from = "p1", to = "p2", amount = 40, reason = "Rent" })
	Expect.equal(describe(pops), "p1-40 p2+40")
end

tests["money from or to the bank pops only on the player"] = function()
	Expect.equal(describe(MoneyPops.fromEvent({ type = "Paid", to = "p1", amount = 200, reason = "Go" })), "p1+200")
	Expect.equal(describe(MoneyPops.fromEvent({ type = "Paid", from = "p2", amount = 100, reason = "Tax" })), "p2-100")
end

tests["nothing to show for a zero payment or another event"] = function()
	Expect.equal(#MoneyPops.fromEvent({ type = "Paid", from = "p1", to = "p2", amount = 0, reason = "Rent" }), 0)
	Expect.equal(#MoneyPops.fromEvent({ type = "Rolled", player = "p1", dice = { 1, 2 } }), 0)
end

tests["passing Go is called out"] = function()
	Expect.equal(MoneyPops.passedGo({ type = "Paid", to = "p1", amount = 200, reason = "Go" }), true)
	Expect.equal(MoneyPops.passedGo({ type = "Paid", to = "p1", amount = 50, reason = "Card" }), false)
end

return tests
