--!strict
-- The speed options picked in the lobby: a turn timer and an optional game length.
-- Shared so the lobby shows the same choices the server accepts.

export type Settings = {
	timer: string, -- "Off" | "Relaxed" | "Fast"
	length: string, -- "Off" | "Rounds15" | "Rounds25" | "Rounds40" | "Minutes30" | "Minutes45" | "Minutes60"
	map: string, -- "Classic" | "College"
}

local MatchSettings = {}

local TIMERS = { "Off", "Relaxed", "Fast" }
local TIMER_SECONDS = { Off = 0, Relaxed = 60, Fast = 20 }
local LENGTHS = { "Off", "Rounds15", "Rounds25", "Rounds40", "Minutes30", "Minutes45", "Minutes60" }
local ROUNDS = { Rounds15 = 15, Rounds25 = 25, Rounds40 = 40 }
local MINUTES = { Minutes30 = 30, Minutes45 = 45, Minutes60 = 60 }

-- A literal rather than Maps.IDS so this stays a leaf module; keep the two lists the same.
local MAPS = { "Classic", "College" }

MatchSettings.DEFAULT = table.freeze({ timer = "Relaxed", length = "Off", map = "Classic" }) :: Settings

local function isOneOf(value: any, options: { string }): boolean
	return typeof(value) == "string" and table.find(options, value) ~= nil
end

function MatchSettings.validate(raw: any): Settings
	local timer = if typeof(raw) == "table" and isOneOf(raw.timer, TIMERS) then raw.timer else MatchSettings.DEFAULT.timer
	local length = if typeof(raw) == "table" and isOneOf(raw.length, LENGTHS) then raw.length else MatchSettings.DEFAULT.length
	local map = if typeof(raw) == "table" and isOneOf(raw.map, MAPS) then raw.map else MatchSettings.DEFAULT.map
	return { timer = timer, length = length, map = map }
end

local function nextIn(options: { string }, id: string): string
	local index = table.find(options, id) or 0
	return options[index % #options + 1]
end

function MatchSettings.nextTimer(id: string): string
	return nextIn(TIMERS, id)
end

function MatchSettings.nextLength(id: string): string
	return nextIn(LENGTHS, id)
end

function MatchSettings.nextMap(id: string): string
	return nextIn(MAPS, id)
end

function MatchSettings.mapLabel(id: string): string
	return `Map: {id}`
end

function MatchSettings.timerLabel(id: string): string
	local seconds = TIMER_SECONDS[id]
	return if seconds and seconds > 0 then `Timer: {id} {seconds} s` else "Timer: Off"
end

function MatchSettings.lengthLabel(id: string): string
	if ROUNDS[id] then
		return `Length: {ROUNDS[id]} rounds`
	elseif MINUTES[id] then
		return `Length: {MINUTES[id]} min`
	end
	return "Length: Off"
end

function MatchSettings.timerSeconds(settings: Settings): number
	return TIMER_SECONDS[settings.timer] or 0
end

-- An auction bid gets a third of the timer, so a table of bidders doesn't take minutes.
function MatchSettings.bidSeconds(timerSeconds: number): number
	return math.ceil(timerSeconds / 3)
end

function MatchSettings.roundLimit(settings: Settings): number?
	return ROUNDS[settings.length]
end

function MatchSettings.limitMinutes(settings: Settings): number?
	return MINUTES[settings.length]
end

return MatchSettings
