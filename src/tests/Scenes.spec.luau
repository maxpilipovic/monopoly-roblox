--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["there are three scenes, each named and lit, matching the room setting"] = function()
	Expect.equal(#Scenes.LIST, 3)
	local seen = {}
	for _, scene in Scenes.LIST do
		Expect.equal(seen[scene.id], nil, `duplicate {scene.id}`)
		seen[scene.id] = true
		Expect.equal(Scenes.byId[scene.id], scene)
		Expect.equal(typeof(scene.name) == "string" and #scene.name > 0, true)
		Expect.equal(typeof(scene.clockTime), "number")
		Expect.equal(RoomSettings.validate({ scene = scene.id }).scene, scene.id, `{scene.id} accepted by rooms`)
	end
	Expect.equal(Scenes.byId[RoomSettings.DEFAULT.scene] ~= nil, true, "the default exists")
end

tests["a random scene is always a real one"] = function()
	local random = Random.new(3)
	for _ = 1, 20 do
		Expect.equal(Scenes.byId[Scenes.random(random)] ~= nil, true)
	end
end

return tests
