--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Throws = require(ReplicatedStorage.Shared.Dice.Throws)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["there are enough throws to look varied"] = function()
	Expect.equal(#Throws >= 20, true, `only {#Throws} throws`)
end

tests["every throw is two dice that settle in time, flat and inside the centre"] = function()
	for t, throw in Throws do
		Expect.equal(#throw, 2, `throw {t} dice`)
		Expect.equal(#throw[1], #throw[2], `throw {t}: both dice have every frame`)
		Expect.equal(#throw[1] % 7, 0, `throw {t}: whole frames`)
		local count = DiceThrow.frameCount(throw)
		Expect.equal((count - 1) / DiceThrow.FPS <= DiceThrow.MAX_SECONDS + 1e-6, true, `throw {t} lasts {(count - 1) / DiceThrow.FPS} s`)
		for d = 1, 2 do
			local last = DiceThrow.frame(throw[d], count)
			local before = DiceThrow.frame(throw[d], count - 1)
			Expect.equal(DiceThrow.tilt(last.Rotation) <= DiceThrow.MAX_TILT, true, `throw {t} die {d} rests flat`)
			Expect.equal((last.Position - before.Position).Magnitude < 0.05, true, `throw {t} die {d} is at rest`)
			Expect.equal(math.abs(last.Position.X) <= DiceThrow.BOUNDS and math.abs(last.Position.Z) <= DiceThrow.BOUNDS, true, `throw {t} die {d} inside the centre`)
		end
	end
end

tests["every throw can show every roll"] = function()
	for t, throw in Throws do
		local count = DiceThrow.frameCount(throw)
		for a = 1, 6 do
			for b = 1, 6 do
				local plan = DiceThrow.plan(throw, { a, b }, (a + b) % 4, { a % 4, b % 4 })
				Expect.equal(DiceThrow.faceUp(plan[1][count]), a, `throw {t} die 1 for {a},{b}`)
				Expect.equal(DiceThrow.faceUp(plan[2][count]), b, `throw {t} die 2 for {a},{b}`)
			end
		end
	end
end

return tests
