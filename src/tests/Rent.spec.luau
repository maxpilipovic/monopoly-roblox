--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Rent = require(ServerScriptService.Server.Game.Rent)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Board positions used below
local ORIENTAL, VERMONT, CONNECTICUT = 6, 8, 9 -- LightBlue, base rents 6, 6, 8
local PARK_PLACE, BOARDWALK = 37, 39
local READING, PENNSYLVANIA_RR, BO_RR, SHORT_LINE = 5, 15, 25, 35
local ELECTRIC, WATER_WORKS = 12, 28

tests["unowned or mortgaged tiles have no rent"] = function()
	local state = GameFixtures.bareState(2)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 0, "unowned")
	GameFixtures.own(state, "p2", ORIENTAL)
	state.properties[ORIENTAL].mortgaged = true
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 0, "mortgaged")
end

tests["base rent doubles when the owner has the whole color group"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", ORIENTAL)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 6, "single lot")
	GameFixtures.own(state, "p2", VERMONT)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 6, "two of three")
	GameFixtures.own(state, "p2", CONNECTICUT)
	Expect.equal(Rent.calculate(state, ORIENTAL, 7), 12, "full group")
	Expect.equal(Rent.calculate(state, CONNECTICUT, 7), 16, "full group, other lot")
	assert(Rent.ownsGroup(state, "p2", "LightBlue"), "ownsGroup")
	assert(not Rent.ownsGroup(state, "p1", "LightBlue"), "ownsGroup other player")
end

tests["houses and hotels use the rent table"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", PARK_PLACE, 0)
	GameFixtures.own(state, "p2", BOARDWALK, 3)
	Expect.equal(Rent.calculate(state, BOARDWALK, 7), 1400, "3 houses")
	state.properties[BOARDWALK].houses = 5
	Expect.equal(Rent.calculate(state, BOARDWALK, 7), 2000, "hotel")
end

tests["railroad rent doubles for each railroad owned"] = function()
	local state = GameFixtures.bareState(2)
	local expected = { 25, 50, 100, 200 }
	for count, position in { READING, PENNSYLVANIA_RR, BO_RR, SHORT_LINE } do
		GameFixtures.own(state, "p2", position)
		Expect.equal(Rent.calculate(state, READING, 7), expected[count], `{count} railroads`)
	end
end

tests["utility rent is 4x the dice, or 10x with both utilities"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p2", ELECTRIC)
	Expect.equal(Rent.calculate(state, ELECTRIC, 7), 28, "one utility")
	GameFixtures.own(state, "p2", WATER_WORKS)
	Expect.equal(Rent.calculate(state, ELECTRIC, 7), 70, "both utilities")
end

return tests
