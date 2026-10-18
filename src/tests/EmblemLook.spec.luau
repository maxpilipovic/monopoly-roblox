--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Expect = require(script.Parent.Expect)

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

return tests
