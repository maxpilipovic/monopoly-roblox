--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local MEDITERRANEAN, BALTIC, READING = 1, 3, 5

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 owns the brown set, it's p1's turn to roll.
local function brownGame(houses1: number?, houses3: number?, rolls: { { number } }?)
	local state = GameFixtures.newGame(2, rolls)
	GameFixtures.own(state, "p1", MEDITERRANEAN, houses1)
	GameFixtures.own(state, "p1", BALTIC, houses3)
	return state
end

local function build(position: number)
	return { type = "Build", position = position }
end

tests["new games start with 32 houses and 12 hotels in the bank"] = function()
	local state = GameFixtures.newGame(2)
	Expect.equal(state.bankHouses, 32, "houses")
	Expect.equal(state.bankHotels, 12, "hotels")
	local snapshot = Snapshot.fromState(state)
	Expect.equal(snapshot.bankHouses, 32, "snapshot houses")
	Expect.equal(snapshot.bankHotels, 12, "snapshot hotels")
end

tests["building a house charges the price and takes a house from the bank"] = function()
	local state = brownGame()
	act(state, "p1", build(MEDITERRANEAN))
	Expect.equal(state.properties[MEDITERRANEAN].houses, 1, "houses")
	Expect.equal(player(state, "p1").money, 1450, "money")
	Expect.equal(state.bankHouses, 31, "bank houses")
	local built = GameFixtures.eventsOfType(state, "Built")[1]
	Expect.equal(built.position, MEDITERRANEAN, "event position")
	Expect.equal(built.amount, 50, "event amount")
	Expect.equal(built.hotel, false, "event hotel")
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[1].reason, "Building", "paid reason")
	Expect.equal(state.phase, "Roll", "still p1's roll")
end

tests["a fifth building is a hotel and returns four houses"] = function()
	local state = brownGame(4, 4)
	state.bankHouses = 24
	act(state, "p1", build(MEDITERRANEAN))
	Expect.equal(state.properties[MEDITERRANEAN].houses, 5, "hotel")
	Expect.equal(state.bankHotels, 11, "bank hotels")
	Expect.equal(state.bankHouses, 28, "houses returned")
	Expect.equal(player(state, "p1").money, 1450, "money")
	Expect.equal(GameFixtures.eventsOfType(state, "Built")[1].hotel, true, "event hotel")
end

tests["selling a house refunds half and returns it to the bank"] = function()
	local state = brownGame(1, 1)
	state.bankHouses = 30
	act(state, "p1", { type = "SellBuilding", position = BALTIC })
	Expect.equal(state.properties[BALTIC].houses, 0, "houses")
	Expect.equal(player(state, "p1").money, 1525, "money")
	Expect.equal(state.bankHouses, 31, "bank houses")
	local sold = GameFixtures.eventsOfType(state, "BuildingSold")[1]
	Expect.equal(sold.amount, 25, "event amount")
	Expect.equal(sold.hotel, false, "event hotel")
end

tests["selling a hotel returns it and takes 4 houses"] = function()
	local state = brownGame(5, 4)
	state.bankHouses = 4
	state.bankHotels = 11
	act(state, "p1", { type = "SellBuilding", position = MEDITERRANEAN })
	Expect.equal(state.properties[MEDITERRANEAN].houses, 4, "back to 4 houses")
	Expect.equal(state.bankHouses, 0, "4 houses taken")
	Expect.equal(state.bankHotels, 12, "hotel returned")
	Expect.equal(Engine.getPlayer(state, "p1").money, 1525, "half the hotel price")
	Expect.equal(GameFixtures.eventsOfType(state, "BuildingSold")[1].hotel, true, "event hotel")
end

tests["in a house shortage a hotel breaks down into what the bank has, selling the rest"] = function()
	local state = brownGame(5, 5)
	state.bankHouses = 3
	state.bankHotels = 10
	act(state, "p1", { type = "SellBuilding", position = MEDITERRANEAN })
	Expect.equal(state.properties[MEDITERRANEAN].houses, 3, "3 houses left")
	Expect.equal(state.bankHouses, 0, "the bank's 3 houses taken")
	Expect.equal(state.bankHotels, 11, "hotel returned")
	Expect.equal(Engine.getPlayer(state, "p1").money, 1550, "hotel + 1 house at $25")
	Expect.equal(GameFixtures.eventsOfType(state, "BuildingSold")[1].amount, 50, "event amount")
end

