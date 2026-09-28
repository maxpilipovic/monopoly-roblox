--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Tokens = require(StarterPlayer.StarterPlayerScripts.Client.Tokens)
local Expect = require(script.Parent.Expect)

local tests = {}

local PLAYER = { id = "p1", name = "Ana", isBot = false, money = 1500, position = 9, bankrupt = false, seat = 1 }

tests["a new token starts where its first move in the update begins"] = function()
	local events = {
		{ type = "Rolled", player = "p1", dice = { 4, 5 } },
		{ type = "Moved", player = "p1", from = 0, to = 9, passedGo = false },
	}
	Expect.equal(Tokens.startPosition(PLAYER, events), 0)
end

tests["a new token with no move in the update starts at its snapshot position"] = function()
	local events = { { type = "Moved", player = "p2", from = 3, to = 7, passedGo = false } }
	Expect.equal(Tokens.startPosition(PLAYER, events), 9)
end

return tests
