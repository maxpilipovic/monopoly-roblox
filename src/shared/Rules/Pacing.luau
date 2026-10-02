--!strict
-- How long a move takes to watch. The server resolves a move in an instant; clients play it out in
-- order (dice, walk, landing, card) and bots wait for that before acting again. Both sides read the
-- timings from here so neither outruns the other.

local Pacing = {}

Pacing.HOP_SECONDS = 0.26 -- one tile of a token's walk
Pacing.DICE_SECONDS = 1 -- the dice tumble and settle before the token sets off
Pacing.LAND_SECONDS = 0.6 -- a beat on the landing tile before what happens there is shown
Pacing.CARD_SECONDS = 2.6 -- time to read a drawn card before its effect plays
Pacing.JAIL_SECONDS = 2.2 -- time to read that someone is going to jail before their token jumps
Pacing.BOT_THINK_SECONDS = 1 -- a bot's pause before each action, on top of what's still playing

local BOARD_TILES = 40

export type Move = { from: number, to: number, style: string? }

export type Item = {
	at: number, -- seconds after the update starts playing
	event: { [string]: any },
	pause: number?, -- Moved only: how long the token waits after its previous walk (or the start)
}

export type Landing = { at: number, player: string, position: number }

export type Jail = { at: number, player: string, reason: string }

export type Timeline = {
	items: { Item },
	landings: { Landing }, -- walks that end on a tile (not jumps to jail)
	jails: { Jail }, -- players sent to jail, announced before the token jumps
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

-- Why the player whose jump to jail is at `index` was sent there (from the SentToJail that follows).
local function jailReason(events: { { [string]: any } }, index: number, player: string): string
	for later = index + 1, #events do
		local event = events[later]
		if event.type == "SentToJail" and event.player == player then
			return event.reason
		end
	end
	return ""
end

-- When each event of an update should be shown. Only rolls, walks and cards take time; everything
-- else is shown as soon as what came before it has played.
function Pacing.timeline(events: { { [string]: any } }): Timeline
	local items: { Item } = {}
	local landings: { Landing } = {}
	local jails: { Jail } = {}
	local cursor = 0
	local lastArrival = 0 -- when the previous walk ended
	for index, event in events do
		local item: Item = { at = cursor, event = event }
		table.insert(items, item)
		if event.type == "Rolled" then
			cursor += Pacing.DICE_SECONDS
		elseif event.type == "Moved" then
			if event.style == "ToJail" then
				-- The engine reports why only after the jump. A card that sends you there has just
				-- been read by everyone; the other ways get their own announcement first.
				local reason = jailReason(events, index, event.player)
				if reason ~= "Card" then
					table.insert(jails, { at = cursor, player = event.player, reason = reason })
					cursor += Pacing.JAIL_SECONDS
					item.at = cursor
				end
			end
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
	return { items = items, landings = landings, jails = jails, total = cursor }
end

return Pacing
