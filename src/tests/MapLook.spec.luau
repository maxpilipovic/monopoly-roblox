--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapLook = require(ReplicatedStorage.Shared.Board.MapLook)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["a card id tells its map and its classic twin"] = function()
	local map, classic = MapLook.forCard("eiu.chance.go")
	Expect.equal(map, "EIU")
	Expect.equal(classic, "chance.go")
	map, classic = MapLook.forCard("college.chest.go")
	Expect.equal(map, "College")
	Expect.equal(classic, "chest.go")
	map, classic = MapLook.forCard("crazy.reverse")
	Expect.equal(map, "Classic")
	Expect.equal(classic, "crazy.reverse")
end

tests["EIU crazy cards have no classic twin and keep their whole id"] = function()
	local map, classic = MapLook.forCard("eiu.crazy.ghost")
	Expect.equal(map, "EIU")
	Expect.equal(classic, "eiu.crazy.ghost")
end

tests["each map names the railroads and utilities its own way"] = function()
	Expect.equal(MapLook.noun("Classic", "Railroad"), "railroad")
	Expect.equal(MapLook.noun("Classic", "Utility"), "utility")
	Expect.equal(MapLook.noun("College", "Railroad"), "shuttle")
	Expect.equal(MapLook.noun("EIU", "Railroad"), "hangout")
	Expect.equal(MapLook.noun("EIU", "Utility"), "delivery")
end

return tests
