--!strict
-- How long a move takes to watch. The server resolves a move in an instant; clients play it out in
-- order (dice, walk, landing, card) and bots wait for that before acting again. Both sides read the
-- timings from here so neither outruns the other.

local Pacing = {}

Pacing.HOP_SECONDS = 0.26 -- one tile of a token's walk
Pacing.DICE_SECONDS = 1 -- the dice tumble and settle before the token sets off
Pacing.LAND_SECONDS = 0.6 -- a beat on the landing tile before what happens there is shown
Pacing.CARD_SECONDS = 2.6 -- time to read a drawn card before its effect plays
Pacing.BOT_THINK_SECONDS = 1 -- a bot's pause before each action, on top of what's still playing

local BOARD_TILES = 40

export type Move = { from: number, to: number, style: string? }

export type Item = {
	at: number, -- seconds after the update starts playing
	event: { [string]: any },
	pause: number?, -- Moved only: how long the token waits after its previous walk (or the start)
}

export type Landing = { at: number, player: string, position: number }

export type Timeline = {
	items: { Item },
	landings: { Landing }, -- walks that end on a tile (not jumps to jail)
	total: number, -- when the result of it all can be shown
}

-- How many hops a move takes. A jump to jail is a single hop.
function Pacing.steps(move: Move): number
	if move.style == "ToJail" then
		return 1
	end
	local direction = if move.style == "Back" then -1 else 1
	return (direction * (move.to - move.from)) % BOARD_TILES
end

function Pacing.moveSeconds(move: Move): number
	return Pacing.steps(move) * Pacing.HOP_SECONDS
end

-- When each event of an update should be shown. Only rolls, walks and cards take time; everything
-- else is shown as soon as what came before it has played.
function Pacing.timeline(events: { { [string]: any } }): Timeline
	local items: { Item } = {}
	local landings: { Landing } = {}
	local cursor = 0
	local lastArrival = 0 -- when the previous walk ended
	for _, event in events do
		local item: Item = { at = cursor, event = event }
		table.insert(items, item)
		if event.type == "Rolled" then
			cursor += Pacing.DICE_SECONDS
		elseif event.type == "Moved" then
			item.pause = cursor - lastArrival
			local arrival = cursor + Pacing.moveSeconds(event :: any)
			if event.style ~= "ToJail" then
				table.insert(landings, { at = arrival, player = event.player, position = event.to })
			end
			lastArrival = arrival
			cursor = arrival + Pacing.LAND_SECONDS
		elseif event.type == "CardDrawn" then
			cursor += Pacing.CARD_SECONDS
		end
	end
	return { items = items, landings = landings, total = cursor }
end

return Pacing
