--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Expect = require(script.Parent.Expect)
local MapTestHelper = require(script.Parent.MapTestHelper)

local tests = {}

tests["chance, chest, railroad and utility tiles each get their emblem; others none"] = function()
	local expected = {
		[2] = "Chest",
		[7] = "Question",
		[5] = "Locomotive",
		[15] = "Locomotive",
		[12] = "Bulb",
		[28] = "Tap",
		[0] = nil,
		[1] = nil,
		[4] = nil,
		[10] = nil,
	}
	for position = 0, 39 do
		local tile = Tiles.at(position)
		local shape = EmblemLook.forTile(tile)
		if expected[position] ~= nil then
			Expect.equal(shape, expected[position], `tile {position}`)
		end
		local wantsOne = tile.kind == "Chance" or tile.kind == "CommunityChest" or tile.kind == "Railroad" or tile.kind == "Utility"
		Expect.equal(shape ~= nil, wantsOne, `tile {position} ({tile.kind})`)
	end
end

tests["every emblem shape has a finish for each of its parts"] = function()
	for _, shape in EmblemLook.SHAPES do
		local finish = EmblemLook.FINISHES[shape]
		Expect.equal(finish ~= nil, true, `{shape} finish`)
		Expect.equal(finish.Body ~= nil, true, `{shape} body`)
	end
end

tests["EIU tiles get the hangout, delivery and care package emblems"] = function()
	MapTestHelper.onMap("College", function()
		for position, shape in { [5] = "Hangout", [15] = "Hangout", [25] = "Hangout", [35] = "Hangout", [12] = "Sub", [28] = "Pizza", [2] = "CarePackage", [7] = "Question" } do
			Expect.equal(EmblemLook.forTile(Tiles.at(position)), shape, `EIU tile {position}`)
		end
		for _, shape in { "Hangout", "Sub", "Pizza", "CarePackage" } do
			assert(table.find(EmblemLook.SHAPES, shape), `{shape} listed`)
			assert(EmblemLook.FINISHES[shape], `{shape} finished`)
		end
	end)
	Expect.equal(EmblemLook.forTile(Tiles.at(5)), "Locomotive", "Classic railroads keep the locomotive")
	Expect.equal(EmblemLook.forTile(Tiles.at(2)), "Chest", "Classic chest")
end

return tests
