--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local SessionLock = require(ServerScriptService.Server.Data.SessionLock)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["unlocked, our own or stale data can be taken"] = function()
	Expect.equal(SessionLock.decide(nil, "A", 1000, false), "take", "new player")
	Expect.equal(SessionLock.decide({ wins = 1 }, "A", 1000, false), "take", "old save without a lock")
	Expect.equal(SessionLock.decide({ lock = { job = "A", at = 990 } }, "A", 1000, false), "take", "ours")
	Expect.equal(SessionLock.decide({ lock = { job = "B", at = 1000 - SessionLock.STALE_SECONDS - 1 } }, "A", 1000, false), "take", "stale")
end

tests["another server's fresh lock means wait, unless we give up waiting"] = function()
	local held = { lock = { job = "B", at = 990 } }
	Expect.equal(SessionLock.decide(held, "A", 1000, false), "wait")
	Expect.equal(SessionLock.decide(held, "A", 1000, true), "take", "forced after waiting long enough")
end

tests["only the lock holder may write"] = function()
	Expect.equal(SessionLock.canWrite(nil, "A"), true, "nothing stored yet")
	Expect.equal(SessionLock.canWrite({ lock = { job = "A", at = 1 } }, "A"), true)
	Expect.equal(SessionLock.canWrite({ lock = { job = "B", at = 1 } }, "A"), false, "someone took it over")
	Expect.equal(SessionLock.canWrite({ wins = 3 }, "A"), true, "no lock at all")
end

return tests
