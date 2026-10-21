--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local STRIP_DEPTH = 2.5

local function tileTop(position: number): CFrame
	local placement = Layout.getTilePlacement(position)
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
end

tests["any number of pieces on a tile stays on it, clear of the colour band, without touching"] = function()
	local radius = TokenLayout.TOKEN_DIAMETER / 2
	for position = 0, 39 do
		local placement = Layout.getTilePlacement(position)
		for count = 1, TokenLayout.MAX_SEATS do
			for index = 1, count do
				local localSpot = tileTop(position):PointToObjectSpace(TokenLayout.spot(position, index, count))
				Expect.near(localSpot.Y, 0, `tile {position} {index}/{count} height`)
				assert(math.abs(localSpot.X) + radius <= placement.size.X / 2, `tile {position} {index}/{count} off the side`)
				assert(localSpot.Z + radius <= placement.size.Z / 2, `tile {position} {index}/{count} off the outer edge`)
				assert(localSpot.Z - radius >= -placement.size.Z / 2 + STRIP_DEPTH, `tile {position} {index}/{count} on the band`)
				for other = index + 1, count do
					local gap = (TokenLayout.spot(position, index, count) - TokenLayout.spot(position, other, count)).Magnitude
					assert(gap >= TokenLayout.TOKEN_DIAMETER, `tile {position}: {index} and {other} of {count} touch`)
				end
			end
		end
	end
end

tests["a piece alone stands in the middle of its tile, and a group is centred there too"] = function()
	for _, position in { 1, 15, 39 } do
		local alone = tileTop(position):PointToObjectSpace(TokenLayout.spot(position, 1, 1))
		Expect.near(alone.X, 0, "across the tile")
		Expect.near(alone.Z, TokenLayout.CENTER.Z, "in the open area")
		for count = 2, TokenLayout.MAX_SEATS do
			local sum = Vector3.zero
			for index = 1, count do
				sum += tileTop(position):PointToObjectSpace(TokenLayout.spot(position, index, count))
			end
			Expect.near((sum / count).X, 0, `{count} centred across`)
		end
	end
end

tests["six distinct seat colors"] = function()
	Expect.equal(#TokenLayout.SEAT_COLORS, 6)
	for a = 1, 6 do
		for b = a + 1, 6 do
			assert(TokenLayout.SEAT_COLORS[a] ~= TokenLayout.SEAT_COLORS[b], `colors {a} and {b} match`)
		end
	end
end

tests["pieces in jail stay in the cell, apart from each other and from visitors"] = function()
	local placement = Layout.getTilePlacement(TokenLayout.JAIL_POSITION)
	local radius = TokenLayout.TOKEN_DIAMETER / 2
	for count = 1, TokenLayout.MAX_SEATS do
		for index = 1, count do
			local spot = TokenLayout.jailSpot(index, count)
			local localSpot = tileTop(TokenLayout.JAIL_POSITION):PointToObjectSpace(spot)
			assert(math.abs(localSpot.X) + radius <= placement.size.X / 2, `{index}/{count} off the side`)
			assert(localSpot.Z - radius >= -placement.size.Z / 2 - 1e-6, `{index}/{count} off the inner edge`)
			assert(localSpot.Z < 0, `{index}/{count} not in the inner half`)
			for visitors = 1, TokenLayout.MAX_SEATS do
				for v = 1, visitors do
					local gap = (spot - TokenLayout.spot(TokenLayout.JAIL_POSITION, v, visitors)).Magnitude
					assert(gap >= TokenLayout.TOKEN_DIAMETER, `jailed {index}/{count} touches visitor {v}/{visitors}`)
				end
			end
		end
	end
end

tests["rejects impossible slots"] = function()
	assert(not pcall(TokenLayout.spot, 0, 1.5, 3), "index 1.5 accepted")
end

return tests
