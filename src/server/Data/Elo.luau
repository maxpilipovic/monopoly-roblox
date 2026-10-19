--!strict
-- Rating changes at the end of a game. The winner is scored as beating everyone; everyone else draws
-- with each other. Each pairing is ordinary Elo with K shared out over the table, so a bigger game
-- moves ratings about as much as a duel. Bots are fixed opponents: they count, but don't change.

export type Entry = { id: string, rating: number, isBot: boolean?, k: number? } -- k: this player's K-factor (Ranks.kFactor)

local Elo = {}

Elo.K = 32

local function expected(rating: number, against: number): number
	return 1 / (1 + 10 ^ ((against - rating) / 400))
end

function Elo.changes(entries: { Entry }, winnerId: string?): { [string]: number }
	local changes: { [string]: number } = {}
	local count = #entries
	for _, entry in entries do
		if entry.isBot then
			continue
		end
		local total = 0
		if winnerId and count > 1 then
			for _, other in entries do
				if other ~= entry then
					local score = if entry.id == winnerId then 1 elseif other.id == winnerId then 0 else 0.5
					total += ((entry.k or Elo.K) / (count - 1)) * (score - expected(entry.rating, other.rating))
				end
			end
		end
		changes[entry.id] = math.round(total)
	end
	return changes
end

return Elo
