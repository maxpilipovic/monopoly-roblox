--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ServerScriptService.Server.Game.Types)
local Engine = require(ServerScriptService.Server.Game.Engine)
local Cards = require(game:GetService("ReplicatedStorage").Shared.Board.Cards)

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
		table.insert(players, { id = `p{i}`, name = `Player {i}`, isBot = false, money = 1500, position = 0, bankrupt = false, inJail = false, jailAttempts = 0, jailCards = {} })
	end
	return {
		players = players,
		currentIndex = 1,
		phase = "Roll",
		map = "Classic",
		properties = {},
		lastRoll = nil,
		doublesCount = 0,
		rollAgain = false,
		bankHouses = 32,
		bankHotels = 12,
		decks = { Chance = Cards.idsFor("Chance"), CommunityChest = Cards.idsFor("CommunityChest") },
		auction = nil,
		debts = {},
		resumePhase = nil,
		auctionQueue = {},
		winner = nil,
		trade = nil,
		tradeOffers = {},
		round = 1,
		roundLimit = nil,
		timeUp = false,
		winReason = nil,
		events = {},
		rollDice = GameFixtures.scriptedDice({}),
	}
end

function GameFixtures.own(state: Types.GameState, owner: string, position: number, houses: number?)
	state.properties[position] = { owner = owner, houses = houses or 0, mortgaged = false }
end

-- Puts these card ids on top of the deck, first id drawn first.
function GameFixtures.stackDeck(state: Types.GameState, deck: string, ids: { string })
	local cards = state.decks[deck]
	for i = #ids, 1, -1 do
		local index = table.find(cards, ids[i])
		assert(index, `{ids[i]} is not in the {deck} deck`)
		table.remove(cards, index)
		table.insert(cards, 1, ids[i])
	end
end

-- Puts a state straight into the Debt phase: debtorId owes amount, play resumes in the current phase.
function GameFixtures.inDebt(state: Types.GameState, debtorId: string, amount: number, creditorId: string?, reason: string?)
	state.resumePhase = state.phase
	state.phase = "Debt"
	table.insert(state.debts, { debtor = debtorId, creditor = creditorId, amount = amount, reason = reason or "Tax" })
end

function GameFixtures.side(properties: { number }?, cash: number?, jailCards: number?)
	return { properties = properties or {}, cash = cash or 0, jailCards = jailCards or 0 }
end

function GameFixtures.propose(state: Types.GameState, fromId: string, toId: string, give: any, get: any): (boolean, string?)
	return Engine.act(state, fromId, { type = "ProposeTrade", offer = { to = toId, give = give, get = get } })
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
