--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["board size is two corners plus nine tiles"] = function()
	Expect.equal(Layout.BOARD_SIZE, 2 * Layout.CORNER_SIZE + 9 * Layout.TILE_WIDTH)
end

tests["corners sit at the four board corners"] = function()
	local expected = {
		[0] = Vector3.new(32, 0, 32),
		[10] = Vector3.new(-32, 0, 32),
		[20] = Vector3.new(-32, 0, -32),
		[30] = Vector3.new(32, 0, -32),
	}
	for position, pos in expected do
		local placement = Layout.getTilePlacement(position)
		Expect.vectorNear(placement.cframe.Position, pos, `corner {position}`)
		Expect.vectorNear(placement.size, Vector3.new(10, 1, 10), `corner {position} size`)
	end
end

tests["side tiles run clockwise from Go"] = function()
	Expect.vectorNear(Layout.getTilePlacement(1).cframe.Position, Vector3.new(24, 0, 32), "tile 1")
	Expect.vectorNear(Layout.getTilePlacement(9).cframe.Position, Vector3.new(-24, 0, 32), "tile 9")
	Expect.vectorNear(Layout.getTilePlacement(11).cframe.Position, Vector3.new(-32, 0, 24), "tile 11")
	Expect.vectorNear(Layout.getTilePlacement(21).cframe.Position, Vector3.new(-24, 0, -32), "tile 21")
	Expect.vectorNear(Layout.getTilePlacement(39).cframe.Position, Vector3.new(32, 0, 24), "tile 39")
	Expect.vectorNear(Layout.getTilePlacement(1).size, Vector3.new(6, 1, 10), "tile 1 size")
end

tests["every tile faces the board centre and touches the outer edge"] = function()
	local inward = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) }
	for position = 0, 39 do
		local placement = Layout.getTilePlacement(position)
		local side = position // 10
		Expect.vectorNear(placement.cframe.LookVector, inward[side + 1], `tile {position} look`)
		local outerEdge = placement.cframe.Position:Dot(-inward[side + 1]) + placement.size.Z / 2
		Expect.near(outerEdge, Layout.BOARD_SIZE / 2, `tile {position} outer edge`)
	end
end

tests["consecutive tiles touch without gaps or overlap"] = function()
	for position = 0, 39 do
		local a = Layout.getTilePlacement(position)
		local b = Layout.getTilePlacement((position + 1) % 40)
		local distance = (a.cframe.Position - b.cframe.Position).Magnitude
		Expect.near(distance, (a.size.X + b.size.X) / 2, `tiles {position}->{(position + 1) % 40}`)
	end
end

tests["rejects invalid positions"] = function()
	for _, bad in { -1, 40, 1.5 } do
		assert(not pcall(Layout.getTilePlacement, bad), `getTilePlacement({bad}) should error`)
	end
end

return tests
