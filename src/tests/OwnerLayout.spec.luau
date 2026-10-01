--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local OwnerLayout = require(ReplicatedStorage.Shared.Board.OwnerLayout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local function tileTop(position: number): (CFrame, Vector3)
	local placement = Layout.getTilePlacement(position)
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0), placement.size
end

tests["the strip lies flat on the outer edge of every ownable tile"] = function()
	local size = OwnerLayout.SIZE
	for _, tile in Tiles.list do
		if not OwnerLayout.isOwnable(tile.position) then
			continue
		end
		local top, tileSize = tileTop(tile.position)
		local spot = top:PointToObjectSpace(OwnerLayout.cframe(tile.position).Position)
		local label = `tile {tile.position}`
		Expect.near(spot.Y, size.Y / 2, `{label} height`)
		Expect.near(spot.X, 0, `{label} centred`)
		assert(size.X <= tileSize.X, `{label} wider than the tile`)
		assert(spot.Z + size.Z / 2 <= tileSize.Z / 2, `{label} off the outer edge`)
		assert(spot.Z - size.Z / 2 > 0, `{label} not on the outer half`)
		-- Oriented with the tile: its long side runs along the edge.
		local along = top:VectorToObjectSpace(OwnerLayout.cframe(tile.position).RightVector)
		Expect.near(math.abs(along.X), 1, `{label} orientation`)
	end
end

tests["the strip stays clear of the token spots"] = function()
	local size = OwnerLayout.SIZE
	local radius = TokenLayout.TOKEN_DIAMETER / 2
	for seat = 1, TokenLayout.MAX_SEATS do
		local top = tileTop(1)
		local token = top:PointToObjectSpace(TokenLayout.spot(1, seat))
		local strip = top:PointToObjectSpace(OwnerLayout.cframe(1).Position)
		assert(token.Z + radius <= strip.Z - size.Z / 2, `seat {seat} token overlaps the strip`)
	end
end

tests["only streets, railroads and utilities get a strip"] = function()
	assert(OwnerLayout.isOwnable(1), "street")
	assert(OwnerLayout.isOwnable(5), "railroad")
	assert(OwnerLayout.isOwnable(12), "utility")
	for _, position in { 0, 2, 4, 7, 10, 20, 30, 38 } do
		assert(not OwnerLayout.isOwnable(position), `position {position} is not ownable`)
		assert(not pcall(OwnerLayout.cframe, position), `position {position} accepted`)
	end
end

return tests
