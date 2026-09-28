--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 starts on `from` and rolls onto a card tile whose deck has `cardId` on top.
-- Chance is at 7, 22, 36; Community Chest at 2, 17, 33.
local function drawAt(from: number, rolls: { { number } }, deck: string, cardId: string, playerCount: number?)
	local state = GameFixtures.newGame(playerCount or 2, rolls)
	player(state, "p1").position = from
	GameFixtures.stackDeck(state, deck, { cardId })
	act(state, "p1", ROLL)
	return state
end

tests["a drawn card is announced and goes to the bottom of its deck"] = function()
	local state = drawAt(4, { { 1, 2 } }, "Chance", "chance.loan")
	local drawn = GameFixtures.eventsOfType(state, "CardDrawn")[1]
	Expect.equal(drawn.card, "chance.loan", "card")
	Expect.equal(drawn.deck, "Chance", "deck")
	Expect.equal(drawn.player, "p1", "player")
	Expect.equal(player(state, "p1").money, 1650, "collected")
	Expect.equal(state.decks.Chance[#state.decks.Chance], "chance.loan", "bottom of the deck")
	Expect.equal(#state.decks.Chance, 16, "deck size")
	Expect.equal(state.phase, "EndTurn")
end

tests["pay cards charge the bank"] = function()
	local state = drawAt(14, { { 1, 2 } }, "CommunityChest", "chest.doctor")
	Expect.equal(player(state, "p1").money, 1450)
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[1].reason, "Card")
end

tests["advancing past Go collects $200 and resolves the new tile"] = function()
	local state = drawAt(33, { { 1, 2 } }, "Chance", "chance.stCharles") -- 36 -> 11
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 11, "position")
	Expect.equal(p1.money, 1700, "Go salary")
	Expect.equal(state.phase, "BuyDecision", "offered St. Charles Place")
	local moved = GameFixtures.eventsOfType(state, "Moved")[2]
	Expect.equal(moved.style, "Walk", "style")
	assert(moved.passedGo, "passedGo")
end

tests["advancing without passing Go collects nothing"] = function()
	local state = drawAt(4, { { 1, 2 } }, "Chance", "chance.illinois") -- 7 -> 24
	Expect.equal(player(state, "p1").position, 24)
	Expect.equal(player(state, "p1").money, 1500)
	Expect.equal(state.phase, "BuyDecision")
end

tests["go back 3 hops backward and resolves the new tile, even another card"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	player(state, "p1").position = 33
	GameFixtures.stackDeck(state, "Chance", { "chance.back3" })
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.bankError" })
	act(state, "p1", ROLL) -- 36 Chance -> back to 33 Community Chest
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 33, "position")
	Expect.equal(p1.money, 1700, "bank error collected once")
	local moved = GameFixtures.eventsOfType(state, "Moved")[2]
	Expect.equal(moved.style, "Back", "style")
	Expect.equal(moved.passedGo, false, "no Go going backwards")
	Expect.equal(#GameFixtures.eventsOfType(state, "CardDrawn"), 2, "two cards")
	Expect.equal(state.phase, "EndTurn")
end

tests["the go to jail card ends the turn even after doubles"] = function()
	local state = drawAt(5, { { 1, 1 } }, "Chance", "chance.jail")
	local p1 = player(state, "p1")
	assert(p1.inJail, "not in jail")
	Expect.equal(p1.position, 10, "position")
	Expect.equal(p1.money, 1500, "no Go salary")
	Expect.equal(GameFixtures.eventsOfType(state, "SentToJail")[1].reason, "Card")
	Expect.equal(state.phase, "EndTurn")
end

tests["doubles still earn another roll after a card that doesn't jail"] = function()
	local state = drawAt(5, { { 1, 1 } }, "Chance", "chance.dividend")
	Expect.equal(state.phase, "Roll")
end

tests["nearest railroad: pay twice the rent, passing Go if needed"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	player(state, "p1").position = 4
	GameFixtures.own(state, "p2", 15)
	GameFixtures.stackDeck(state, "Chance", { "chance.railroad1" })
	act(state, "p1", ROLL) -- 7 -> Pennsylvania Railroad (15)
	Expect.equal(player(state, "p1").position, 15, "position")
	Expect.equal(player(state, "p1").money, 1450, "paid 2 x 25")
	Expect.equal(player(state, "p2").money, 1550, "owner paid")

	state = drawAt(33, { { 1, 2 } }, "Chance", "chance.railroad2") -- 36 -> Reading Railroad (5)
	Expect.equal(player(state, "p1").position, 5, "wrapped position")
	Expect.equal(player(state, "p1").money, 1700, "Go salary")
	Expect.equal(state.phase, "BuyDecision", "unowned: offered as usual")
end

tests["nearest utility: roll again and pay ten times the roll"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 }, { 4, 5 } })
	player(state, "p1").position = 19
	GameFixtures.own(state, "p2", 28)
	GameFixtures.stackDeck(state, "Chance", { "chance.utility" })
	act(state, "p1", ROLL) -- 22 -> Water Works (28)
	Expect.equal(player(state, "p1").position, 28, "position")
	Expect.equal(player(state, "p1").money, 1410, "paid 10 x 9")
	local rolls = GameFixtures.eventsOfType(state, "Rolled")
	Expect.equal(#rolls, 2, "rolled for the card")
	assert(rolls[2].forCard, "second roll is for the card")
	Expect.equal((state.lastRoll :: { number })[1], 1, "lastRoll untouched")
end

tests["pay each player skips bankrupt players"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p3").bankrupt = true
	player(state, "p1").position = 4
	GameFixtures.stackDeck(state, "Chance", { "chance.chairman" })
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").money, 1450, "paid one player")
	Expect.equal(player(state, "p2").money, 1550, "p2")
	Expect.equal(player(state, "p3").money, 1500, "bankrupt p3")
end

tests["collect from each player"] = function()
	local state = drawAt(14, { { 1, 2 } }, "CommunityChest", "chest.birthday", 3)
	Expect.equal(player(state, "p1").money, 1520, "p1")
	Expect.equal(player(state, "p2").money, 1490, "p2")
	Expect.equal(player(state, "p3").money, 1490, "p3")
end

tests["repairs charge per house and per hotel"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	player(state, "p1").position = 14
	GameFixtures.own(state, "p1", 1, 2) -- 2 houses
	GameFixtures.own(state, "p1", 3, 5) -- hotel
	GameFixtures.own(state, "p2", 6, 4) -- someone else's houses
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.streetRepairs" })
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").money, 1500 - (2 * 40 + 115))
end

tests["a Get Out of Jail Free card is kept, then used and returned to its deck"] = function()
	local state = drawAt(4, { { 1, 2 } }, "Chance", "chance.jailFree")
	local p1 = player(state, "p1")
	Expect.equal(p1.jailCards[1], "chance.jailFree", "held")
	Expect.equal(#state.decks.Chance, 15, "out of the deck")
	assert(not table.find(state.decks.Chance, "chance.jailFree"), "still in the deck")

	-- Next turn p1 starts in jail.
	p1.inJail = true
	p1.position = Engine.JAIL_POSITION
	state.phase = "Roll"
	act(state, "p1", { type = "UseJailCard" })
	assert(not p1.inJail, "still in jail")
	Expect.equal(#p1.jailCards, 0, "card used")
	Expect.equal(state.decks.Chance[16], "chance.jailFree", "back at the bottom of Chance")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Card")
	Expect.equal(state.phase, "Roll", "still has to roll")
end

tests["using a jail card needs one, and needs to be in jail"] = function()
	local state = GameFixtures.newGame(2)
	assert(not Engine.act(state, "p1", { type = "UseJailCard" }), "used while free")
	player(state, "p1").inJail = true
	local ok, err = Engine.act(state, "p1", { type = "UseJailCard" })
	assert(not ok, "used without a card")
	Expect.equal(err, "no Get Out of Jail Free card")
end

tests["new games shuffle each deck with the given shuffler"] = function()
	local shuffled = {}
	local state = Engine.new({
		{ id = "a", name = "A", isBot = false },
		{ id = "b", name = "B", isBot = false },
	}, GameFixtures.scriptedDice({}), function(ids)
		table.insert(shuffled, #ids)
		table.clear(ids)
		table.insert(ids, "chance.dividend")
	end)
	Expect.equal(#shuffled, 2, "both decks shuffled")
	Expect.equal(state.decks.Chance[1], "chance.dividend", "shuffler's order kept")
	local unshuffled = GameFixtures.newGame(2)
	Expect.equal(unshuffled.decks.Chance[1], Cards.idsFor("Chance")[1], "no shuffler: listed order")
end

return tests
