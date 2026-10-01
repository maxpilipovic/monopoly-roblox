--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Rent = require(ServerScriptService.Server.Game.Rent)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local DeedModel = require(StarterPlayer.StarterPlayerScripts.Client.Hud.DeedModel)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function lines(deed: DeedModel.Deed): string
	local parts = {}
	for _, line in deed.lines do
		table.insert(parts, `{line.label}={line.value}`)
	end
	return table.concat(parts, "|")
end

local function current(deed: DeedModel.Deed): string
	local parts = {}
	for _, line in deed.lines do
		if line.current then
			table.insert(parts, line.label)
		end
	end
	return table.concat(parts, "|")
end

local function deedOf(position: number, state): DeedModel.Deed
	return DeedModel.of(position, if state then Snapshot.fromState(state) else nil) :: DeedModel.Deed
end

tests["a street's deed lists its price, rent table and costs"] = function()
	local deed = deedOf(39, nil)
	Expect.equal(deed.name, "Boardwalk")
	Expect.equal(deed.kind, "Property")
	Expect.equal(deed.price, 400)
	Expect.equal(deed.color, ColorGroups.DarkBlue.color)
	Expect.equal(
		lines(deed),
		"Rent=$50|With full set=$100|1 house=$200|2 houses=$600|3 houses=$1400|4 houses=$1700|Hotel=$2000"
	)
	Expect.equal(current(deed), "", "nobody owns it")
	Expect.equal(deed.owner, nil)
	Expect.equal(`{deed.footer[1].label}={deed.footer[1].value}`, "House cost=$200")
	Expect.equal(`{deed.footer[2].label}={deed.footer[2].value}`, "Mortgage value=$200")
end

tests["the rent line that applies is flagged"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 39)
	Expect.equal(current(deedOf(39, state)), "Rent", "one of the set")
	Expect.equal(deedOf(39, state).owner, "p1")
	GameFixtures.own(state, "p1", 37)
	Expect.equal(current(deedOf(39, state)), "With full set", "whole set, no houses")
	GameFixtures.own(state, "p1", 39, 2)
	Expect.equal(current(deedOf(39, state)), "2 houses")
	GameFixtures.own(state, "p1", 39, 5)
	Expect.equal(current(deedOf(39, state)), "Hotel")
	GameFixtures.own(state, "p1", 39)
	state.properties[39].mortgaged = true
	Expect.equal(current(deedOf(39, state)), "", "mortgaged earns nothing")
	Expect.equal(deedOf(39, state).mortgaged, true)
end

tests["railroads pay by how many the owner has"] = function()
	local state = GameFixtures.newGame(2)
	local unowned = deedOf(5, state)
	Expect.equal(unowned.kind, "Railroad")
	Expect.equal(unowned.color, nil)
	Expect.equal(lines(unowned), "1 owned=$25|2 owned=$50|3 owned=$100|4 owned=$200")
	Expect.equal(`{unowned.footer[1].label}={unowned.footer[1].value}`, "Mortgage value=$100")
	Expect.equal(#unowned.footer, 1, "no house cost")
	GameFixtures.own(state, "p2", 5)
	GameFixtures.own(state, "p2", 25)
	Expect.equal(current(deedOf(5, state)), "2 owned")
end

tests["utilities pay a multiple of the dice"] = function()
	local state = GameFixtures.newGame(2)
	Expect.equal(lines(deedOf(12, state)), "One owned=4× dice|Both owned=10× dice")
	GameFixtures.own(state, "p1", 12)
	Expect.equal(current(deedOf(12, state)), "One owned")
	GameFixtures.own(state, "p1", 28)
	Expect.equal(current(deedOf(28, state)), "Both owned")
end

tests["tiles that can't be owned have no deed"] = function()
	for _, position in { 0, 2, 4, 7, 10, 20, 30, 38 } do
		Expect.equal(DeedModel.of(position, nil), nil, `position {position}`)
	end
end

tests["the rent figures match the server's"] = function()
	Expect.equal(table.concat(DeedModel.RAILROAD_RENT, ","), table.concat(Rent.RAILROAD_RENT, ","))
	Expect.equal(table.concat(DeedModel.UTILITY_MULTIPLIER, ","), table.concat(Rent.UTILITY_MULTIPLIER, ","))
end

return tests
