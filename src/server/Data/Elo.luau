--!strict
-- Rating changes at the end of a game, by finishing place. Every pair of players is a chess game:
-- finishing above someone is a win against them, below a loss, the same place a draw. Each pairing
-- is ordinary Elo with the player's K shared out over the table, so a bigger game moves ratings about
-- as much as a duel. Bots are fixed opponents: they count, but don't change.

export type Entry = { id: string, rating: number, isBot: boolean?, k: number? } -- k: this player's K-factor (Ranks.kFactor)

local Elo = {}

Elo.K = 32

local function expected(rating: number, against: number): number
	return 1 / (1 + 10 ^ ((against - rating) / 400))
end

-- `places`: id -> finishing place (1 is best). Without it nobody's rating moves.
function Elo.changes(entries: { Entry }, places: { [string]: number }?): { [string]: number }
	local changes: { [string]: number } = {}
	local count = #entries
	for _, entry in entries do
		if entry.isBot then
			continue
		end
		local total = 0
		local mine = places and places[entry.id]
		if places and mine and count > 1 then
			for _, other in entries do
				local theirs = places[other.id]
				if other ~= entry and theirs then
					local score = if mine < theirs then 1 elseif mine > theirs then 0 else 0.5
					total += ((entry.k or Elo.K) / (count - 1)) * (score - expected(entry.rating, other.rating))
				end
			end
		end
		changes[entry.id] = math.round(total)
	end
	return changes
end

return Elo
