--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Tokens = require(StarterPlayer.StarterPlayerScripts.Client.Tokens)
local Expect = require(script.Parent.Expect)

local tests = {}

local PLAYER = { id = "p1", name = "Ana", isBot = false, money = 1500, position = 9, bankrupt = false, inJail = false, jailCards = 0, seat = 1 }

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

tests["walks hop forward through every tile, wrapping past Go"] = function()
	Expect.equal(table.concat(Tokens.path({ from = 38, to = 3, style = "Walk" }), ","), "39,0,1,2,3")
	Expect.equal(table.concat(Tokens.path({ from = 0, to = 2 }), ","), "1,2", "no style means walk")
end

tests["backward moves hop backward"] = function()
	Expect.equal(table.concat(Tokens.path({ from = 7, to = 4, style = "Back" }), ","), "6,5,4")
	Expect.equal(table.concat(Tokens.path({ from = 1, to = 38, style = "Back" }), ","), "0,39,38")
end

tests["a move takes one hop time per tile"] = function()
	Expect.near(Tokens.moveSeconds({ from = 0, to = 7, style = "Walk" }), 7 * Tokens.HOP_TIME)
	Expect.near(Tokens.moveSeconds({ from = 36, to = 33, style = "Back" }), 3 * Tokens.HOP_TIME)
end

tests["going to jail is a single jump"] = function()
	Expect.equal(table.concat(Tokens.path({ from = 30, to = 10, style = "ToJail" }), ","), "10")
	Expect.equal(table.concat(Tokens.path({ from = 10, to = 10, style = "ToJail" }), ","), "10", "from just visiting")
end

return tests
