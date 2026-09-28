--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Brown set: Mediterranean (1) and Baltic (3). Light blue: 6, 8, 9. Reading Railroad: 5. Electric Company: 12.
local MEDITERRANEAN, BALTIC, READING, ELECTRIC = 1, 3, 5, 12

local function brownSet(houses1: number?, houses3: number?)
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p1", MEDITERRANEAN, houses1)
	GameFixtures.own(state, "p1", BALTIC, houses3)
	return state
end

-- The rule call goes last: a call in the middle of an argument list keeps only its first result.
local function refused(label: string, expected: string, ok: boolean, reason: string?)
	assert(not ok, `{label}: allowed`)
	Expect.equal(reason, expected, label)
end

tests["house prices follow the board side"] = function()
	Expect.equal(PropertyRules.housePrice(1), 50, "brown")
	Expect.equal(PropertyRules.housePrice(11), 100, "pink")
	Expect.equal(PropertyRules.housePrice(21), 150, "red")
	Expect.equal(PropertyRules.housePrice(39), 200, "dark blue")
	assert(not pcall(PropertyRules.housePrice, READING), "railroad has a house price")
end

tests["mortgage values and unmortgage costs"] = function()
	Expect.equal(PropertyRules.mortgageValue(MEDITERRANEAN), 30, "Mediterranean")
	Expect.equal(PropertyRules.mortgageValue(READING), 100, "Reading")
	Expect.equal(PropertyRules.mortgageValue(ELECTRIC), 75, "Electric")
	Expect.equal(PropertyRules.unmortgageCost(MEDITERRANEAN), 33, "30 + 10%")
	Expect.equal(PropertyRules.unmortgageCost(ELECTRIC), 83, "75 + 10%, rounded up")
	Expect.equal(PropertyRules.unmortgageCost(READING), 110, "100 + 10%")
	Expect.equal(PropertyRules.unmortgageCost(39), 220, "200 + 10%")
end

tests["group positions list a color set"] = function()
	Expect.equal(table.concat(PropertyRules.groupPositions("LightBlue"), ","), "6,8,9")
	Expect.equal(table.concat(PropertyRules.groupPositions("DarkBlue"), ","), "37,39")
end

tests["building needs the whole set, unmortgaged, and a street"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p1", MEDITERRANEAN)
	refused("half a set", "you need the whole color set", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))
	GameFixtures.own(state, "p2", BALTIC)
	refused("other owner", "you need the whole color set", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))
	refused("not the owner", "you don't own it", PropertyRules.canBuild(state, "p2", 1500, MEDITERRANEAN))

	state = brownSet()
	assert(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "full set refused")
	state.properties[BALTIC].mortgaged = true
	refused("mortgaged", "a property in this set is mortgaged", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))

	GameFixtures.own(state, "p1", READING)
	refused("railroad", "only streets can have buildings", PropertyRules.canBuild(state, "p1", 1500, READING))
end

tests["building is even across the set"] = function()
	local state = brownSet(1, 0)
	refused("ahead", "build evenly across the set", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))
	assert(PropertyRules.canBuild(state, "p1", 1500, BALTIC), "behind refused")
	state = brownSet(5, 5)
	refused("hotel", "it already has a hotel", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))
end

tests["building costs the house price"] = function()
	local state = brownSet()
	refused("49", "not enough money", PropertyRules.canBuild(state, "p1", 49, MEDITERRANEAN))
	assert(PropertyRules.canBuild(state, "p1", 50, MEDITERRANEAN), "50 refused")
end

tests["the bank's supply limits building"] = function()
	local state = brownSet()
	state.bankHouses = 0
	refused("no houses", "the bank has no houses left", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))
	state = brownSet(4, 4)
	state.bankHouses = 0
	assert(PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN), "hotel needs no houses from the bank")
	state.bankHotels = 0
	refused("no hotels", "the bank has no hotels left", PropertyRules.canBuild(state, "p1", 1500, MEDITERRANEAN))
end

tests["selling is even across the set"] = function()
	local state = brownSet(0, 0)
	refused("nothing built", "no buildings to sell", PropertyRules.canSell(state, "p1", MEDITERRANEAN))
	state = brownSet(2, 1)
	refused("behind", "sell evenly across the set", PropertyRules.canSell(state, "p1", BALTIC))
	assert(PropertyRules.canSell(state, "p1", MEDITERRANEAN), "ahead refused")
	refused("not the owner", "you don't own it", PropertyRules.canSell(state, "p2", MEDITERRANEAN))
end

tests["selling a hotel needs 4 houses in the bank"] = function()
	local state = brownSet(5, 4)
	state.bankHouses = 3
	refused("3 houses", "the bank doesn't have 4 houses to replace the hotel", PropertyRules.canSell(state, "p1", MEDITERRANEAN))
	state.bankHouses = 4
	assert(PropertyRules.canSell(state, "p1", MEDITERRANEAN), "4 houses refused")
end

tests["mortgaging needs no buildings in the set"] = function()
	local state = brownSet(0, 1)
	refused("buildings", "sell the buildings in this set first", PropertyRules.canMortgage(state, "p1", MEDITERRANEAN))
	state = brownSet(0, 0)
	assert(PropertyRules.canMortgage(state, "p1", MEDITERRANEAN), "empty set refused")
	state.properties[MEDITERRANEAN].mortgaged = true
	refused("twice", "it is already mortgaged", PropertyRules.canMortgage(state, "p1", MEDITERRANEAN))
	GameFixtures.own(state, "p1", READING)
	assert(PropertyRules.canMortgage(state, "p1", READING), "railroad refused")
	refused("Go", "you don't own it", PropertyRules.canMortgage(state, "p1", 0))
	refused("not the owner", "you don't own it", PropertyRules.canMortgage(state, "p2", READING))
end

tests["unmortgaging needs a mortgage and the money"] = function()
	local state = brownSet()
	refused("not mortgaged", "it isn't mortgaged", PropertyRules.canUnmortgage(state, "p1", 1500, MEDITERRANEAN))
	state.properties[MEDITERRANEAN].mortgaged = true
	refused("32", "not enough money", PropertyRules.canUnmortgage(state, "p1", 32, MEDITERRANEAN))
	assert(PropertyRules.canUnmortgage(state, "p1", 33, MEDITERRANEAN), "33 refused")
	refused("not the owner", "you don't own it", PropertyRules.canUnmortgage(state, "p2", 1500, MEDITERRANEAN))
end

return tests
