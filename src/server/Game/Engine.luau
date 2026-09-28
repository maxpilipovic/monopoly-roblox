--!strict
-- Monopoly rules as state transitions. The server keeps one GameState per match and feeds it
-- player actions through Engine.act; every change is recorded in state.events for clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Rent = require(script.Parent.Rent)
local Types = require(script.Parent.Types)

type GameState = Types.GameState
type Player = Types.Player

export type PlayerInfo = {
	id: string,
	name: string,
	isBot: boolean,
}

local Engine = {}

Engine.STARTING_MONEY = 1500
Engine.GO_SALARY = 200
Engine.MIN_PLAYERS = 2
Engine.MAX_PLAYERS = 6

local PURCHASABLE = { Property = true, Railroad = true, Utility = true }

local function emit(state: GameState, event: Types.Event)
	table.insert(state.events, event)
end

function Engine.getPlayer(state: GameState, id: string): Player?
	for _, player in state.players do
		if player.id == id then
			return player
		end
	end
	return nil
end

function Engine.currentPlayer(state: GameState): Player
	return state.players[state.currentIndex]
end

-- Moves money between players; a nil side is the bank.
local function transfer(state: GameState, fromId: string?, toId: string?, amount: number, reason: string)
	if fromId then
		(Engine.getPlayer(state, fromId) :: Player).money -= amount
	end
	if toId then
		(Engine.getPlayer(state, toId) :: Player).money += amount
	end
	emit(state, { type = "Paid", from = fromId, to = toId, amount = amount, reason = reason })
end

local function rolledDoubles(state: GameState): boolean
	local roll = state.lastRoll
	return roll ~= nil and roll[1] == roll[2]
end

-- Called once everything caused by landing is settled.
local function finishMove(state: GameState)
	state.phase = if rolledDoubles(state) then "Roll" else "EndTurn"
end

local function resolveLanding(state: GameState, player: Player)
	local tile = Tiles.at(player.position)

	if PURCHASABLE[tile.kind] then
		local ownership = state.properties[tile.position]
		if not ownership then
			state.phase = "BuyDecision"
			emit(state, { type = "OfferedPurchase", player = player.id, position = tile.position })
			return
		end
		if ownership.owner ~= player.id then
			local roll = state.lastRoll :: { number }
			local rent = Rent.calculate(state, tile.position, roll[1] + roll[2])
			if rent > 0 then
				transfer(state, player.id, ownership.owner, rent, "Rent")
			end
		end
	elseif tile.kind == "Tax" then
		transfer(state, player.id, nil, tile.amount :: number, "Tax")
	end

	finishMove(state)
end

local function roll(state: GameState, player: Player)
	local a, b = state.rollDice()
	state.lastRoll = { a, b }
	emit(state, { type = "Rolled", player = player.id, dice = { a, b } })

	local from = player.position
	local steps = from + a + b
	player.position = steps % Tiles.COUNT
	local passedGo = steps >= Tiles.COUNT
	emit(state, { type = "Moved", player = player.id, from = from, to = player.position, passedGo = passedGo })
	if passedGo then
		transfer(state, nil, player.id, Engine.GO_SALARY, "Go")
	end

	resolveLanding(state, player)
end

local function buy(state: GameState, player: Player): (boolean, string?)
	local tile = Tiles.at(player.position)
	local price = tile.price :: number
	if player.money < price then
		return false, "not enough money"
	end
	transfer(state, player.id, nil, price, "Purchase")
	state.properties[tile.position] = { owner = player.id, houses = 0, mortgaged = false }
	emit(state, { type = "Bought", player = player.id, position = tile.position, price = price })
	finishMove(state)
	return true
end

function Engine.currentBidder(state: GameState): string?
	local auction = state.auction
	return if auction then auction.bidders[auction.nextBidder] else nil
end

-- Whoever the game is waiting on: the bidder during an auction, otherwise the current player.
function Engine.actingPlayer(state: GameState): string?
	if state.phase == "GameOver" then
		return nil
	elseif state.phase == "Auction" then
		return Engine.currentBidder(state)
	end
	return Engine.currentPlayer(state).id
end

