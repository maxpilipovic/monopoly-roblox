--!strict
-- Where a tile's ownership strip lies: flat along its outer (board-edge) side, opposite the color band
-- and the houses, clear of where tokens stand.

local Layout = require(script.Parent.Layout)
local Tiles = require(script.Parent.Tiles)

local OwnerLayout = {}

local MARGIN = 0.3 -- inset from the tile's sides and outer edge
local OWNABLE = { Property = true, Railroad = true, Utility = true }

OwnerLayout.SIZE = Vector3.new(Layout.TILE_WIDTH - 2 * MARGIN, 0.1, 0.6)

function OwnerLayout.isOwnable(position: number): boolean
	return OWNABLE[Tiles.at(position).kind] == true
end

-- Centre of the strip, oriented with the tile (+Z toward the board's outer edge).
function OwnerLayout.cframe(position: number): CFrame
	assert(OwnerLayout.isOwnable(position), `{Tiles.at(position).name} can't be owned`)
	local placement = Layout.getTilePlacement(position)
	local z = placement.size.Z / 2 - MARGIN - OwnerLayout.SIZE.Z / 2
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2 + OwnerLayout.SIZE.Y / 2, z)
end

return OwnerLayout
