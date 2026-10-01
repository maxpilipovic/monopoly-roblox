--!strict
-- One match: the engine state, which events clients have already been sent, and bot turn-taking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Bot = require(script.Parent.Bot)
local Engine = require(script.Parent.Engine)
local Timeouts = require(script.Parent.Timeouts)
local Types = require(script.Parent.Types)

export type Human = {
	id: string,
	name: string,
}

export type Session = {
	state: Types.GameState,
	eventCursor: number,
	settings: MatchSettings.Settings,
	endsAt: number?, -- server time the minutes limit runs out, if there is one
}

local GameSession = {}

GameSession.MAX_TIMEOUT_STEPS = 100

function GameSession.new(
	humans: { Human },
	seats: number,
	rollDice: Types.DiceRoller,
	shuffle: Types.Shuffler?,
	settings: MatchSettings.Settings?
): Session
	local playing = math.min(#humans, Engine.MAX_PLAYERS)
	if seats ~= seats then -- NaN
		seats = Engine.MIN_PLAYERS
	end
	seats = math.clamp(math.floor(seats), math.max(playing, Engine.MIN_PLAYERS), Engine.MAX_PLAYERS)

	local infos = {}
	local nameCounts = {} -- players who share a display name become "Sam", "Sam (2)", ...
	for i = 1, playing do
		local base = humans[i].name
		nameCounts[base] = (nameCounts[base] or 0) + 1
		local name = if nameCounts[base] > 1 then `{base} ({nameCounts[base]})` else base
		table.insert(infos, { id = humans[i].id, name = name, isBot = false })
	end
	local botNumber = 0
	while #infos < seats do
		botNumber += 1
		table.insert(infos, { id = `bot{botNumber}`, name = `Bot {botNumber}`, isBot = true })
	end

	local chosen = settings or MatchSettings.validate(nil)
	return {
		state = Engine.new(infos, rollDice, shuffle, MatchSettings.roundLimit(chosen), chosen.map),
		eventCursor = 0,
		settings = chosen,
		endsAt = nil,
	}
end

function GameSession.act(session: Session, playerId: string, action: any): (boolean, string?)
	-- A player who left and rejoined spectates; the bot that took their seat keeps it.
	local player = Engine.getPlayer(session.state, playerId)
	if player and player.isBot then
		return false, "a bot is playing this seat"
	end
	return Engine.act(session.state, playerId, action)
end

-- Tried in order when a bot has no plan (or its plan is rejected), so a game never waits on a bot forever.
local FALLBACK_ACTIONS = {
	{ type = "EndTurn" },
	{ type = "PassBid" },
	{ type = "Decline" },
	{ type = "Roll" },
	{ type = "PayDebt" },
	{ type = "Bankrupt" },
	{ type = "DeclineTrade" },
}

function GameSession.takeNewEvents(session: Session): { Types.Event }
	local events = session.state.events
	local new = table.move(events, session.eventCursor + 1, #events, 1, {})
	session.eventCursor = #events
	return new
end

function GameSession.stepBot(session: Session): boolean
	local actor = Engine.actingPlayer(session.state)
	local player = actor and Engine.getPlayer(session.state, actor)
	if not player or not player.isBot then
		return false
	end
	local action = Bot.chooseAction(session.state, player.id)
	if action then
		local ok, err = Engine.act(session.state, player.id, action)
		if ok then
			return true
		end
		warn(`bot {player.id} could not {action.type}: {err}`)
	else
		warn(`bot {player.id} has no action for phase {session.state.phase}`)
	end

	for _, fallback in FALLBACK_ACTIONS do
		if Engine.act(session.state, player.id, fallback) then
			return true
		end
	end
	return false
end

local function playDefault(state: Types.GameState, playerId: string): boolean
	local action = Timeouts.defaultAction(state, playerId)
	if action and Engine.act(state, playerId, action) then
		return true
	end
	for _, fallback in FALLBACK_ACTIONS do
		if Engine.act(state, playerId, fallback) then
			return true
		end
	end
	return false
end

-- A human's timer ran out: play their safe default. A debt is settled in one go, so an absent
-- player doesn't cost everyone a full timer per mortgage; anywhere else it's one move.
function GameSession.timeout(session: Session, playerId: string): boolean
	local state = session.state
	local player = Engine.getPlayer(state, playerId)
	if not player or player.isBot or Engine.actingPlayer(state) ~= playerId then
		return false
	end
	local inDebt = state.phase == "Debt"
	if not playDefault(state, playerId) then
		return false
	end
	local steps = 1
	while
		inDebt
		and state.phase == "Debt"
		and Engine.actingPlayer(state) == playerId
		and steps < GameSession.MAX_TIMEOUT_STEPS
	do
		if not playDefault(state, playerId) then
			break
		end
		steps += 1
	end
	return true
end

function GameSession.markTimeUp(session: Session)
	Engine.markTimeUp(session.state)
end

function GameSession.replaceWithBot(session: Session, playerId: string)
	local player = Engine.getPlayer(session.state, playerId)
	-- A finished game's results stay as they ended, even if its players leave.
	if not player or player.isBot or session.state.phase == "GameOver" then
		return
	end
	player.isBot = true
	player.name = `{player.name} (bot)`
	table.insert(session.state.events, { type = "PlayerReplaced", player = playerId })
end

function GameSession.hasHumans(session: Session): boolean
	for _, player in session.state.players do
		if not player.isBot and not player.bankrupt then
			return true
		end
	end
	return false
end

function GameSession.isPlayer(session: Session, playerId: string): boolean
	return Engine.getPlayer(session.state, playerId) ~= nil
end

return GameSession
