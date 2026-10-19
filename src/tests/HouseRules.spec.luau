--!strict
-- The options a casual game's host picks: starting money, auctions and the Free Parking pot.
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function game(rules: any?, rolls: { { number } }?)
	local infos = {
		{ id = "p1", name = "Player 1", isBot = false },
		{ id = "p2", name = "Player 2", isBot = false },
	}
	return Engine.new(infos, GameFixtures.scriptedDice(rolls or {}), nil, nil, nil, rules)
end

local function eventsOf(state: any, kind: string): { any }
	return GameFixtures.eventsOfType(state, kind)
end

tests["every player starts with the room's starting money"] = function()
	local state = game({ startingMoney = 2500 })
	for _, player in state.players do
		Expect.equal(player.money, 2500)
	end
	Expect.equal(game(nil).players[1].money, Engine.STARTING_MONEY, "the standard amount without rules")
end

tests["with auctions off a declined property stays with the bank"] = function()
	local state = game({ auctions = false }, { { 1, 2 } })
	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(state.phase, "BuyDecision")
	local ok = Engine.act(state, "p1", { type = "Decline" })
	Expect.equal(ok, true)
	Expect.equal(state.phase, "EndTurn", "no auction")
	Expect.equal(state.properties[3], nil, "still the bank's")
	Expect.equal(#eventsOf(state, "PurchaseDeclined"), 1)
end

tests["with auctions on (the default) a declined property goes to auction"] = function()
	local state = game(nil, { { 1, 2 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	Expect.equal(state.phase, "Auction")
end

tests["with Free Parking on, tax goes into the pot and landing there collects it"] = function()
	local state = game({ freeParking = true }, { { 1, 3 }, { 1, 3 } })
	Engine.act(state, "p1", { type = "Roll" }) -- 0 -> 4, Income Tax $200
	Expect.equal(state.freeParkingPot, 200, "tax into the pot")
	Expect.equal(state.players[1].money, 1300)
	Engine.act(state, "p1", { type = "EndTurn" })
	state.players[2].position = 16
	Engine.act(state, "p2", { type = "Roll" }) -- 16 -> 20, Free Parking
	Expect.equal(state.players[2].money, 1700, "the pot paid out")
	Expect.equal(state.freeParkingPot, 0, "pot emptied")
	local paid = eventsOf(state, "Paid")
	Expect.equal(paid[#paid].reason, "FreeParking")
	Expect.equal(#eventsOf(state, "FreeParkingPaid"), 1)
end

tests["card payments and the jail fine fill the pot; rent and purchases don't"] = function()
	local state = game({ freeParking = true }, { { 3, 4 } })
	GameFixtures.stackDeck(state, "Chance", { "chance.speeding" })
	Engine.act(state, "p1", { type = "Roll" }) -- 0 -> 7, Chance: pay $15
	Expect.equal(state.freeParkingPot, 15, "card fine")
	local fine = game({ freeParking = true })
	fine.players[1].inJail = true
	fine.players[1].position = 10
	Engine.act(fine, "p1", { type = "PayJailFine" })
	Expect.equal(fine.freeParkingPot, Engine.JAIL_FINE, "jail fine")
	local buying = game({ freeParking = true }, { { 1, 2 } })
	Engine.act(buying, "p1", { type = "Roll" })
	Engine.act(buying, "p1", { type = "Buy" })
	Expect.equal(buying.freeParkingPot, 0, "a purchase pays the bank, not the pot")
end

tests["with Free Parking off nothing collects there"] = function()
	local state = game(nil, { { 1, 3 }, { 1, 3 } })
	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(state.freeParkingPot, 0)
	Engine.act(state, "p1", { type = "EndTurn" })
	state.players[2].position = 16
	Engine.act(state, "p2", { type = "Roll" })
	Expect.equal(state.players[2].money, 1500, "nothing paid")
end

return tests
