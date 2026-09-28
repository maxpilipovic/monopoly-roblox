--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingLayout = require(ReplicatedStorage.Shared.Board.BuildingLayout)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Expect = require(script.Parent.Expect)

local tests = {}

local BAND_DEPTH = 2.5
local BAND_THICKNESS = 0.1

tests["buildings stand on the color band of every street"] = function()
	for _, tile in Tiles.list do
		if tile.kind ~= "Property" then
			continue
		end
		local placement = Layout.getTilePlacement(tile.position)
		local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
		for index = 1, BuildingLayout.HOTEL do
			local size = if index == BuildingLayout.HOTEL then BuildingLayout.HOTEL_SIZE else BuildingLayout.HOUSE_SIZE
			local spot = tileTop:PointToObjectSpace(BuildingLayout.cframe(tile.position, index).Position)
			local label = `tile {tile.position} index {index}`
			Expect.near(spot.Y, BAND_THICKNESS, `{label} height`)
			assert(math.abs(spot.X) + size.X / 2 <= placement.size.X / 2, `{label} off the side`)
			assert(spot.Z - size.Z / 2 >= -placement.size.Z / 2, `{label} off the inner edge`)
			assert(spot.Z + size.Z / 2 <= -placement.size.Z / 2 + BAND_DEPTH, `{label} off the band`)
		end
	end
end

tests["houses on one street don't overlap"] = function()
	for a = 1, 4 do
		for b = a + 1, 4 do
			local gap = (BuildingLayout.cframe(1, a).Position - BuildingLayout.cframe(1, b).Position).Magnitude
			assert(gap >= BuildingLayout.HOUSE_SIZE.X, `houses {a} and {b} overlap`)
		end
	end
end

tests["buildings only go on streets, at indexes 1-5"] = function()
	assert(not pcall(BuildingLayout.cframe, 5, 1), "railroad accepted")
	assert(not pcall(BuildingLayout.cframe, 1, 0), "index 0 accepted")
	assert(not pcall(BuildingLayout.cframe, 1, 6), "index 6 accepted")
end

return tests
