--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local STRIP_DEPTH = 2.5

tests["every spot is on its tile's top surface, clear of the color band"] = function()
	for position = 0, 39 do
		local placement = Layout.getTilePlacement(position)
		local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
		for seat = 1, TokenLayout.MAX_SEATS do
			local localSpot = tileTop:PointToObjectSpace(TokenLayout.spot(position, seat))
			local radius = TokenLayout.TOKEN_DIAMETER / 2
			Expect.near(localSpot.Y, 0, `tile {position} seat {seat} height`)
			assert(math.abs(localSpot.X) + radius <= placement.size.X / 2, `tile {position} seat {seat} off the side`)
			assert(localSpot.Z + radius <= placement.size.Z / 2, `tile {position} seat {seat} off the outer edge`)
			assert(localSpot.Z - radius >= -placement.size.Z / 2 + STRIP_DEPTH, `tile {position} seat {seat} on the band`)
		end
	end
end

tests["seats on the same tile do not overlap"] = function()
	for _, position in { 0, 1, 10, 25 } do
		for a = 1, TokenLayout.MAX_SEATS do
			for b = a + 1, TokenLayout.MAX_SEATS do
				local gap = (TokenLayout.spot(position, a) - TokenLayout.spot(position, b)).Magnitude
				assert(gap >= TokenLayout.TOKEN_DIAMETER, `tile {position}: seats {a} and {b} overlap`)
			end
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

tests["rejects invalid seats"] = function()
	for _, bad in { 0, 7, 1.5 } do
		assert(not pcall(TokenLayout.spot, 0, bad), `seat {bad} accepted`)
	end
end

return tests
