--!strict
-- The ranked matchmaking queue: players wait for a Duel (2) or a Table (4) and are matched with
-- others near their rating. Each player's window starts at ±100 and widens the longer they wait;
-- two players fit if they're inside both windows. The longest-waiting player is matched first, with
-- the closest ratings that fit.

export type Entry = { id: string, elo: number, mode: string, since: number }
export type Match = { mode: string, ids: { string } }
export type Queue = { entries: { Entry } }

local RankedQueue = {}

RankedQueue.SIZES = table.freeze({ Duel = 2, Table = 4 })
RankedQueue.START_WINDOW = 100
RankedQueue.WIDEN_PER_SECOND = 5
RankedQueue.MAX_WINDOW = 600

function RankedQueue.new(): Queue
	return { entries = {} }
end

function RankedQueue.window(waited: number): number
	return math.min(RankedQueue.START_WINDOW + math.max(waited, 0) * RankedQueue.WIDEN_PER_SECOND, RankedQueue.MAX_WINDOW)
end

function RankedQueue.entryOf(q: Queue, id: string): Entry?
	for _, entry in q.entries do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function RankedQueue.leave(q: Queue, id: string)
	for index, entry in q.entries do
		if entry.id == id then
			table.remove(q.entries, index)
			return
		end
	end
end

function RankedQueue.join(q: Queue, id: string, elo: number, mode: string, now: number)
	assert(RankedQueue.SIZES[mode], `no ranked mode {mode}`)
	RankedQueue.leave(q, id)
	table.insert(q.entries, { id = id, elo = elo, mode = mode, since = now })
end

local function fits(a: Entry, b: Entry, now: number): boolean
	local gap = math.abs(a.elo - b.elo)
	return gap <= RankedQueue.window(now - a.since) and gap <= RankedQueue.window(now - b.since)
end

-- Takes every group that can be made right now out of the queue.
function RankedQueue.match(q: Queue, now: number): { Match }
	local matches: { Match } = {}
	local waiting = table.clone(q.entries)
	table.sort(waiting, function(a, b)
		return a.since < b.since
	end)
	local taken: { [string]: boolean } = {}
	for _, anchor in waiting do
		if taken[anchor.id] then
			continue
		end
		local size = RankedQueue.SIZES[anchor.mode]
		local candidates = {}
		for _, other in waiting do
			if other ~= anchor and not taken[other.id] and other.mode == anchor.mode and fits(anchor, other, now) then
				table.insert(candidates, other)
			end
		end
		table.sort(candidates, function(a, b)
			return math.abs(a.elo - anchor.elo) < math.abs(b.elo - anchor.elo)
		end)
		if #candidates < size - 1 then
			continue
		end
		local group = { anchor }
		for _, candidate in candidates do
			-- Everyone at the table must fit everyone else, not just the anchor.
			local fitsAll = true
			for _, member in group do
				if not fits(member, candidate, now) then
					fitsAll = false
				end
			end
			if fitsAll then
				table.insert(group, candidate)
			end
			if #group == size then
				break
			end
		end
		if #group == size then
			local ids = {}
			for _, member in group do
				taken[member.id] = true
				table.insert(ids, member.id)
			end
			table.insert(matches, { mode = anchor.mode, ids = ids })
		end
	end
	for id in taken do
		RankedQueue.leave(q, id)
	end
	return matches
end

return RankedQueue
