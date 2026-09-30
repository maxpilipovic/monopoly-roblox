--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local TradeBuilder = require(StarterPlayer.StarterPlayerScripts.Client.Hud.TradeBuilder)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

-- p1 owns the brown set (a house on Baltic) and Reading; p2 owns Boardwalk; p3 is bankrupt.
local function game()
	local state = GameFixtures.newGame(3)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3, 1)
	GameFixtures.own(state, "p1", 5)
	GameFixtures.own(state, "p2", 39)
	Engine.getPlayer(state, "p3").bankrupt = true
	return state
end

tests["partners are the other players still in the game"] = function()
	local partners = TradeBuilder.partners(Snapshot.fromState(game()), "p1")
	Expect.equal(#partners, 1)
	Expect.equal(partners[1].id, "p2")
	Expect.equal(partners[1].name, "Player 2")
end

tests["deed rows mark selections and untradable deeds with the reason"] = function()
	local snapshot = Snapshot.fromState(game())
	local builder = TradeBuilder.new()
	TradeBuilder.setPartner(builder, "p2")
	TradeBuilder.toggle(builder, "give", 5)
	local rows = TradeBuilder.rows(snapshot, "p1", builder.give)
	Expect.equal(#rows, 3, "p1's three deeds")
	Expect.equal(rows[1].name, "Mediterranean Avenue", "sorted by position")
	Expect.equal(rows[1].tradable, false, "built set")
	Expect.equal(rows[1].reason, "sell the buildings in this set first")
	Expect.equal(rows[3].position, 5, "Reading")
	Expect.equal(rows[3].selected, true, "selected")
	Expect.equal(rows[3].tradable, true, "tradable")
	TradeBuilder.toggle(builder, "give", 5)
	Expect.equal(TradeBuilder.rows(snapshot, "p1", builder.give)[3].selected, false, "toggled off")
end

tests["cash and jail card steppers stay between 0 and what the side has"] = function()
	local builder = TradeBuilder.new()
	TradeBuilder.stepCash(builder, "get", 100, 250)
	TradeBuilder.stepCash(builder, "get", 100, 250)
	TradeBuilder.stepCash(builder, "get", 100, 250)
	Expect.equal(builder.get.cash, 250, "clamped to max")
	TradeBuilder.stepCash(builder, "get", -500, 250)
	Expect.equal(builder.get.cash, 0, "clamped to 0")
	TradeBuilder.stepJailCards(builder, "give", 1, 1)
	TradeBuilder.stepJailCards(builder, "give", 1, 1)
	Expect.equal(builder.give.jailCards, 1, "only one card held")
end

tests["check uses the trade rules, and a new partner clears the offer"] = function()
	local snapshot = Snapshot.fromState(game())
	local builder = TradeBuilder.new()
	local ok, err = TradeBuilder.check(snapshot, "p1", builder)
	assert(not ok, "no partner accepted")
	Expect.equal(err, "pick a player")
	TradeBuilder.setPartner(builder, "p2")
	ok, err = TradeBuilder.check(snapshot, "p1", builder)
	Expect.equal(err, "the offer is empty")
	TradeBuilder.toggle(builder, "get", 39)
	TradeBuilder.stepCash(builder, "give", 50, 1500)
	assert(TradeBuilder.check(snapshot, "p1", builder), "legal offer refused")
	local offer = TradeBuilder.offer(builder)
	Expect.equal(offer.to, "p2", "to")
	Expect.equal(offer.get.properties[1], 39, "get")
	Expect.equal(offer.give.cash, 50, "give cash")
	TradeBuilder.setPartner(builder, "p3")
	Expect.equal(#builder.get.properties, 0, "cleared")
	Expect.equal(builder.give.cash, 0, "cash cleared")
end

tests["check knows the player paying the open debt is in debt"] = function()
	local state = game()
	GameFixtures.inDebt(state, "p1", 1000)
	local builder = TradeBuilder.new()
	TradeBuilder.setPartner(builder, "p2")
	TradeBuilder.toggle(builder, "give", 5)
	local ok, err = TradeBuilder.check(Snapshot.fromState(state), "p1", builder)
	assert(not ok, "debtor gift accepted")
	Expect.equal(err, "while in debt you must get at least $100 in value")
end

tests["deed rows say which deeds are mortgaged"] = function()
	local state = game()
	state.properties[5].mortgaged = true
	local rows = TradeBuilder.rows(Snapshot.fromState(state), "p1", TradeBuilder.new().give)
	Expect.equal(rows[3].position, 5, "Reading")
	Expect.equal(rows[3].mortgaged, true, "mortgaged")
	Expect.equal(rows[2].mortgaged, false, "Baltic isn't")
end

tests["deeds that change hands drop out of the offer, and selected deeds can always be unpicked"] = function()
	local state = game()
	local builder = TradeBuilder.new()
	TradeBuilder.setPartner(builder, "p2")
	TradeBuilder.toggle(builder, "give", 5)
	TradeBuilder.toggle(builder, "get", 39)
	state.properties[5] = nil -- Reading went back to the bank
	TradeBuilder.prune(builder, Snapshot.fromState(state), "p1")
	Expect.equal(#builder.give.properties, 0, "Reading dropped")
	Expect.equal(builder.get.properties[1], 39, "Boardwalk kept")

	local row = { position = 1, name = "x", selected = true, mortgaged = false, tradable = false, reason = "sell the buildings in this set first" }
	assert(TradeBuilder.canToggle(row), "a selected deed can be unpicked")
	row.selected = false
	assert(not TradeBuilder.canToggle(row), "an untradable deed can't be picked")
end

return tests
