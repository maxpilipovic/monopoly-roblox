--!strict
-- Where houses and hotels stand: in a row along the color band on a street's inner edge.

local Layout = require(script.Parent.Layout)
local Tiles = require(script.Parent.Tiles)

local BuildingLayout = {}

BuildingLayout.HOTEL = 5
BuildingLayout.HOUSE_SIZE = Vector3.new(1, 0.8, 1)
BuildingLayout.HOTEL_SIZE = Vector3.new(2.2, 1, 1.4)

local BAND_DEPTH = 2.5 -- matches the color band BoardBuilder draws
local BAND_THICKNESS = 0.1
local HOUSE_X = { -2.1, -0.7, 0.7, 2.1 }

-- Base centre of house `index` (1-4) or the hotel (5), on top of the band, oriented with the tile.
function BuildingLayout.cframe(position: number, index: number): CFrame
	local tile = Tiles.at(position)
	assert(tile.kind == "Property", `{tile.name} can't have buildings`)
	assert(index % 1 == 0 and index >= 1 and index <= BuildingLayout.HOTEL, `invalid building index {index}`)
	local placement = Layout.getTilePlacement(position)
	local bandZ = -(placement.size.Z / 2 - BAND_DEPTH / 2)
	local x = if index == BuildingLayout.HOTEL then 0 else HOUSE_X[index]
	return Layout.ORIGIN * placement.cframe * CFrame.new(x, placement.size.Y / 2 + BAND_THICKNESS, bandZ)
end

return BuildingLayout
