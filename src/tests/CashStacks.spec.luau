--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CashStacks = require(ReplicatedStorage.Shared.Board.CashStacks)
local Expect = require(script.Parent.Expect)

local tests = {}

local function bundles(layout: { CashStacks.Stack }): number
	local total = 0
	for _, stack in layout do
		total += stack.bundles
	end
	return total
end

tests["an empty pot shows no cash"] = function()
	Expect.equal(#CashStacks.layout(0), 0)
end

tests["a bundle per $100, rounded up, in stacks of up to six"] = function()
	Expect.equal(bundles(CashStacks.layout(50)), 1)
	Expect.equal(bundles(CashStacks.layout(200)), 2)
	Expect.equal(bundles(CashStacks.layout(1250)), 13)
	for _, stack in CashStacks.layout(1250) do
		Expect.equal(stack.bundles >= 1 and stack.bundles <= CashStacks.MAX_BUNDLES, true)
	end
end

tests["a huge pot is capped at twelve full stacks"] = function()
	local layout = CashStacks.layout(1000000)
	Expect.equal(#layout, CashStacks.MAX_STACKS)
	Expect.equal(bundles(layout), CashStacks.MAX_STACKS * CashStacks.MAX_BUNDLES)
end

tests["stacks don't overlap"] = function()
	local layout = CashStacks.layout(7000)
	for i = 1, #layout do
		for j = i + 1, #layout do
			Expect.equal((layout[i].offset - layout[j].offset).Magnitude >= CashStacks.SPACING - 1e-6, true, `{i} and {j}`)
		end
	end
end

return tests
