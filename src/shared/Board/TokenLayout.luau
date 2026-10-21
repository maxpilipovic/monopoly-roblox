--!strict
-- Where tokens stand on a tile (arranged by how many share it, centred on the tile), and each seat's color.

local Layout = require(script.Parent.Layout)

local TokenLayout = {}

TokenLayout.MAX_SEATS = 6
TokenLayout.TOKEN_DIAMETER = 1.8
TokenLayout.JAIL_POSITION = 10

TokenLayout.SEAT_COLORS = table.freeze({
	Color3.fromRGB(220, 50, 47), -- red
	Color3.fromRGB(38, 139, 210), -- blue
	Color3.fromRGB(133, 153, 0), -- green
	Color3.fromRGB(181, 137, 0), -- gold
	Color3.fromRGB(108, 113, 196), -- violet
	Color3.fromRGB(42, 161, 152), -- teal
})

-- How the pieces on one tile stand, by how many share it (tile-local X along the edge, Z toward
-- the outer edge, around the middle of the tile's open area): one alone stands dead centre, two
-- side by side, three in a row, four in a square, five or six in two rows of three.
local ARRANGEMENTS: { { Vector3 } } = {
	{ Vector3.new(0, 0, 0) },
	{ Vector3.new(-1.25, 0, 0), Vector3.new(1.25, 0, 0) },
	{ Vector3.new(-1.95, 0, 0), Vector3.new(0, 0, 0), Vector3.new(1.95, 0, 0) },
	{ Vector3.new(-1.25, 0, -1.15), Vector3.new(1.25, 0, -1.15), Vector3.new(-1.25, 0, 1.15), Vector3.new(1.25, 0, 1.15) },
	{ Vector3.new(-1.95, 0, -1.15), Vector3.new(0, 0, -1.15), Vector3.new(1.95, 0, -1.15), Vector3.new(-1.25, 0, 1.15), Vector3.new(1.25, 0, 1.15) },
	{
		Vector3.new(-1.95, 0, -1.15), Vector3.new(0, 0, -1.15), Vector3.new(1.95, 0, -1.15),
		Vector3.new(-1.95, 0, 1.15), Vector3.new(0, 0, 1.15), Vector3.new(1.95, 0, 1.15),
	},
}

-- The middle of a tile's open area: its outer side, past the colour band (2.5 deep on a 10-deep tile).
TokenLayout.CENTER = Vector3.new(0, 0, 1.25)
-- Inside the jail cell: the inner half of the Jail corner, clear of visitors on the outer half.
TokenLayout.JAIL_CENTER = Vector3.new(0, 0, -2.9)

local function tileTop(position: number): CFrame
	local placement = Layout.getTilePlacement(position)
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
end

local function checkSeat(seat: number)
	assert(seat % 1 == 0 and seat >= 1 and seat <= TokenLayout.MAX_SEATS, `invalid seat {seat}`)
end

-- Where the `index`th of `count` pieces sharing a tile stands (one alone stands in the middle).
function TokenLayout.spot(position: number, index: number?, count: number?): Vector3
	local n = math.clamp(count or 1, 1, TokenLayout.MAX_SEATS)
	local i = math.clamp(index or 1, 1, n)
	checkSeat(i)
	return tileTop(position):PointToWorldSpace(TokenLayout.CENTER + ARRANGEMENTS[n][i])
end

-- The same, for pieces in the jail cell.
function TokenLayout.jailSpot(index: number?, count: number?): Vector3
	local n = math.clamp(count or 1, 1, TokenLayout.MAX_SEATS)
	local i = math.clamp(index or 1, 1, n)
	checkSeat(i)
	return tileTop(TokenLayout.JAIL_POSITION):PointToWorldSpace(TokenLayout.JAIL_CENTER + ARRANGEMENTS[n][i])
end

return TokenLayout
