--!strict
-- One match: the engine state, which events clients have already been sent, and bot turn-taking.

local Bot = require(script.Parent.Bot)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

export type Human = {
	id: string,
	name: string,
}

export type Session = {
	state: Types.GameState,
	eventCursor: number,
}

local GameSession = {}

function GameSession.new(humans: { Human }, seats: number, rollDice: Types.DiceRoller): Session
	local playing = math.min(#humans, Engine.MAX_PLAYERS)
	if seats ~= seats then -- NaN
		seats = Engine.MIN_PLAYERS
	end
	seats = math.clamp(math.floor(seats), math.max(playing, Engine.MIN_PLAYERS), Engine.MAX_PLAYERS)

	local infos = {}
	for i = 1, playing do
		table.insert(infos, { id = humans[i].id, name = humans[i].name, isBot = false })
	end
	local botNumber = 0
	while #infos < seats do
		botNumber += 1
		table.insert(infos, { id = `bot{botNumber}`, name = `Bot {botNumber}`, isBot = true })
	end

	return { state = Engine.new(infos, rollDice), eventCursor = 0 }
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

function GameSession.replaceWithBot(session: Session, playerId: string)
	local player = Engine.getPlayer(session.state, playerId)
	if not player or player.isBot then
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

return GameSession