tests["mortgaging pays half the price; unmortgaging costs that plus 10%"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", READING)
	act(state, "p1", { type = "Mortgage", position = READING })
	Expect.equal(state.properties[READING].mortgaged, true, "mortgaged")
	Expect.equal(player(state, "p1").money, 1600, "paid out")
	Expect.equal(GameFixtures.eventsOfType(state, "Mortgaged")[1].amount, 100, "event amount")
	act(state, "p1", { type = "Unmortgage", position = READING })
	Expect.equal(state.properties[READING].mortgaged, false, "unmortgaged")
	Expect.equal(player(state, "p1").money, 1490, "paid 110")
	Expect.equal(GameFixtures.eventsOfType(state, "Unmortgaged")[1].amount, 110, "event amount")
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[2].reason, "Mortgage", "paid reason")
end

tests["rule violations are refused with the rule's reason"] = function()
	local state = brownGame(1, 0)
	local ok, err = Engine.act(state, "p1", build(MEDITERRANEAN))
	assert(not ok, "built unevenly")
	Expect.equal(err, "build evenly across the set")
	ok, err = Engine.act(state, "p1", { type = "Mortgage", position = BALTIC })
	assert(not ok, "mortgaged with buildings in the set")
	Expect.equal(err, "sell the buildings in this set first")
end

tests["property actions work after moving, in the EndTurn phase"] = function()
	local state = brownGame(nil, nil, { { 3, 4 } }) -- 7: Chance, dividend (money-only)
	act(state, "p1", { type = "Roll" })
	Expect.equal(state.phase, "EndTurn")
	act(state, "p1", build(MEDITERRANEAN))
	Expect.equal(state.properties[MEDITERRANEAN].houses, 1)
end

tests["property actions only on your own turn, never mid-decision"] = function()
	local state = brownGame(nil, nil, { { 2, 4 } }) -- 6: Oriental Avenue, unowned
	local ok, err = Engine.act(state, "p2", { type = "Mortgage", position = MEDITERRANEAN })
	assert(not ok, "p2 acted on p1's turn")
	Expect.equal(err, "not your turn")
	act(state, "p1", { type = "Roll" })
	Expect.equal(state.phase, "BuyDecision")
	assert(not Engine.act(state, "p1", build(MEDITERRANEAN)), "built during a buy decision")
	act(state, "p1", { type = "Decline" })
	Expect.equal(state.phase, "Auction")
	assert(not Engine.act(state, "p1", build(MEDITERRANEAN)), "built during an auction")
	Expect.equal(state.properties[MEDITERRANEAN].houses, 0, "nothing built")
end

tests["garbage positions are rejected without changing anything"] = function()
	local state = brownGame()
	GameFixtures.own(state, "p1", READING)
	local eventCount = #state.events
	-- nil can't sit in a table literal (iteration would skip it), so it gets its own check.
	for _, kind in { "Build", "SellBuilding", "Mortgage", "Unmortgage" } do
		local ok, err = Engine.act(state, "p1", { type = kind })
		assert(not ok, `{kind} accepted a missing position`)
		Expect.equal(err, "invalid position", `{kind} nil`)
		for _, bad in { "1", 1.5, -1, 40, 0 / 0, math.huge } :: { any } do
			ok, err = Engine.act(state, "p1", { type = kind, position = bad })
			assert(not ok, `{kind} accepted {tostring(bad)}`)
			Expect.equal(err, "invalid position", `{kind} {tostring(bad)}`)
		end
	end
	local ok = Engine.act(state, "p1", build(7)) -- Chance
	assert(not ok, "built on Chance")
	Expect.equal(#state.events, eventCount, "no events")
	Expect.equal(player(state, "p1").money, 1500, "money unchanged")
	Expect.equal(state.bankHouses, 32, "bank unchanged")
end

tests["rent follows the houses you build"] = function()
	local state = brownGame(nil, nil, { { 3, 4 }, { 1, 2 } })
	act(state, "p1", build(MEDITERRANEAN))
	act(state, "p1", build(BALTIC))
	act(state, "p1", build(MEDITERRANEAN))
	act(state, "p1", { type = "Roll" }) -- 7, dividend
	act(state, "p1", { type = "EndTurn" })
	player(state, "p2").position = 38
	act(state, "p2", { type = "Roll" }) -- 38 + 3 = 1, Mediterranean with 2 houses
	Expect.equal(player(state, "p2").money, 1500 + 200 - 30, "Go, then 2-house rent")
end

return tests
