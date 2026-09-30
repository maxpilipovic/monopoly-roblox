--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ORIENTAL = 6

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function bid(amount: any)
	return { type = "Bid", amount = amount }
end
local PASS = { type = "PassBid" }

-- p1 lands on Oriental Avenue and declines it.
local function declinedGame(playerCount: number, rolls: { { number } }?)
	local state = GameFixtures.newGame(playerCount, rolls or { { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	return state
end

tests["declining starts an auction with the decliner bidding first"] = function()
	local state = declinedGame(3)
	Expect.equal(state.phase, "Auction")
	Expect.equal(Engine.currentBidder(state), "p1")
	local started = GameFixtures.eventsOfType(state, "AuctionStarted")[1]
	Expect.equal(started.position, ORIENTAL, "position")
	Expect.equal(table.concat(started.bidders, ","), "p1,p2,p3", "bidders")
end

tests["bidding order starts from the decliner and wraps"] = function()
	local state = GameFixtures.newGame(3, { { 3, 4 }, { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "EndTurn" })
	act(state, "p2", { type = "Roll" })
	act(state, "p2", { type = "Decline" })
	local started = GameFixtures.eventsOfType(state, "AuctionStarted")[1]
	Expect.equal(table.concat(started.bidders, ","), "p2,p3,p1", "bidders")
end

tests["auction goes to the highest bidder"] = function()
	local state = declinedGame(3)
	act(state, "p1", bid(10))
	act(state, "p2", bid(20))
	act(state, "p3", PASS)
	act(state, "p1", PASS)
	Expect.equal(state.properties[ORIENTAL].owner, "p2")
	Expect.equal(Engine.getPlayer(state, "p2").money, 1480)
	Expect.equal(Engine.getPlayer(state, "p1").money, 1500)
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(Engine.currentPlayer(state).id, "p1", "turn stays with p1")
	local ended = GameFixtures.eventsOfType(state, "AuctionEnded")[1]
	Expect.equal(ended.winner, "p2")
	Expect.equal(ended.amount, 20)
end

tests["if everyone passes the bank keeps the property"] = function()
	local state = declinedGame(2)
	act(state, "p1", PASS)
	act(state, "p2", PASS)
	Expect.equal(state.properties[ORIENTAL], nil)
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(GameFixtures.eventsOfType(state, "AuctionEnded")[1].winner, nil)
end

tests["last bidder left can still bid"] = function()
	local state = declinedGame(3)
	act(state, "p1", PASS)
	act(state, "p2", PASS)
	Expect.equal(state.phase, "Auction", "still open for p3")
	Expect.equal(Engine.currentBidder(state), "p3")
	act(state, "p3", bid(1))
	Expect.equal(state.properties[ORIENTAL].owner, "p3")
	Expect.equal(Engine.getPlayer(state, "p3").money, 1499)
end

tests["bids must be higher, whole, and affordable"] = function()
	local state = declinedGame(2)
	act(state, "p1", bid(10))
	for _, bad in { 10, 5, 10.5, 2000, 0 / 0, math.huge, "20" } :: { any } do
		assert(not Engine.act(state, "p2", bid(bad)), `accepted bid {tostring(bad)}`)
	end
	Expect.equal(Engine.currentBidder(state), "p2", "p2 still to act")
	act(state, "p2", bid(1500))
end

tests["only the next bidder can act in an auction"] = function()
	local state = declinedGame(3)
	assert(not Engine.act(state, "p2", bid(10)), "p2 bid out of order")
	assert(not Engine.act(state, "p1", { type = "Roll" }), "rolled during auction")
	assert(not Engine.act(state, "p1", { type = "EndTurn" }), "ended turn during auction")
	act(state, "p1", bid(10))
end

tests["doubles still give another roll after an auction"] = function()
	local state = declinedGame(2, { { 3, 3 } })
	act(state, "p1", PASS)
	act(state, "p2", PASS)
	Expect.equal(state.phase, "Roll")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
end

tests["bankrupt players are left out of auctions"] = function()
	local state = GameFixtures.newGame(3, { { 2, 4 } })
	Engine.getPlayer(state, "p2").bankrupt = true
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	local started = GameFixtures.eventsOfType(state, "AuctionStarted")[1]
	Expect.equal(table.concat(started.bidders, ","), "p1,p3", "bidders")
end

tests["a refused bid or an out-of-turn pass changes nothing"] = function()
	local state = declinedGame(3)
	act(state, "p1", bid(20))
	assert(not Engine.act(state, "p2", bid(15)), "low bid accepted")
	assert(not Engine.act(state, "p3", PASS), "p3 passed out of turn")
	Expect.equal(state.auction.highBid, 20, "high bid")
	Expect.equal(state.auction.highBidder, "p1", "high bidder")
	Expect.equal(Engine.currentBidder(state), "p2", "still p2")
	Expect.equal(#state.auction.bidders, 3, "nobody dropped")
end

return tests
