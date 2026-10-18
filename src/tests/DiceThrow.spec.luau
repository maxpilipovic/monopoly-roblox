--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Expect = require(script.Parent.Expect)

local tests = {}

-- A made-up throw: each die drops along a line and ends at an awkward resting rotation.
local function fakeThrow(): DiceThrow.Throw
	local ends = { CFrame.Angles(0, 0.7, 0) * CFrame.Angles(math.pi / 2, 0, 0), CFrame.Angles(math.pi, 2.1, 0) }
	local throw = {}
	for d = 1, 2 do
		local die = {}
		for i = 0, 4 do
			local t = i / 4
			local position = Vector3.new(d * 5 - 7.5, 2 + 8 * (1 - t), 18 * (1 - t))
			local rotation = CFrame.Angles(3 * (1 - t), 0, 2 * (1 - t)) * ends[d]
			DiceThrow.encode(CFrame.new(position) * rotation, die)
		end
		throw[d] = die
	end
	return throw
end

tests["faceUp reads every face of the model"] = function()
	-- Model layout: 1 = +Y, 2 = +Z, 3 = +X; opposites sum to 7.
	Expect.equal(DiceThrow.faceUp(CFrame.identity), 1)
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(math.pi, 0, 0)), 6)
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(-math.pi / 2, 0, 0)), 2, "+Z turned up")
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(math.pi / 2, 0, 0)), 5, "-Z turned up")
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(0, 0, math.pi / 2)), 3, "+X turned up")
	Expect.equal(DiceThrow.faceUp(CFrame.Angles(0, 0, -math.pi / 2)), 4, "-X turned up")
end

tests["tilt is how far the top face leans from flat"] = function()
	Expect.near(DiceThrow.tilt(CFrame.identity), 0)
	Expect.near(DiceThrow.tilt(CFrame.Angles(math.rad(4), 0, 0)), 4, "a slight lean", 1e-2)
	Expect.near(DiceThrow.tilt(CFrame.Angles(0, 1.3, 0)), 0, "spinning flat is still flat")
end

tests["a frame survives encoding to 3 decimals"] = function()
	local original = CFrame.new(3.21, 4.5, -7.125) * CFrame.Angles(0.4, 2.2, -1.1)
	local packed = {}
	DiceThrow.encode(original, packed)
	Expect.equal(#packed, 7)
	local back = DiceThrow.frame(packed, 1)
	Expect.vectorNear(back.Position, original.Position, "position", 1e-3)
	Expect.vectorNear(back.LookVector, original.LookVector, "look", 5e-3)
	Expect.vectorNear(back.UpVector, original.UpVector, "up", 5e-3)
	Expect.near(back.LookVector.Magnitude, 1, "a clean rotation", 1e-6)
end

tests["the planned dice end showing the rolled numbers, from every side and spin"] = function()
	local throw = fakeThrow()
	local count = DiceThrow.frameCount(throw)
	Expect.equal(count, 5)
	for a = 1, 6 do
		for b = 1, 6 do
			for side = 0, 3 do
				for spin = 0, 3 do
					local plan = DiceThrow.plan(throw, { a, b }, side, { spin, 3 - spin })
					Expect.equal(DiceThrow.faceUp(plan[1][count]), a, `die 1 rolling {a},{b} side {side} spin {spin}`)
					Expect.equal(DiceThrow.faceUp(plan[2][count]), b, `die 2 rolling {a},{b} side {side} spin {spin}`)
				end
			end
		end
	end
end

tests["turning a die to show a number never moves it"] = function()
	local throw = fakeThrow()
	local plan = DiceThrow.plan(throw, { 4, 6 }, 0, { 0, 0 })
	for d = 1, 2 do
		for i = 1, DiceThrow.frameCount(throw) do
			Expect.vectorNear(plan[d][i].Position, DiceThrow.frame(throw[d], i).Position, `die {d} frame {i}`)
		end
	end
end

tests["a throw is turned to come from the roller's side"] = function()
	local throw = fakeThrow()
	for side = 0, 3 do
		local plan = DiceThrow.plan(throw, { 1, 1 }, side, { 0, 0 })
		local turn = CFrame.Angles(0, Layout.sideYaw(side), 0)
		Expect.vectorNear(plan[1][1].Position, turn * DiceThrow.frame(throw[1], 1).Position, `side {side}`)
	end
end

tests["the four spins give four different resting turns"] = function()
	local throw = fakeThrow()
	local count = DiceThrow.frameCount(throw)
	local looks = {}
	for spin = 0, 3 do
		-- With 5 up the -Z (look) axis points up, so the spin shows on the right vector.
		local look = DiceThrow.plan(throw, { 5, 5 }, 0, { spin, spin })[1][count].RightVector
		for _, other in looks do
			Expect.equal((look - other).Magnitude > 0.5, true, `spin {spin} differs`)
		end
		table.insert(looks, look)
	end
end

tests["side follows the board's rows"] = function()
	Expect.equal(DiceThrow.side(0), 0)
	Expect.equal(DiceThrow.side(9), 0)
	Expect.equal(DiceThrow.side(10), 1)
	Expect.equal(DiceThrow.side(25), 2)
	Expect.equal(DiceThrow.side(39), 3)
end

tests["the roller is where they stood before the move"] = function()
	local players = { { id = "p1", position = 12 }, { id = "p2", position = 30 } }
	local events = {
		{ type = "Rolled", player = "p1", dice = { 3, 4 } },
		{ type = "Moved", player = "p1", from = 5, to = 12 },
	}
	Expect.equal(DiceThrow.rollerPosition(events, 1, players), 5, "the move's start")
end

tests["a roll with no move after it is thrown from where the roller is"] = function()
	local players = { { id = "p1", position = 10 }, { id = "p2", position = 28 } }
	local jailRoll = { { type = "Rolled", player = "p1", dice = { 2, 5 } } }
	Expect.equal(DiceThrow.rollerPosition(jailRoll, 1, players), 10, "failed doubles in jail")
	local cardRoll = {
		{ type = "Moved", player = "p2", from = 22, to = 28 },
		{ type = "Rolled", player = "p2", dice = { 6, 1 }, forCard = true },
	}
	Expect.equal(DiceThrow.rollerPosition(cardRoll, 2, players), 28, "a move before the roll doesn't count")
end

tests["the surface is the top of the board centre"] = function()
	Expect.vectorNear(DiceThrow.surface().Position, Layout.ORIGIN.Position + Vector3.new(0, Layout.TILE_THICKNESS / 2, 0))
end

return tests
