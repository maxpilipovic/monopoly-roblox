--!strict
-- Where each seat's token stands on a tile, and each seat's color.

local Layout = require(script.Parent.Layout)

local TokenLayout = {}

TokenLayout.MAX_SEATS = 6
TokenLayout.TOKEN_DIAMETER = 1.4

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

function TokenLayout.spot(position: number, seat: number): Vector3
	assert(seat % 1 == 0 and seat >= 1 and seat <= TokenLayout.MAX_SEATS, `invalid seat {seat}`)
	local placement = Layout.getTilePlacement(position)
	local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
	return tileTop:PointToWorldSpace(SPOTS[seat])
end

return TokenLayout
