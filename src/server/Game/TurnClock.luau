--!strict
-- When the acting human's decision times out. Pure: the caller passes the time, so it tests
-- without a real clock. A decision is one player in one phase; it gets a fresh deadline when it
-- starts, and again whenever that player makes a move (so raising cash in steps isn't rushed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

export type Clock = {
	key: string?, -- actor .. "|" .. phase of the decision being timed
	actor: string?, -- who the game is waiting on
	deadline: number?, -- nil = not timed (bot, timer off, game over)
}

local TurnClock = {}

function TurnClock.new(): Clock
	return { key = nil, actor = nil, deadline = nil }
end

function TurnClock.update(clock: Clock, state: Types.GameState, timerSeconds: number, now: number, actedBy: string?)
	local actor = Engine.actingPlayer(state)
	local key = if actor then `{actor}|{state.phase}` else nil
	local changed = key ~= clock.key
	clock.key = key
	clock.actor = actor
	local player = if actor then Engine.getPlayer(state, actor) else nil
	if timerSeconds <= 0 or not player or player.isBot then
		clock.deadline = nil
		return
	end
	if changed or actedBy == actor or clock.deadline == nil then
		local seconds = if state.phase == "Auction" then MatchSettings.bidSeconds(timerSeconds) else timerSeconds
		clock.deadline = now + seconds
	end
end

return TurnClock
