--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeRules = require(ReplicatedStorage.Shared.Rules.TradeRules)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local PARK_PLACE, BOARDWALK, READING, ELECTRIC = 37, 39, 5, 12

local function parties(): { [string]: TradeRules.Party }
	return {
		p1 = { id = "p1", name = "Player 1", money = 500, jailCards = 1, bankrupt = false, inDebt = false },
		p2 = { id = "p2", name = "Player 2", money = 300, jailCards = 0, bankrupt = false, inDebt = false },
		p3 = { id = "p3", name = "Player 3", money = 1500, jailCards = 0, bankrupt = true, inDebt = false },
	}
end

local function side(properties: { number }?, cash: number?, jailCards: number?): TradeRules.Side
	return { properties = properties or {}, cash = cash or 0, jailCards = jailCards or 0 }
end

-- p1 owns Park Place and Reading; p2 owns Boardwalk and Electric Company.
local function board()
	local state = GameFixtures.bareState(3)
	GameFixtures.own(state, "p1", PARK_PLACE)
	GameFixtures.own(state, "p1", READING)
	GameFixtures.own(state, "p2", BOARDWALK)
	GameFixtures.own(state, "p2", ELECTRIC)
	return state
end

local function check(state, offer: any, expected: string?, label: string, debtor: string?)
	local all = parties()
	if debtor then
		all[debtor].inDebt = true
	end
	local ok, err = TradeRules.validate(state, all, "p1", offer)
	if expected then
		assert(not ok, `{label}: accepted`)
		Expect.equal(err, expected, label)
	else
		assert(ok, `{label}: refused ({err})`)
	end
end

tests["a deed-for-cash offer between two players is legal"] = function()
	local state = board()
	check(state, { to = "p2", give = side({ PARK_PLACE }, 50), get = side({ BOARDWALK }) }, nil, "park + cash for boardwalk")
	check(state, { to = "p2", give = side(nil, 0, 1), get = side(nil, 10) }, nil, "jail card for cash")
end

tests["offers go to another player who is still in the game"] = function()
	local state = board()
	check(state, { to = "p1", give = side(nil, 10), get = side() }, "pick another player", "yourself")
	check(state, { to = "ghost", give = side(nil, 10), get = side() }, "pick another player", "unknown")
	check(state, { to = "p3", give = side(nil, 10), get = side() }, "that player is out of the game", "bankrupt")
end

tests["an offer must move something"] = function()
	check(board(), { to = "p2", give = side(), get = side() }, "the offer is empty", "empty")
end

tests["each side can only trade its own deeds"] = function()
	local state = board()
	check(state, { to = "p2", give = side({ BOARDWALK }), get = side() }, "you don't own Boardwalk", "give theirs")
	check(state, { to = "p2", give = side(), get = side({ PARK_PLACE }) }, "Player 2 doesn't own Park Place", "ask for yours")
	check(state, { to = "p2", give = side(), get = side({ 1 }) }, "Player 2 doesn't own Mediterranean Avenue", "unowned")
end

tests["streets in a set with buildings can't be traded; railroads and utilities always can"] = function()
	local state = board()
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3, 1)
	check(state, { to = "p2", give = side({ 1 }), get = side() }, "sell the buildings in this set first", "bare lot in a built set")
	assert(not TradeRules.tradable(state, 3), "built lot tradable")
	assert(TradeRules.tradable(state, READING), "railroad not tradable")
	assert(TradeRules.tradable(state, ELECTRIC), "utility not tradable")
	assert(TradeRules.tradable(state, PARK_PLACE), "bare set not tradable")
end

tests["cash and jail cards are limited to what each side has"] = function()
	local state = board()
	check(state, { to = "p2", give = side(nil, 501), get = side() }, "you don't have that much cash", "give cash")
	check(state, { to = "p2", give = side(), get = side(nil, 301) }, "Player 2 doesn't have that much cash", "get cash")
	check(state, { to = "p2", give = side(nil, 0, 2), get = side() }, "you don't have that many jail cards", "give cards")
	check(state, { to = "p2", give = side(nil, 10), get = side(nil, 0, 1) }, "Player 2 doesn't have that many jail cards", "get cards")
end

