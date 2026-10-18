--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Assets = require(ServerScriptService.Server.Assets)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["part names lose Blender's duplicate-name suffix"] = function()
	Expect.equal(Assets.cleanName("Body.001"), "Body")
	Expect.equal(Assets.cleanName("Trim.012"), "Trim")
	Expect.equal(Assets.cleanName("Body"), "Body", "already clean")
	Expect.equal(Assets.cleanName("Drop"), "Drop")
end

return tests