local function startAuction(state: GameState, position: number)
	-- Everyone still in the game bids, starting with the player who declined.
	local bidders = {}
	for offset = 0, #state.players - 1 do
		local player = state.players[(state.currentIndex - 1 + offset) % #state.players + 1]
		if not player.bankrupt then
			table.insert(bidders, player.id)
		end
	end
	state.auction = { position = position, highBid = 0, highBidder = nil, bidders = bidders, nextBidder = 1 }
	state.phase = "Auction"
	emit(state, { type = "AuctionStarted", position = position, bidders = table.clone(bidders) })
end

local function endAuctionIfSettled(state: GameState)
	local auction = state.auction :: Types.Auction
	local settled = #auction.bidders == 0 or (#auction.bidders == 1 and auction.bidders[1] == auction.highBidder)
	if not settled then
		return
	end

	state.auction = nil
	local winner = auction.highBidder
	if winner then
		transfer(state, winner, nil, auction.highBid, "Auction")
		state.properties[auction.position] = { owner = winner, houses = 0, mortgaged = false }
	end
	emit(state, { type = "AuctionEnded", position = auction.position, winner = winner, amount = auction.highBid })
	finishMove(state)
end

local function placeBid(state: GameState, player: Player, amount: any): (boolean, string?)
	local auction = state.auction :: Types.Auction
	-- amount ~= amount catches NaN; infinity fails the whole-number check (inf % 1 is NaN).
	if typeof(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount <= auction.highBid then
		return false, `bid must be a whole number above {auction.highBid}`
	end
	if amount > player.money then
		return false, "not enough money"
	end
	auction.highBid = amount
	auction.highBidder = player.id
	emit(state, { type = "BidPlaced", player = player.id, amount = amount })
	auction.nextBidder = auction.nextBidder % #auction.bidders + 1
	endAuctionIfSettled(state)
	return true
end

local function passBid(state: GameState, player: Player)
	local auction = state.auction :: Types.Auction
	table.remove(auction.bidders, auction.nextBidder)
	emit(state, { type = "BidPassed", player = player.id })
	if auction.nextBidder > #auction.bidders then
		auction.nextBidder = 1
	end
	endAuctionIfSettled(state)
end

local function endTurn(state: GameState)
	state.lastRoll = nil
	for _ = 1, #state.players do
		state.currentIndex = state.currentIndex % #state.players + 1
		if not Engine.currentPlayer(state).bankrupt then
			break
		end
	end
	state.phase = "Roll"
	emit(state, { type = "TurnStarted", player = Engine.currentPlayer(state).id })
end

function Engine.new(players: { PlayerInfo }, rollDice: Types.DiceRoller): GameState
	assert(
		#players >= Engine.MIN_PLAYERS and #players <= Engine.MAX_PLAYERS,
		`a game needs {Engine.MIN_PLAYERS}-{Engine.MAX_PLAYERS} players, got {#players}`
	)

	local seen = {}
	local playerStates = {}
	for _, info in players do
		assert(not seen[info.id], `duplicate player id {info.id}`)
		seen[info.id] = true
		table.insert(playerStates, {
			id = info.id,
			name = info.name,
			isBot = info.isBot,
			money = Engine.STARTING_MONEY,
			position = 0,
			bankrupt = false,
		})
	end

	local state: GameState = {
		players = playerStates,
		currentIndex = 1,
		phase = "Roll",
		properties = {},
		lastRoll = nil,
		auction = nil,
		events = {},
		rollDice = rollDice,
	}
	emit(state, { type = "TurnStarted", player = playerStates[1].id })
	return state
end

function Engine.act(state: GameState, playerId: string, action: Types.Action): (boolean, string?)
	if typeof(action) ~= "table" or typeof(action.type) ~= "string" then
		return false, "invalid action"
	end
	if state.phase == "GameOver" then
		return false, "the game is over"
	end
	local player = Engine.getPlayer(state, playerId)
	if not player or player.bankrupt then
		return false, "not in this game"
	end

	if state.phase == "Auction" then
		if Engine.currentBidder(state) ~= playerId then
			return false, "not your turn to bid"
		elseif action.type == "Bid" then
			return placeBid(state, player, action.amount)
		elseif action.type == "PassBid" then
			passBid(state, player)
			return true
		end
		return false, "an auction is in progress"
	end

	if Engine.currentPlayer(state).id ~= playerId then
		return false, "not your turn"
	end

	if action.type == "Roll" and state.phase == "Roll" then
		roll(state, player)
		return true
	elseif action.type == "Buy" and state.phase == "BuyDecision" then
		return buy(state, player)
	elseif action.type == "Decline" and state.phase == "BuyDecision" then
		startAuction(state, player.position)
		return true
	elseif action.type == "EndTurn" and state.phase == "EndTurn" then
		endTurn(state)
		return true
	end
	return false, `can't {action.type} now`
end

return Engine