tests["deeds are worth their mortgage value, mortgaged or not, and jail cards $50"] = function()
	local state = board()
	Expect.equal(TradeRules.value(side({ PARK_PLACE, READING }, 20, 1)), 175 + 100 + 20 + 50)
	state.properties[PARK_PLACE].mortgaged = true
	Expect.equal(TradeRules.value(side({ PARK_PLACE })), 175, "mortgaged")
	Expect.equal(TradeRules.value(side()), 0, "empty")
end

tests["a player in debt can't give away more value than they get"] = function()
	local state = board()
	local atLeast = "while in debt you must get at least $175 in value"
	check(state, { to = "p2", give = side({ PARK_PLACE }), get = side() }, atLeast, "gift a deed", "p1")
	check(state, { to = "p2", give = side({ PARK_PLACE }), get = side(nil, 174) }, atLeast, "cheap sale", "p1")
	check(state, { to = "p2", give = side(nil, 10), get = side() }, "while in debt you must get at least $10 in value", "gift cash", "p1")
	check(state, { to = "p2", give = side({ PARK_PLACE }), get = side(nil, 175) }, nil, "sale at mortgage value", "p1")
	check(state, { to = "p2", give = side({ PARK_PLACE }), get = side({ BOARDWALK }) }, nil, "swap up", "p1")
	check(state, { to = "p2", give = side(), get = side(nil, 50) }, nil, "a gift to the debtor", "p1")
end

tests["a receiver in debt must get at least what they give"] = function()
	local state = board()
	check(state, { to = "p2", give = side(nil, 100), get = side({ BOARDWALK }) }, "Player 2 is in debt and must get at least $200 in value", "cheap buy", "p2")
	check(state, { to = "p2", give = side(nil, 0, 1), get = side(nil, 51) }, "Player 2 is in debt and must get at least $51 in value", "overpaid card", "p2")
	check(state, { to = "p2", give = side(nil, 200), get = side({ BOARDWALK }) }, nil, "fair buy", "p2")
end

tests["players not in debt can trade at any price"] = function()
	check(board(), { to = "p2", give = side({ PARK_PLACE }), get = side() }, nil, "gift")
end

tests["malformed offers are refused"] = function()
	local state = board()
	local bad: { any } = {
		5,
		{},
		{ to = "p2" },
		{ to = "p2", give = side(), get = 5 },
		{ to = "p2", give = side(nil, 0 / 0), get = side() },
		{ to = "p2", give = side(nil, -10), get = side() },
		{ to = "p2", give = side(nil, 1.5), get = side() },
		{ to = "p2", give = side(nil, math.huge), get = side() },
		{ to = "p2", give = side(nil, 0, 0.5), get = side() },
		{ to = "p2", give = { properties = "37", cash = 0, jailCards = 0 }, get = side() },
		{ to = "p2", give = side({ 37.5 }), get = side() },
		{ to = "p2", give = side({ 7 }), get = side() }, -- Chance
		{ to = "p2", give = side({ 40 }), get = side() },
		{ to = "p2", give = side({ PARK_PLACE, PARK_PLACE }), get = side() },
		{ to = "p2", give = side({ PARK_PLACE }), get = side({ PARK_PLACE }) },
		{ to = "p2", give = { properties = { x = PARK_PLACE }, cash = 0, jailCards = 0 }, get = side() },
		{ to = 5, give = side(nil, 10), get = side() },
	}
	-- nil can't sit inside a table literal, so check it on its own first.
	local ok, err = TradeRules.validate(state, parties(), "p1", nil)
	assert(not ok, "nil accepted")
	Expect.equal(err, "invalid offer", "nil")
	for i = 1, #bad do
		ok = TradeRules.validate(state, parties(), "p1", bad[i])
		assert(not ok, `bad offer #{i} accepted`)
	end
end

tests["copy keeps only the offer's fields"] = function()
	local original: any = { to = "p2", give = side({ PARK_PLACE }, 5), get = side(nil, 0, 1), extra = "x" }
	local copied: any = TradeRules.copy(original)
	Expect.equal(copied.extra, nil, "extra dropped")
	Expect.equal(copied.give.properties[1], PARK_PLACE, "properties")
	assert(copied.give.properties ~= original.give.properties, "shares the list")
	Expect.equal(copied.get.jailCards, 1, "jail cards")
end

return tests
