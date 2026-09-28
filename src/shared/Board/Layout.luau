--!strict
-- Maps a board position (0-39) to where its tile sits, relative to the board centre.

local Tiles = require(script.Parent.Tiles)

export type TilePlacement = {
	cframe: CFrame, -- LookVector points at the board centre
	size: Vector3, -- (width along the edge, thickness, depth)
}

local Layout = {}

Layout.TILE_WIDTH = 6
Layout.CORNER_SIZE = 10
Layout.TILE_THICKNESS = 1
Layout.BOARD_SIZE = 2 * Layout.CORNER_SIZE + 9 * Layout.TILE_WIDTH
-- Board centre in world space; tiles rest on the baseplate, whose top is at y = 0.
Layout.ORIGIN = CFrame.new(0, Layout.TILE_THICKNESS / 2, 0)

local TILES_PER_SIDE = Tiles.COUNT // 4
local EDGE_CENTER = Layout.BOARD_SIZE / 2 - Layout.CORNER_SIZE / 2
-- Bottom (+Z), left (-X), top (-Z), right (+X): each side is the bottom side rotated about Y.
local SIDE_YAW = { 0, -math.pi / 2, math.pi, math.pi / 2 }

function Layout.getTilePlacement(position: number): TilePlacement
	assert(position % 1 == 0 and position >= 0 and position < Tiles.COUNT, `invalid board position {position}`)

	local side = position // TILES_PER_SIDE
	local offset = position % TILES_PER_SIDE

	-- Distance from this side's starting corner centre, measured along the edge.
	local along, width
	if offset == 0 then
		along, width = 0, Layout.CORNER_SIZE
	else
		along = Layout.CORNER_SIZE / 2 + Layout.TILE_WIDTH * (offset - 1) + Layout.TILE_WIDTH / 2
		width = Layout.TILE_WIDTH
	end

	-- Laid out on the bottom side (starting corner at +X/+Z, running toward -X), then rotated into place.
	local bottomSidePosition = Vector3.new(EDGE_CENTER - along, 0, EDGE_CENTER)
	return {
		cframe = CFrame.Angles(0, SIDE_YAW[side + 1], 0) * CFrame.new(bottomSidePosition),
		size = Vector3.new(width, Layout.TILE_THICKNESS, Layout.CORNER_SIZE),
	}
end

return Layout
