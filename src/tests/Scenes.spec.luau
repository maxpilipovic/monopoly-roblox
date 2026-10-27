--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["there are five scenes (City and EIU Campus included), each named and lit, matching the room setting"] = function()
	Expect.equal(#Scenes.LIST, 5)
	Expect.equal(Scenes.byId.City ~= nil, true, "the city skyline")
	local seen = {}
	for _, scene in Scenes.LIST do
		Expect.equal(seen[scene.id], nil, `duplicate {scene.id}`)
		seen[scene.id] = true
		Expect.equal(Scenes.byId[scene.id], scene)
		Expect.equal(typeof(scene.name) == "string" and #scene.name > 0, true)
		Expect.equal(typeof(scene.clockTime), "number")
		Expect.equal(RoomSettings.validate({ scene = scene.id, map = scene.map }).scene, scene.id, `{scene.id} accepted by rooms`)
	end
	Expect.equal(Scenes.byId[RoomSettings.DEFAULT.scene] ~= nil, true, "the default exists")
end

tests["a random scene is always a real one"] = function()
	local random = Random.new(3)
	for _ = 1, 20 do
		Expect.equal(Scenes.byId[Scenes.random(random)] ~= nil, true)
	end
end

tests["EIU Campus belongs to the EIU map and only to it"] = function()
	local campus = Scenes.byId.EIUCampus
	assert(campus, "no EIU Campus scene")
	Expect.equal(campus.name, "EIU Campus")
	Expect.equal(campus.map, "EIU")
	Expect.equal(table.concat(Scenes.forMap("EIU"), "|"), "EIUCampus")
	local classic = Scenes.forMap("Classic")
	Expect.equal(table.find(classic, "EIUCampus"), nil, "not offered on Classic")
	Expect.equal(#classic, 4, "every other scene is")
	Expect.equal(table.find(Scenes.forMap("College"), "EIUCampus"), nil, "not offered on College")
end

tests["a random scene never belongs to another map"] = function()
	local random = Random.new(11)
	for _ = 1, 200 do
		assert(Scenes.random(random) ~= "EIUCampus", "Classic got the EIU scene")
		Expect.equal(Scenes.random(random, "EIU"), "EIUCampus")
	end
end

return tests
