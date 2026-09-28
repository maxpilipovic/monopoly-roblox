--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Buildings = require(StarterPlayer.StarterPlayerScripts.Client.Buildings)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["wanted lists only built positions"] = function()
	local snapshot = {
		properties = {
			{ position = 1, owner = "p1", houses = 2, mortgaged = false },
			{ position = 3, owner = "p1", houses = 0, mortgaged = false },
			{ position = 39, owner = "p2", houses = 5, mortgaged = false },
		},
	} :: any
	local wanted = Buildings.wanted(snapshot)
	Expect.equal(wanted[1], 2, "two houses")
	Expect.equal(wanted[3], nil, "bare lot")
	Expect.equal(wanted[39], 5, "hotel")
	Expect.equal(next(Buildings.wanted(nil)), nil, "lobby: nothing")
end

return tests
