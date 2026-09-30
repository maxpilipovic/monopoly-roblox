--!strict
-- A per-key rate limit: at most one event per `seconds` for each key. Pure: the caller passes the time.

export type Throttle = {
	seconds: number,
	last: { [string]: number }, -- when each key last got through
}

local Throttle = {}

function Throttle.new(seconds: number): Throttle
	return { seconds = seconds, last = {} }
end

function Throttle.allow(throttle: Throttle, key: string, now: number): boolean
	local last = throttle.last[key]
	if last and now - last < throttle.seconds then
		return false
	end
	throttle.last[key] = now
	return true
end

function Throttle.forget(throttle: Throttle, key: string)
	throttle.last[key] = nil
end

return Throttle
