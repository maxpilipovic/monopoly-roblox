--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ServerScriptService.Server.Game.Types)
local Engine = require(ServerScriptService.Server.Game.Engine)

local GameFixtures = {}

function GameFixtures.scriptedDice(rolls: { { number } }): Types.DiceRoller
	local index = 0
	return function()
		index += 1
		local roll = rolls[index]
		assert(roll, `scripted dice ran out after {index - 1} rolls`)
		return roll[1], roll[2]
	end
end

-- A real engine game with players p1..pN and scripted dice.
function GameFixtures.newGame(playerCount: number, rolls: { { number } }?): Types.GameState
	local infos = {}
	for i = 1, playerCount do
		table.insert(infos, { id = `p{i}`, name = `Player {i}`, isBot = false })
	end
	return Engine.new(infos, GameFixtures.scriptedDice(rolls or {}))
end

-- A state with players p1..pN and no engine involvement, for testing pure helpers.
function GameFixtures.bareState(playerCount: number): Types.GameState
	local players = {}
	for i = 1, playerCount do
		table.insert(players, { id = `p{i}`, name = `Player {i}`, isBot = false, money = 1500, position = 0, bankrupt = false })
	end
	return {
		players = players,
		currentIndex = 1,
		phase = "Roll",
		properties = {},
		lastRoll = nil,
		auction = nil,
		events = {},
		rollDice = GameFixtures.scriptedDice({}),
	}
end

function GameFixtures.own(state: Types.GameState, owner: string, position: number, houses: number?)
	state.properties[position] = { owner = owner, houses = houses or 0, mortgaged = false }
end

function GameFixtures.eventsOfType(state: Types.GameState, eventType: string): { Types.Event }
	local found = {}
	for _, event in state.events do
		if event.type == eventType then
			table.insert(found, event)
		end
	end
	return found
end

return GameFixtures
