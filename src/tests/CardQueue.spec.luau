--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local CardQueue = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardQueue)
local Expect = require(script.Parent.Expect)

local tests = {}

local function shown(queue, now: number): string?
	local card = CardQueue.current(queue, now)
	return if card then card.text else nil
end

tests["cards drawn together are shown one after another"] = function()
	local queue = CardQueue.new(5)
	CardQueue.push(queue, "Chance", "Go back 3 spaces.", 0)
	CardQueue.push(queue, "CommunityChest", "Bank error in your favor.", 0)
	Expect.equal(shown(queue, 0), "Go back 3 spaces.", "first card first")
	Expect.equal(shown(queue, 4.9), "Go back 3 spaces.", "first card for its full time")
	Expect.equal(shown(queue, 5), "Bank error in your favor.", "then the second")
	Expect.equal(shown(queue, 9.9), "Bank error in your favor.", "second card for its full time")
	Expect.equal(shown(queue, 10), nil, "then nothing")
end

tests["a card waits until its token has arrived"] = function()
	local queue = CardQueue.new(5)
	CardQueue.push(queue, "Chance", "Advance to Go.", 2)
	Expect.equal(shown(queue, 1), nil, "token still moving")
	Expect.equal(shown(queue, 2), "Advance to Go.", "shown on arrival")
	Expect.equal(shown(queue, 6.9), "Advance to Go.", "still showing")
	Expect.equal(shown(queue, 7), nil, "gone after its time")
end

tests["a card drawn later starts fresh, not in the past"] = function()
	local queue = CardQueue.new(5)
	CardQueue.push(queue, "Chance", "First.", 0)
	Expect.equal(shown(queue, 0), "First.")
	CardQueue.push(queue, "Chance", "Later.", 20)
	Expect.equal(shown(queue, 20), "Later.", "shown when drawn")
	Expect.equal(shown(queue, 24.9), "Later.", "for its full time")
	Expect.equal(CardQueue.current(queue, 20) and CardQueue.current(queue, 20).deck, "Chance", "deck kept")
end

tests["dismissing ends the card on show; the next still waits for its token"] = function()
	local queue = CardQueue.new(5)
	CardQueue.push(queue, "Chance", "first", 0)
	CardQueue.push(queue, "Chance", "second", 0)
	CardQueue.push(queue, "CommunityChest", "third", 20)
	Expect.equal(shown(queue, 1), "first")
	CardQueue.dismiss(queue, 1)
	Expect.equal(shown(queue, 1), "second", "the next card starts at once")
	Expect.equal(shown(queue, 5.9), "second", "and gets its full time")
	CardQueue.dismiss(queue, 6)
	Expect.equal(shown(queue, 6), nil, "the third's token hasn't arrived")
	CardQueue.dismiss(queue, 7)
	Expect.equal(#queue.items, 1, "dismissing with nothing showing drops nothing")
	Expect.equal(shown(queue, 20), "third")
end

tests["a queued card carries its face"] = function()
	local queue = CardQueue.new(5)
	local face = { id = "chance.go" } :: any
	CardQueue.push(queue, "Chance", "text", 0, face)
	Expect.equal((CardQueue.current(queue, 1) :: any).face, face)
end

return tests
