--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Engine = require(ServerScriptService.Server.Game.Engine)
local CrazyCards = require(ServerScriptService.Server.Game.CrazyCards)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)
local MapTestHelper = require(script.Parent.MapTestHelper)

local tests = {}

local ROLL = { type = "Roll" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- A game with Crazy Chance on. `setup` arranges the board before p1 rolls 4 -> 7 (Chance) and
-- draws `cardId` from the crazy deck; `randoms` answers the engine's random choices after the
-- first (which picks the crazy deck).
local function crazyDraw(cardId: string, setup: ((any) -> ())?, randoms: { number }?, playerCount: number?, map: string?)
	local state = GameFixtures.newGame(playerCount or 3, { { 1, 2 } }, map)
	state.rules.crazyChance = true
	local values = { 1 }
	for _, value in randoms or {} do
		table.insert(values, value)
	end
	state.random = GameFixtures.scriptedRandom(values)
	player(state, "p1").position = 4
	GameFixtures.stackDeck(state, "Crazy", { cardId })
	if setup then
		setup(state)
	end
	act(state, "p1", ROLL)
	return state
end

-- Each map's crazy deck: its size, its title and the prefix its ids share.
local CRAZY_DECKS = {
	Classic = { size = 14, title = "Crazy Chance", prefix = "crazy." },
	College = { size = 14, title = "Crazy Chance", prefix = "crazy." },
	EIU = { size = 16, title = "Crazy Night", prefix = "eiu.crazy." },
}

tests["each map's crazy deck: wild cards under the map's own title"] = function()
	for mapId, expected in CRAZY_DECKS do
		MapTestHelper.onMap(mapId, function()
			local ids = Cards.idsFor("Crazy")
			Expect.equal(#ids, expected.size, `{mapId} deck size`)
			for _, id in ids do
				local card = Cards.byId[id]
				Expect.equal(id:sub(1, #expected.prefix), expected.prefix, `{id} prefix`)
				Expect.equal(card.deck, "Crazy", `{id} deck`)
				Expect.equal(Cards.titleFor(id), expected.title, `{id} title`)
				assert(card.effect.kind ~= "JailFree", `{id} must not be kept`)
			end
			Expect.equal(#Cards.list, 32, `{mapId}: the classic decks are unchanged`)
		end)
	end
end

tests["with Crazy Chance off, every Chance draw is a Chance card"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	state.random = GameFixtures.scriptedRandom({ 1, 1, 1 })
	player(state, "p1").position = 4
	act(state, "p1", ROLL)
	Expect.equal(GameFixtures.eventsOfType(state, "CardDrawn")[1].deck, "Chance")
end

tests["with it on, one Chance draw in three is a crazy card"] = function()
	local crazy = crazyDraw("crazy.jackpot")
	Expect.equal(GameFixtures.eventsOfType(crazy, "CardDrawn")[1].deck, "Crazy", "random 1 of 3")
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	state.rules.crazyChance = true
	state.random = GameFixtures.scriptedRandom({ 2 })
	player(state, "p1").position = 4
	act(state, "p1", ROLL)
	Expect.equal(GameFixtures.eventsOfType(state, "CardDrawn")[1].deck, "Chance", "random 2 of 3")
end

tests["Community Chest is never crazy"] = function()
	local state = GameFixtures.newGame(2, { { 1, 1 } })
	state.rules.crazyChance = true
	state.random = GameFixtures.scriptedRandom({ 1 })
	player(state, "p1").position = 0 -- 0 -> 2, Community Chest
	act(state, "p1", ROLL)
	Expect.equal(GameFixtures.eventsOfType(state, "CardDrawn")[1].deck, "CommunityChest")
end

tests["swap places with the richest player, flying, no Go money"] = function()
	local state = crazyDraw("crazy.swapLeader", function(s)
		player(s, "p2").money = 3000
		player(s, "p2").position = 3
	end)
	Expect.equal(player(state, "p1").position, 3, "p1 took p2's square")
	Expect.equal(player(state, "p2").position, 7, "p2 took p1's square")
	Expect.equal(player(state, "p1").money, 1500, "no Go salary for a teleport")
	local moved = GameFixtures.eventsOfType(state, "Moved")
	Expect.equal(moved[#moved].flight, true, "flies")
	Expect.equal(state.phase, "EndTurn")
end

tests["the richest drawing swap places trades with the poorest instead"] = function()
	local state = crazyDraw("crazy.swapLeader", function(s)
		player(s, "p1").money = 5000
		player(s, "p3").money = 100
		player(s, "p3").position = 30
	end)
	Expect.equal(player(state, "p1").position, 30)
	Expect.equal(player(state, "p3").position, 7)
	Expect.equal(player(state, "p1").inJail, false, "a teleport onto Go To Jail doesn't jail")
end

tests["earthquake throws every free piece to a random square"] = function()
	local state = crazyDraw("crazy.scatter", function(s)
		player(s, "p3").inJail = true
		player(s, "p3").position = 10
	end, { 13, 26 })
	Expect.equal(player(state, "p1").position, 12, "p1 to square 12")
	Expect.equal(player(state, "p2").position, 25, "p2 to square 25")
	Expect.equal(player(state, "p3").position, 10, "the jailed piece stays put")
	Expect.equal(state.phase, "EndTurn", "nobody resolves where they land")
end

tests["reverse turns play the other way round the table"] = function()
	local state = crazyDraw("crazy.reverse")
	Expect.equal(state.direction, -1)
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(Engine.currentPlayer(state).id, "p3", "p1 -> p3")
	Expect.equal(state.round, 2, "wrapping round the table backwards starts a new round")
end

tests["extra turn lets the drawer roll again"] = function()
	local state = crazyDraw("crazy.extraTurn")
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
end

tests["Robin Hood: the richest pays the poorest $200"] = function()
	local state = crazyDraw("crazy.robinHood", function(s)
		player(s, "p2").money = 3000
		player(s, "p3").money = 400
	end)
	Expect.equal(player(state, "p2").money, 2800)
	Expect.equal(player(state, "p3").money, 600)
	Expect.equal(player(state, "p1").money, 1500)
end

tests["the lottery: everyone puts in $50, one player takes the pot"] = function()
	local state = crazyDraw("crazy.lottery", nil, { 2 })
	Expect.equal(player(state, "p1").money, 1450)
	Expect.equal(player(state, "p2").money, 1450 + 150, "p2 won the $150 pot")
	Expect.equal(player(state, "p3").money, 1450)
	Expect.equal(state.freeParkingPot, 0, "the lottery never feeds Free Parking")
end

tests["jackpot collects $500"] = function()
	local state = crazyDraw("crazy.jackpot")
	Expect.equal(player(state, "p1").money, 2000)
end

tests["split the pile: everyone's cash is shared evenly"] = function()
	local state = crazyDraw("crazy.splitCash", function(s)
		player(s, "p1").money = 1000
		player(s, "p2").money = 2000
		player(s, "p3").money = 3001
	end)
	Expect.equal(player(state, "p1").money, 2000)
	Expect.equal(player(state, "p2").money, 2000)
	Expect.equal(player(state, "p3").money, 2000, "the odd dollar goes to the bank")
end

tests["heist takes a random unbuilt property from the richest player"] = function()
	local state = crazyDraw("crazy.heist", function(s)
		player(s, "p2").money = 3000
		GameFixtures.own(s, "p2", 1)
		GameFixtures.own(s, "p2", 3)
		GameFixtures.own(s, "p2", 6, 2) -- a built street can't be taken
		GameFixtures.own(s, "p2", 8, 2)
		GameFixtures.own(s, "p2", 9, 2)
	end, { 2 })
	Expect.equal(state.properties[3].owner, "p1", "the second candidate, Baltic Avenue")
	Expect.equal(state.properties[1].owner, "p2")
	Expect.equal(state.properties[6].owner, "p2", "built set untouched")
	Expect.equal(GameFixtures.eventsOfType(state, "DeedMoved")[1].position, 3)
end

tests["heist with nothing to take does nothing"] = function()
	local state = crazyDraw("crazy.heist")
	Expect.equal(next(state.properties), nil)
	Expect.equal(state.phase, "EndTurn")
end

tests["swap deeds trades a random unbuilt property each way"] = function()
	local state = crazyDraw("crazy.swapDeed", function(s)
		GameFixtures.own(s, "p1", 5)
		GameFixtures.own(s, "p3", 12)
	end, { 1, 1, 1 })
	Expect.equal(state.properties[5].owner, "p3")
	Expect.equal(state.properties[12].owner, "p1")
end

tests["building boom puts a free house on one of your sets, or pays $100"] = function()
	local state = crazyDraw("crazy.freeHouse", function(s)
		GameFixtures.own(s, "p1", 1, 1)
		GameFixtures.own(s, "p1", 3, 0)
	end)
	Expect.equal(state.properties[3].houses, 1, "the evenly-built choice")
	Expect.equal(state.bankHouses, Engine.BANK_HOUSES - 1)
	Expect.equal(player(state, "p1").money, 1500, "free")
	local none = crazyDraw("crazy.freeHouse")
	Expect.equal(player(none, "p1").money, 1600, "no set: $100")
end

tests["demolition knocks a house off every built street"] = function()
	local state = crazyDraw("crazy.demolition", function(s)
		GameFixtures.own(s, "p2", 1, 2)
		GameFixtures.own(s, "p2", 3, 2)
		GameFixtures.own(s, "p3", 37, 5)
		GameFixtures.own(s, "p3", 39, 5)
		s.bankHouses = 20
		s.bankHotels = 10
	end)
	Expect.equal(state.properties[1].houses, 1)
	Expect.equal(state.properties[3].houses, 1)
	Expect.equal(state.properties[37].houses, 4, "a hotel drops to four houses")
	Expect.equal(state.bankHotels, 12)
	Expect.equal(state.bankHouses, 20 + 2 - 8)
end

tests["mass arrest jails everyone else; jailbreak frees everyone"] = function()
	local state = crazyDraw("crazy.massArrest")
	Expect.equal(player(state, "p1").inJail, false, "not the drawer")
	Expect.equal(player(state, "p2").inJail, true)
	Expect.equal(player(state, "p3").inJail, true)
	Expect.equal(player(state, "p2").position, Engine.JAIL_POSITION)
	Expect.equal(state.phase, "EndTurn")
	local freed = crazyDraw("crazy.jailbreak", function(s)
		player(s, "p2").inJail = true
		player(s, "p2").position = 10
	end)
	Expect.equal(player(freed, "p2").inJail, false)
end

-- crazyDraw on the EIU map, whose crazy deck has the bail-out and the block-party raid.
local function eiuDraw(cardId: string, setup: ((any) -> ())?, randoms: { number }?, playerCount: number?)
	local state
	MapTestHelper.onMap("EIU", function()
		state = crazyDraw(cardId, setup, randoms, playerCount, "EIU")
	end)
	return state
end

local function jail(state, id: string)
	player(state, id).inJail = true
	player(state, id).position = Engine.JAIL_POSITION
end

tests["bail out: pays $100 per jailed player and frees them"] = function()
	local state = eiuDraw("eiu.crazy.bailBuddy", function(s)
		jail(s, "p2")
		jail(s, "p3")
	end)
	Expect.equal(player(state, "p1").money, 1300, "two bails")
	Expect.equal(player(state, "p2").inJail, false, "p2 freed")
	Expect.equal(player(state, "p3").inJail, false, "p3 freed")
	Expect.equal(#GameFixtures.eventsOfType(state, "LeftJail"), 2, "two releases")
end

tests["bail out with nobody in jail arrests a random other player"] = function()
	local state = eiuDraw("eiu.crazy.bailBuddy", nil, { 2 })
	Expect.equal(player(state, "p3").inJail, true, "the second other player")
	Expect.equal(player(state, "p2").inJail, false)
	Expect.equal(player(state, "p1").money, 1500, "nothing paid")
end

tests["bail out it can't afford: everyone is still freed, the rest is debt"] = function()
	local state = eiuDraw("eiu.crazy.bailBuddy", function(s)
		player(s, "p1").money = 150
		jail(s, "p2")
		jail(s, "p3")
	end)
	Expect.equal(player(state, "p2").inJail, false, "p2 freed")
	Expect.equal(player(state, "p3").inJail, false, "p3 freed")
	assert(#state.debts > 0, "the unpaid bail is a debt")
	Expect.equal(state.phase, "Debt")
end

tests["raid: everyone standing on a hangout goes to jail, not those already there"] = function()
	local state = eiuDraw("eiu.crazy.blockParty", function(s)
		jail(s, "p2")
		player(s, "p3").position = 25
		player(s, "p4").position = 35
	end, nil, 4)
	Expect.equal(player(state, "p3").inJail, true, "p3 on Stu's")
	Expect.equal(player(state, "p4").inJail, true, "p4 on PBox")
	Expect.equal(player(state, "p1").inJail, false, "p1 is on Saturday Night")
	Expect.equal(#GameFixtures.eventsOfType(state, "SentToJail"), 2, "p2 isn't jailed twice")
end

tests["raid on an empty street finds nobody"] = function()
	local state = eiuDraw("eiu.crazy.blockParty")
	Expect.equal(#GameFixtures.eventsOfType(state, "SentToJail"), 0)
	Expect.equal(#GameFixtures.eventsOfType(state, "RaidFoundNobody"), 1)
end

tests["raid takes the drawer too"] = function()
	local state = GameFixtures.bareState(2)
	local drawer = player(state, "p1")
	drawer.position = 5
	local jailed = {}
	local ops = { jail = function(_, who) table.insert(jailed, who.id) end, emit = function() end }
	CrazyCards.apply(state, drawer, { kind = "RaidKind", tileKind = "Railroad" }, ops :: any)
	Expect.equal(jailed[1], "p1")
	Expect.equal(#jailed, 1)
end

return tests
