--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["has 40 tiles in position order"] = function()
	Expect.equal(Tiles.COUNT, 40, "COUNT")
	Expect.equal(#Tiles.list, 40, "#list")
	for i, tile in Tiles.list do
		Expect.equal(tile.position, i - 1, `list[{i}].position`)
		Expect.equal(Tiles.at(i - 1), tile, `at({i - 1})`)
	end
end

tests["corners are Go, Jail, Free Parking, Go To Jail"] = function()
	Expect.equal(Tiles.at(0).kind, "Go")
	Expect.equal(Tiles.at(10).kind, "Jail")
	Expect.equal(Tiles.at(20).kind, "FreeParking")
	Expect.equal(Tiles.at(30).kind, "GoToJail")
end

tests["kind counts match the official board"] = function()
	local counts = {}
	for _, tile in Tiles.list do
		counts[tile.kind] = (counts[tile.kind] or 0) + 1
	end
	Expect.equal(counts.Property, 22, "Property")
	Expect.equal(counts.Railroad, 4, "Railroad")
	Expect.equal(counts.Utility, 2, "Utility")
	Expect.equal(counts.Tax, 2, "Tax")
	Expect.equal(counts.Chance, 3, "Chance")
	Expect.equal(counts.CommunityChest, 3, "CommunityChest")
end

tests["color groups exist and have the right sizes"] = function()
	local sizes = {}
	for _, tile in Tiles.list do
		if tile.kind == "Property" then
			local group = assert(tile.group, `{tile.name} has no group`)
			assert(ColorGroups[group], `unknown group {group}`)
			sizes[group] = (sizes[group] or 0) + 1
		end
	end
	for group in ColorGroups do
		local expected = if group == "Brown" or group == "DarkBlue" then 2 else 3
		Expect.equal(sizes[group], expected, group)
	end
end

tests["properties have a price and six increasing rents"] = function()
	for _, tile in Tiles.list do
		if tile.kind == "Property" then
			assert((tile.price or 0) > 0, `{tile.name} price`)
			local rent = assert(tile.rent, `{tile.name} rent`)
			Expect.equal(#rent, 6, `{tile.name} #rent`)
			for i = 2, 6 do
				assert(rent[i] > rent[i - 1], `{tile.name} rent not increasing at {i}`)
			end
		end
	end
end

tests["railroads cost 200, utilities 150, taxes 200 and 100"] = function()
	for _, tile in Tiles.list do
		if tile.kind == "Railroad" then
			Expect.equal(tile.price, 200, tile.name)
		elseif tile.kind == "Utility" then
			Expect.equal(tile.price, 150, tile.name)
		end
	end
	Expect.equal(Tiles.at(4).amount, 200, "Income Tax")
	Expect.equal(Tiles.at(38).amount, 100, "Luxury Tax")
	Expect.equal(Tiles.at(39).name, "Boardwalk")
end

tests["at rejects invalid positions"] = function()
	for _, bad in { -1, 40, 1.5 } do
		assert(not pcall(Tiles.at, bad), `at({bad}) should error`)
	end
end

tests["tile data is frozen"] = function()
	assert(table.isfrozen(Tiles.list), "list not frozen")
	assert(table.isfrozen(Tiles.at(1)), "tile not frozen")
	assert(table.isfrozen(Tiles.at(1).rent :: any), "rent not frozen")
end

return tests
