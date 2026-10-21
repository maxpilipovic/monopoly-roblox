--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Expect = require(script.Parent.Expect)

local tests = {}

local HOP, DICE, LAND, CARD = Pacing.HOP_SECONDS, Pacing.DICE_SECONDS, Pacing.LAND_SECONDS, Pacing.CARD_SECONDS

local function times(timeline: Pacing.Timeline): string
	local parts = {}
	for _, item in timeline.items do
		table.insert(parts, `{item.event.type}@{string.format("%.2f", item.at)}`)
	end
	return table.concat(parts, " ")
end

tests["a move takes a hop per tile, whichever way it goes"] = function()
	Expect.equal(Pacing.steps({ from = 0, to = 7 }), 7)
	Expect.equal(Pacing.steps({ from = 38, to = 3 }), 5, "past Go")
	Expect.equal(Pacing.steps({ from = 36, to = 33, style = "Back" }), 3, "backwards")
	Expect.equal(Pacing.steps({ from = 30, to = 10, style = "ToJail" }), 1, "a jump is one hop")
	Expect.near(Pacing.moveSeconds({ from = 0, to = 7 }), 7 * HOP)
end

tests["a roll plays in order: dice, then the walk, then what happened there"] = function()
	local timeline = Pacing.timeline({
		{ type = "Rolled", player = "p1", dice = { 3, 4 } },
		{ type = "Moved", player = "p1", from = 0, to = 7 },
		{ type = "CardDrawn", player = "p1", deck = "Chance", card = "chance.dividend" },
		{ type = "Paid", to = "p1", amount = 50, reason = "Card" },
	})
	local arrive = DICE + 7 * HOP
	Expect.equal(
		times(timeline),
		`Rolled@0.00 Moved@{string.format("%.2f", DICE)} CardDrawn@{string.format("%.2f", arrive + LAND)} Paid@{string.format("%.2f", arrive + LAND + CARD)}`
	)
	Expect.near(timeline.total, arrive + LAND + CARD, "the result is shown once the card has been read")
	Expect.equal(#timeline.landings, 1)
	Expect.near(timeline.landings[1].at, arrive, "landing is when the token arrives")
	Expect.equal(timeline.landings[1].player, "p1")
	Expect.equal(timeline.landings[1].position, 7)
end

tests["a card that moves the token waits to be read first"] = function()
	local timeline = Pacing.timeline({
		{ type = "Rolled", player = "p1", dice = { 3, 4 } },
		{ type = "Moved", player = "p1", from = 0, to = 7 },
		{ type = "CardDrawn", player = "p1", deck = "Chance", card = "chance.boardwalk" },
		{ type = "Moved", player = "p1", from = 7, to = 39 },
	})
	local second = DICE + 7 * HOP + LAND + CARD
	Expect.near(timeline.items[4].at, second, "second walk starts after the card")
	Expect.near(timeline.total, second + 32 * HOP + LAND)
	Expect.equal(#timeline.landings, 2)
end

tests["going to jail is announced before the token jumps, and is not a landing"] = function()
	-- The engine reports the jump first and the reason after it.
	local timeline = Pacing.timeline({
		{ type = "Rolled", player = "p1", dice = { 5, 5 } },
		{ type = "Moved", player = "p1", from = 20, to = 10, style = "ToJail" },
		{ type = "SentToJail", player = "p1", reason = "Doubles" },
	})
	local JAIL = Pacing.JAIL_SECONDS
	Expect.equal(#timeline.landings, 0)
	Expect.equal(#timeline.jails, 1)
	Expect.near(timeline.jails[1].at, DICE, "announced once the dice have settled")
	Expect.equal(timeline.jails[1].player, "p1")
	Expect.equal(timeline.jails[1].reason, "Doubles")
	Expect.near(timeline.items[2].at, DICE + JAIL, "the jump waits for the announcement")
	Expect.near(timeline.items[2].pause :: number, DICE + JAIL)
	Expect.near(timeline.total, DICE + JAIL + HOP + LAND)

	-- Walking onto Go To Jail: the walk lands first, then the announcement, then the jump.
	local walked = Pacing.timeline({
		{ type = "Rolled", player = "p2", dice = { 2, 3 } },
		{ type = "Moved", player = "p2", from = 25, to = 30 },
		{ type = "Moved", player = "p2", from = 30, to = 10, style = "ToJail" },
		{ type = "SentToJail", player = "p2", reason = "GoToJail" },
	})
	Expect.near(walked.jails[1].at, DICE + 5 * HOP + LAND)
	Expect.equal(walked.jails[1].reason, "GoToJail")
	Expect.equal(#walked.landings, 1, "the walk onto the tile still lands")
	Expect.equal(#Pacing.timeline({}).jails, 0)

	-- A card that sends you to jail has already told everyone: no second announcement.
	local carded = Pacing.timeline({
		{ type = "CardDrawn", player = "p1", deck = "Chance", card = "chance.jail" },
		{ type = "Moved", player = "p1", from = 7, to = 10, style = "ToJail" },
		{ type = "SentToJail", player = "p1", reason = "Card" },
	})
	Expect.equal(#carded.jails, 0)
	Expect.near(carded.total, Pacing.CARD_SECONDS + HOP + LAND)
end

tests["updates with nothing to watch take no time"] = function()
	Expect.near(Pacing.timeline({}).total, 0)
	local quiet = Pacing.timeline({
		{ type = "BidPlaced", player = "p1", amount = 20 },
		{ type = "Built", player = "p2", position = 1 },
		{ type = "TurnStarted", player = "p2" },
	})
	Expect.near(quiet.total, 0)
	Expect.equal(times(quiet), "BidPlaced@0.00 Built@0.00 TurnStarted@0.00")
end

tests["each walk says how long the token waits before starting"] = function()
	local timeline = Pacing.timeline({
		{ type = "Rolled", player = "p1", dice = { 3, 4 } },
		{ type = "Moved", player = "p1", from = 0, to = 7 },
		{ type = "CardDrawn", player = "p1", deck = "Chance", card = "chance.boardwalk" },
		{ type = "Moved", player = "p1", from = 7, to = 39 },
	})
	Expect.near(timeline.items[2].pause :: number, DICE, "after the dice")
	Expect.near(timeline.items[4].pause :: number, LAND + CARD, "after arriving and reading the card")
	Expect.equal(timeline.items[1].pause, nil, "only walks pause")
end

tests["the dice get time to tumble and then be read"] = function()
	Expect.near(Pacing.DICE_SECONDS, 2)
	Expect.near(Pacing.DICE_READ_SECONDS, 0.4)
	Expect.equal(Pacing.DICE_SECONDS - Pacing.DICE_READ_SECONDS >= 1.6, true, "every recorded throw settles before the read")
end

tests["the turn-order spin plays before anything else"] = function()
	local timeline = Pacing.timeline({
		{ type = "TurnOrder", order = { "p1", "p2", "p3" } },
		{ type = "TurnStarted", player = "p1" },
	})
	Expect.near(timeline.items[2].at, Pacing.turnOrderSeconds(3))
	Expect.equal(Pacing.turnOrderSeconds(4) > Pacing.turnOrderSeconds(2), true, "more players, longer spin")
end

tests["a card's flight takes the same short time however far it goes"] = function()
	local near = Pacing.moveSeconds({ from = 7, to = 11, style = "Walk", flight = true })
	local far = Pacing.moveSeconds({ from = 7, to = 39, style = "Walk", flight = true })
	Expect.near(near, Pacing.FLIGHT_SECONDS)
	Expect.near(far, Pacing.FLIGHT_SECONDS)
	assert(far < 32 * HOP, "quicker than walking 32 tiles")
end

return tests
