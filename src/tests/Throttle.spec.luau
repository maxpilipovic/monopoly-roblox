--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Throttle = require(ServerScriptService.Server.Game.Throttle)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["allows one event per window for each key"] = function()
	local throttle = Throttle.new(1)
	assert(Throttle.allow(throttle, "a", 10), "first")
	assert(not Throttle.allow(throttle, "a", 10.5), "too soon")
	assert(Throttle.allow(throttle, "b", 10.5), "other keys are separate")
	assert(Throttle.allow(throttle, "a", 11), "window over")
end

tests["forgetting a key resets it"] = function()
	local throttle = Throttle.new(1)
	Throttle.allow(throttle, "a", 10)
	Throttle.forget(throttle, "a")
	assert(Throttle.allow(throttle, "a", 10.1), "reset")
	Expect.equal(throttle.last.b, nil, "no entry for unseen keys")
end

return tests
