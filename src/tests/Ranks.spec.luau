--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ranks = require(ReplicatedStorage.Shared.Rules.Ranks)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["everyone starts at 1000, a Novice"] = function()
	Expect.equal(Ranks.START, 1000)
	Expect.equal(Ranks.titleFor(1000).name, "Novice")
end

tests["titles climb with rating like chess"] = function()
	Expect.equal(Ranks.titleFor(650).name, "Beginner")
	Expect.equal(Ranks.titleFor(1150).name, "Intermediate")
	Expect.equal(Ranks.titleFor(1350).name, "Advanced")
	Expect.equal(Ranks.titleFor(1550).name, "Expert")
	Expect.equal(Ranks.titleFor(1750).name, "Candidate Master")
	Expect.equal(Ranks.titleFor(1950).name, "Master")
	Expect.equal(Ranks.titleFor(2150).name, "International Master")
	Expect.equal(Ranks.titleFor(2450).name, "Grandmaster")
	Expect.equal(Ranks.titleFor(2300).short, "GM", "the boundary belongs to the higher title")
end

tests["the K-factor is high while provisional, then settles, and is small at the top"] = function()
	Expect.equal(Ranks.kFactor(0, 1000), 40)
	Expect.equal(Ranks.kFactor(Ranks.PROVISIONAL_GAMES - 1, 1000), 40)
	Expect.equal(Ranks.kFactor(Ranks.PROVISIONAL_GAMES, 1000), 20)
	Expect.equal(Ranks.kFactor(80, 2100), 10)
	Expect.equal(Ranks.isProvisional(5), true)
	Expect.equal(Ranks.isProvisional(Ranks.PROVISIONAL_GAMES), false)
end

tests["a rating change reads like a chess site's"] = function()
	Expect.equal(Ranks.changeText(1016, 16), "1016 (+16)")
	Expect.equal(Ranks.changeText(990, -10), "990 (−10)")
	Expect.equal(Ranks.changeText(1000, 0), "1000 (±0)")
end

return tests
