--!strict
-- Drawn cards waiting to be shown: each gets its own few seconds on screen, in draw order, and
-- none appears before its token has reached the card tile.

export type Card = {
	deck: string,
	text: string,
	notBefore: number, -- earliest time it may appear
}

export type Queue = {
	seconds: number,
	items: { Card },
	freeAt: number, -- when the card before the head finished showing
}

local CardQueue = {}

function CardQueue.new(seconds: number): Queue
	return { seconds = seconds, items = {}, freeAt = -math.huge }
end

function CardQueue.push(queue: Queue, deck: string, text: string, notBefore: number)
	table.insert(queue.items, { deck = deck, text = text, notBefore = notBefore })
end

-- The card to show at `now`, or nil; drops cards whose time is over.
function CardQueue.current(queue: Queue, now: number): Card?
	while queue.items[1] do
		local head = queue.items[1]
		local start = math.max(head.notBefore, queue.freeAt)
		if now < start then
			return nil
		elseif now < start + queue.seconds then
			return head
		end
		queue.freeAt = start + queue.seconds
		table.remove(queue.items, 1)
	end
	return nil
end

return CardQueue
