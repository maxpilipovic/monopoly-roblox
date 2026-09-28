--!strict
-- Where each seat's token stands on a tile, and each seat's color.

local Layout = require(script.Parent.Layout)

local TokenLayout = {}

TokenLayout.MAX_SEATS = 6
TokenLayout.TOKEN_DIAMETER = 1.4
TokenLayout.JAIL_POSITION = 10

TokenLayout.SEAT_COLORS = table.freeze({
	Color3.fromRGB(220, 50, 47), -- red
	Color3.fromRGB(38, 139, 210), -- blue
	Color3.fromRGB(133, 153, 0), -- green
	Color3.fromRGB(181, 137, 0), -- gold
	Color3.fromRGB(108, 113, 196), -- violet
	Color3.fromRGB(42, 161, 152), -- teal
})

-- Tile-local offsets (X along the edge, +Z toward the outer edge), a 3x2 grid clear of the color band.
local SPOTS = {
	Vector3.new(-1.8, 0, 0.6),
	Vector3.new(0, 0, 0.6),
	Vector3.new(1.8, 0, 0.6),
	Vector3.new(-1.8, 0, 2.8),
	Vector3.new(0, 0, 2.8),
	Vector3.new(1.8, 0, 2.8),
}

-- Inside the jail cell: the inner half of the Jail corner (-Z, toward the board centre),
-- clear of the just-visiting spots on the outer half.
local JAIL_SPOTS = {
	Vector3.new(-2.2, 0, -2.0),
	Vector3.new(0, 0, -2.0),
	Vector3.new(2.2, 0, -2.0),
	Vector3.new(-2.2, 0, -3.9),
	Vector3.new(0, 0, -3.9),
	Vector3.new(2.2, 0, -3.9),
}

local function tileTop(position: number): CFrame
	local placement = Layout.getTilePlacement(position)
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
end

local function checkSeat(seat: number)
	assert(seat % 1 == 0 and seat >= 1 and seat <= TokenLayout.MAX_SEATS, `invalid seat {seat}`)
end

function TokenLayout.spot(position: number, seat: number): Vector3
	checkSeat(seat)
	return tileTop(position):PointToWorldSpace(SPOTS[seat])
end

function TokenLayout.jailSpot(seat: number): Vector3
	checkSeat(seat)
	return tileTop(TokenLayout.JAIL_POSITION):PointToWorldSpace(JAIL_SPOTS[seat])
end

return TokenLayout
