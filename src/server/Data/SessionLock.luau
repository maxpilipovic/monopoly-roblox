--!strict
-- One server at a time owns a player's saved data. Loading stamps `lock = { job, at }` on the record
-- (UpdateAsync), every save refreshes it, leaving clears it. Another server finding a fresh lock waits
-- for it to clear; a lock nobody has refreshed for STALE_SECONDS (a crashed server) can be taken, and
-- so can any lock once the newcomer has waited long enough. A server that has lost the lock never
-- writes again, so it can't overwrite newer data.

local SessionLock = {}

SessionLock.STALE_SECONDS = 180 -- autosave refreshes the lock every minute

export type Lock = { job: string, at: number }

local function lockOf(stored: any): Lock?
	if typeof(stored) == "table" and typeof(stored.lock) == "table" and typeof(stored.lock.job) == "string" then
		return stored.lock
	end
	return nil
end

-- Whether a server (`jobId`) loading the record may take it now ("take") or should wait ("wait").
function SessionLock.decide(stored: any, jobId: string, now: number, force: boolean): string
	local lock = lockOf(stored)
	if not lock or lock.job == jobId or force or now - (tonumber(lock.at) or 0) > SessionLock.STALE_SECONDS then
		return "take"
	end
	return "wait"
end

-- Whether `jobId` may write over the record: only while nobody else holds it.
function SessionLock.canWrite(stored: any, jobId: string): boolean
	local lock = lockOf(stored)
	return lock == nil or lock.job == jobId
end

return SessionLock
