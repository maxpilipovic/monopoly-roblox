--!strict
-- Monopoly rules as state transitions. The server keeps one GameState per match and feeds it
-- player actions through Engine.act; every change is recorded in state.events for clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
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
Engine.JAIL_POSITION = 10
Engine.JAIL_FINE = 50
Engine.JAIL_MAX_ATTEMPTS = 3 -- failed doubles rolls before the fine is forced
Engine.MAX_DOUBLES = 3 -- doubles in one turn that send you to jail
Engine.BANK_HOUSES = 32
Engine.BANK_HOTELS = 12

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

local function hasDebt(state: GameState, playerId: string): boolean
	for _, debt in state.debts do
		if debt.debtor == playerId then
			return true
		end
	end
	return false
end

-- A forced payment: paid now if the payer can cover it and owes nothing else, otherwise an IOU.
local function charge(state: GameState, payer: Player, creditorId: string?, amount: number, reason: string)
	if payer.money >= amount and not hasDebt(state, payer.id) then
		transfer(state, payer.id, creditorId, amount, reason)
		return
	end
	table.insert(state.debts, { debtor = payer.id, creditor = creditorId, amount = amount, reason = reason })
	emit(state, { type = "DebtOwed", debtor = payer.id, creditor = creditorId, amount = amount, reason = reason })
end

-- The player a debt is owed to, or nil when that's the bank (a bankrupt creditor counts as the bank).
local function liveCreditor(state: GameState, creditorId: string?): Player?
	local creditor = if creditorId then Engine.getPlayer(state, creditorId) else nil
	return if creditor and not creditor.bankrupt then creditor else nil
end

-- Called once everything caused by landing is settled.
local function finishMove(state: GameState)
	state.phase = if state.rollAgain and not Engine.currentPlayer(state).inJail then "Roll" else "EndTurn"
end

-- style: "Walk" hops forward and collects Go when passing it, "Back" hops backward,
-- "ToJail" jumps straight into the jail cell.
local function moveTo(state: GameState, player: Player, to: number, style: string)
	local from = player.position
	local passedGo = style == "Walk" and to < from
	player.position = to
	emit(state, { type = "Moved", player = player.id, from = from, to = to, passedGo = passedGo, style = style })
	if passedGo then
		transfer(state, nil, player.id, Engine.GO_SALARY, "Go")
	end
end

local function sendToJail(state: GameState, player: Player, reason: string)
	moveTo(state, player, Engine.JAIL_POSITION, "ToJail")
	player.inJail = true
	player.jailAttempts = 0
	emit(state, { type = "SentToJail", player = player.id, reason = reason })
	finishMove(state)
end

local function leaveJail(state: GameState, player: Player, reason: string)
	player.inJail = false
	player.jailAttempts = 0
	emit(state, { type = "LeftJail", player = player.id, reason = reason })
end

local resolveLanding: (state: GameState, player: Player, rentRule: string?) -> ()
local resume: (state: GameState) -> ()

local function nearestAhead(from: number, kind: string): number
	for step = 1, Tiles.COUNT do
		local position = (from + step) % Tiles.COUNT
		if Tiles.at(position).kind == kind then
			return position
		end
	end
	error(`no {kind} tile on the board`)
end

local function repairCost(state: GameState, player: Player, effect: Cards.Effect): number
	local cost = 0
	for _, ownership in state.properties do
		if ownership.owner == player.id then
			cost += if ownership.houses == 5
				then effect.perHotel :: number
				else ownership.houses * (effect.perHouse :: number)
		end
	end
	return cost
end

local function applyCard(state: GameState, player: Player, effect: Cards.Effect)
	local kind = effect.kind
	if kind == "Collect" then
		transfer(state, nil, player.id, effect.amount :: number, "Card")
	elseif kind == "Pay" then
		charge(state, player, nil, effect.amount :: number, "Card")
	elseif kind == "PayEachPlayer" or kind == "CollectFromEachPlayer" then
		for _, other in state.players do
			if other ~= player and not other.bankrupt then
				if kind == "PayEachPlayer" then
					charge(state, player, other.id, effect.amount :: number, "Card")
				else
					charge(state, other, player.id, effect.amount :: number, "Card")
				end
			end
		end
	elseif kind == "Repairs" then
		local cost = repairCost(state, player, effect)
		if cost > 0 then
			charge(state, player, nil, cost, "Card")
		end
	elseif kind == "GoToJail" then
		sendToJail(state, player, "Card")
		return
	elseif kind == "AdvanceTo" then
		moveTo(state, player, effect.position :: number, "Walk")
		resolveLanding(state, player)
		return
	elseif kind == "AdvanceToNearest" then
		local tileKind = effect.tileKind :: string
		moveTo(state, player, nearestAhead(player.position, tileKind), "Walk")
		resolveLanding(state, player, if tileKind == "Railroad" then "DoubleRailroad" else "UtilityTenTimes")
		return
	elseif kind == "GoBack" then
		moveTo(state, player, (player.position - (effect.spaces :: number)) % Tiles.COUNT, "Back")
		resolveLanding(state, player)
		return
	end
	-- JailFree needs nothing more: drawCard already handed the card to the player.
	finishMove(state)
end

local function drawCard(state: GameState, player: Player, deck: string)
	local cards = state.decks[deck]
	local id = table.remove(cards, 1) :: string
	emit(state, { type = "CardDrawn", player = player.id, deck = deck, card = id })
	local card = Cards.byId[id]
	if card.effect.kind == "JailFree" then
		table.insert(player.jailCards, id) -- returns to the deck when used
	else
		table.insert(cards, id)
	end
	applyCard(state, player, card.effect)
end

-- rentRule comes from the "nearest Railroad/Utility" cards.
local function rentOwed(state: GameState, player: Player, position: number, rentRule: string?): number
	if rentRule == "UtilityTenTimes" then
		if (state.properties[position] :: Types.Ownership).mortgaged then
			return 0
		end
		local a, b = state.rollDice()
		emit(state, { type = "Rolled", player = player.id, dice = { a, b }, forCard = true })
		return (a + b) * 10
	end
	local roll = state.lastRoll :: { number }
	local rent = Rent.calculate(state, position, roll[1] + roll[2])
	return if rentRule == "DoubleRailroad" then rent * 2 else rent
end

function resolveLanding(state: GameState, player: Player, rentRule: string?)
	local tile = Tiles.at(player.position)

	if PURCHASABLE[tile.kind] then
		local ownership = state.properties[tile.position]
		if not ownership then
			state.phase = "BuyDecision"
			emit(state, { type = "OfferedPurchase", player = player.id, position = tile.position })
			return
		end
		if ownership.owner ~= player.id then
			local rent = rentOwed(state, player, tile.position, rentRule)
			if rent > 0 then
				charge(state, player, ownership.owner, rent, "Rent")
			end
		end
	elseif tile.kind == "Tax" then
		charge(state, player, nil, tile.amount :: number, "Tax")
	elseif tile.kind == "Chance" or tile.kind == "CommunityChest" then
		drawCard(state, player, tile.kind)
		return
	elseif tile.kind == "GoToJail" then
		sendToJail(state, player, "GoToJail")
		return
	end

	finishMove(state)
end

local function roll(state: GameState, player: Player)
	local a, b = state.rollDice()
	state.lastRoll = { a, b }
	emit(state, { type = "Rolled", player = player.id, dice = { a, b } })
	local doubles = a == b

	if player.inJail then
		if doubles then
			leaveJail(state, player, "Doubles")
		else
			player.jailAttempts += 1
			if player.jailAttempts < Engine.JAIL_MAX_ATTEMPTS then
				finishMove(state)
				return
			end
			charge(state, player, nil, Engine.JAIL_FINE, "JailFine")
			leaveJail(state, player, if hasDebt(state, player.id) then "FineOwed" else "Fine")
		end
		-- Getting out by the dice never earns another roll.
		state.rollAgain = false
	else
		if doubles then
			state.doublesCount += 1
			if state.doublesCount >= Engine.MAX_DOUBLES then
				sendToJail(state, player, "Doubles")
				return
			end
		end
		state.rollAgain = doubles
	end

	moveTo(state, player, (player.position + a + b) % Tiles.COUNT, "Walk")
	resolveLanding(state, player)
end

local function payJailFine(state: GameState, player: Player): (boolean, string?)
	if player.money < Engine.JAIL_FINE then
		return false, "not enough money"
	end
	transfer(state, player.id, nil, Engine.JAIL_FINE, "JailFine")
	leaveJail(state, player, "Fine")
	return true
end

local function useJailCard(state: GameState, player: Player): (boolean, string?)
	local id = table.remove(player.jailCards, 1)
	if not id then
		return false, "no Get Out of Jail Free card"
	end
	table.insert(state.decks[Cards.byId[id].deck], id)
	leaveJail(state, player, "Card")
	return true
end

local PROPERTY_ACTIONS = { Build = true, SellBuilding = true, Mortgage = true, Unmortgage = true }

local function isPosition(value: any): boolean
	-- value % 1 == 0 is false for NaN and for infinity (inf % 1 is NaN).
	return typeof(value) == "number" and value % 1 == 0 and value >= 0 and value < Tiles.COUNT
end

local function propertyAction(state: GameState, player: Player, kind: string, position: any): (boolean, string?)
	if not isPosition(position) then
		return false, "invalid position"
	end
	local ok, err
	if kind == "Build" then
		ok, err = PropertyRules.canBuild(state, player.id, player.money, position)
	elseif kind == "SellBuilding" then
		ok, err = PropertyRules.canSell(state, player.id, position)
	elseif kind == "Mortgage" then
		ok, err = PropertyRules.canMortgage(state, player.id, position)
	else
		ok, err = PropertyRules.canUnmortgage(state, player.id, player.money, position)
	end
	if not ok then
		return false, err
	end

	local ownership = state.properties[position]
	if kind == "Build" then
		-- A hotel swaps with four houses: building one returns them to the bank.
		local price = PropertyRules.housePrice(position)
		local hotel = ownership.houses == PropertyRules.HOUSES_PER_HOTEL
		if hotel then
			state.bankHotels -= 1
			state.bankHouses += PropertyRules.HOUSES_PER_HOTEL
		else
			state.bankHouses -= 1
		end
		ownership.houses += 1
		transfer(state, player.id, nil, price, "Building")
		emit(state, { type = "Built", player = player.id, position = position, amount = price, hotel = hotel })
	elseif kind == "SellBuilding" then
		local hotel = ownership.houses == PropertyRules.HOTEL
		local left, amount = PropertyRules.sale(state, position)
		if hotel then
			state.bankHotels += 1
			state.bankHouses -= left -- the houses that replace it come from the bank
		else
			state.bankHouses += 1
		end
		ownership.houses = left
		transfer(state, nil, player.id, amount, "Building")
		emit(state, { type = "BuildingSold", player = player.id, position = position, amount = amount, hotel = hotel })
	elseif kind == "Mortgage" then
		local amount = PropertyRules.mortgageValue(position)
		ownership.mortgaged = true
		transfer(state, nil, player.id, amount, "Mortgage")
		emit(state, { type = "Mortgaged", player = player.id, position = position, amount = amount })
	else
		local amount = PropertyRules.unmortgageCost(position)
		ownership.mortgaged = false
		transfer(state, player.id, nil, amount, "Mortgage")
		emit(state, { type = "Unmortgaged", player = player.id, position = position, amount = amount })
	end
	return true
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
	elseif state.phase == "Debt" then
		return state.debts[1].debtor
	elseif state.phase == "Auction" then
		return Engine.currentBidder(state)
	end
	return Engine.currentPlayer(state).id
end

local function startAuction(state: GameState, position: number, fromBankruptcy: boolean?)
	-- Everyone still in the game bids, starting with the player who declined.
	local bidders = {}
	for offset = 0, #state.players - 1 do
		local player = state.players[(state.currentIndex - 1 + offset) % #state.players + 1]
		if not player.bankrupt then
			table.insert(bidders, player.id)
		end
	end
	state.auction = { position = position, highBid = 0, highBidder = nil, bidders = bidders, nextBidder = 1, fromBankruptcy = fromBankruptcy == true }
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
	if auction.fromBankruptcy then
		resume(state)
	else
		finishMove(state)
	end
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
	state.doublesCount = 0
	state.rollAgain = false
	state.resumePhase = nil
	for _ = 1, #state.players do
		state.currentIndex = state.currentIndex % #state.players + 1
		if not Engine.currentPlayer(state).bankrupt then
			break
		end
	end
	state.phase = "Roll"
	emit(state, { type = "TurnStarted", player = Engine.currentPlayer(state).id })
end

-- Continues the game once a debt, a bankruptcy or a bankruptcy auction is settled.
function resume(state: GameState)
	if #state.auctionQueue > 0 then
		startAuction(state, table.remove(state.auctionQueue, 1) :: number, true)
	elseif #state.debts > 0 then
		state.phase = "Debt"
	elseif Engine.currentPlayer(state).bankrupt then
		endTurn(state)
	else
		state.phase = state.resumePhase :: Types.Phase
		state.resumePhase = nil
	end
end

local function payDebt(state: GameState, player: Player): (boolean, string?)
	local debt = state.debts[1]
	if player.money < debt.amount then
		return false, "not enough money"
	end
	table.remove(state.debts, 1)
	local creditor = liveCreditor(state, debt.creditor)
	local creditorId = if creditor then creditor.id else nil
	transfer(state, player.id, creditorId, debt.amount, debt.reason)
	emit(state, { type = "DebtPaid", debtor = player.id, creditor = creditorId, amount = debt.amount, reason = debt.reason })
	resume(state)
	return true
end

-- Hands a property's buildings back to the bank supply; returns what selling them earns (half price each).
local function returnBuildings(state: GameState, position: number, ownership: Types.Ownership): number
	local houses = ownership.houses
	if houses == 0 then
		return 0
	end
	if houses == PropertyRules.HOTEL then
		state.bankHotels += 1
	else
		state.bankHouses += houses
	end
	ownership.houses = 0
	return houses * (PropertyRules.housePrice(position) // 2)
end

-- After a bankruptcy: ends the game if one player is left, or if the last human still playing just went out.
local function endIfOver(state: GameState, bankrupt: Player): boolean
	local solvent, humans = 0, 0
	for _, other in state.players do
		if not other.bankrupt then
			solvent += 1
			if not other.isBot then
				humans += 1
			end
		end
	end
	if solvent > 1 and (bankrupt.isBot or humans > 0) then
		return false
	end

	local winner: Player?, best = nil, -math.huge
	for _, other in state.players do
		if not other.bankrupt then
			local worth = PropertyRules.netWorth(state, other.id, other.money)
			if worth > best then -- strictly greater: ties go to the earlier seat
				winner, best = other, worth
			end
		end
	end
	state.phase = "GameOver"
	state.winner = (winner :: Player).id
	state.debts = {}
	state.auctionQueue = {}
	state.resumePhase = nil
	emit(state, { type = "GameOver", winner = state.winner })
	return true
end

local function goBankrupt(state: GameState, player: Player): (boolean, string?)
	local debt = state.debts[1]
	if player.money >= debt.amount then
		return false, "you can pay this debt"
	end
	local creditor = liveCreditor(state, debt.creditor)
	player.bankrupt = true
	player.inJail = false
	for i = #state.debts, 1, -1 do
		if state.debts[i].debtor == player.id then
			table.remove(state.debts, i)
		end
	end
	emit(state, { type = "WentBankrupt", player = player.id, creditor = if creditor then creditor.id else nil })

	local refund = 0
	local inherited = {} -- mortgaged deeds the creditor takes over
	for position = 0, Tiles.COUNT - 1 do
		local ownership = state.properties[position]
		if not ownership or ownership.owner ~= player.id then
			continue
		end
		refund += returnBuildings(state, position, ownership)
		if creditor then
			ownership.owner = creditor.id
			if ownership.mortgaged then
				table.insert(inherited, position)
			end
		else
			state.properties[position] = nil
			table.insert(state.auctionQueue, position)
		end
	end

	if creditor then
		if refund > 0 then
			transfer(state, nil, player.id, refund, "Building")
		end
		for _, id in player.jailCards do
			table.insert(creditor.jailCards, id)
		end
	else
		for _, id in player.jailCards do
			table.insert(state.decks[Cards.byId[id].deck], id)
		end
	end
	table.clear(player.jailCards)
	if player.money > 0 then
		transfer(state, player.id, if creditor then creditor.id else nil, player.money, "Bankruptcy")
	end

	if endIfOver(state, player) then
		return true
	end
	if creditor then
		for _, position in inherited do
			local interest = PropertyRules.unmortgageCost(position) - PropertyRules.mortgageValue(position)
			charge(state, creditor, nil, interest, "MortgageInterest")
		end
	end
	resume(state)
	return true
end

local function actInDebt(state: GameState, player: Player, action: Types.Action): (boolean, string?)
	if state.debts[1].debtor ~= player.id then
		return false, "waiting for another player to pay a debt"
	elseif action.type == "PayDebt" then
		return payDebt(state, player)
	elseif action.type == "Bankrupt" then
		return goBankrupt(state, player)
	elseif action.type == "SellBuilding" or action.type == "Mortgage" then
		return propertyAction(state, player, action.type, action.position)
	end
	return false, "pay your debt first"
end

function Engine.new(players: { PlayerInfo }, rollDice: Types.DiceRoller, shuffle: Types.Shuffler?): GameState
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
			inJail = false,
			jailAttempts = 0,
			jailCards = {},
		})
	end

	local decks = {}
	for _, deck in Cards.DECKS do
		local ids = Cards.idsFor(deck)
		if shuffle then
			shuffle(ids)
		end
		decks[deck] = ids
	end

	local state: GameState = {
		players = playerStates,
		currentIndex = 1,
		phase = "Roll",
		properties = {},
		lastRoll = nil,
		doublesCount = 0,
		rollAgain = false,
		decks = decks,
		bankHouses = Engine.BANK_HOUSES,
		bankHotels = Engine.BANK_HOTELS,
		auction = nil,
		debts = {},
		resumePhase = nil,
		auctionQueue = {},
		winner = nil,
		events = {},
		rollDice = rollDice,
	}
	emit(state, { type = "TurnStarted", player = playerStates[1].id })
	return state
end

local function dispatch(state: GameState, player: Player, action: Types.Action): (boolean, string?)
	local playerId = player.id
	if state.phase == "Debt" then
		return actInDebt(state, player, action)
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
	elseif action.type == "PayJailFine" and state.phase == "Roll" and player.inJail then
		return payJailFine(state, player)
	elseif action.type == "UseJailCard" and state.phase == "Roll" and player.inJail then
		return useJailCard(state, player)
	elseif PROPERTY_ACTIONS[action.type] and (state.phase == "Roll" or state.phase == "EndTurn") then
		return propertyAction(state, player, action.type, action.position)
	elseif action.type == "EndTurn" and state.phase == "EndTurn" then
		endTurn(state)
		return true
	end
	return false, `can't {action.type} now`
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
	local ok, err = dispatch(state, player, action)
	-- Anything owed during that action pauses the game on the debtor; play picks up here afterwards.
	if ok and #state.debts > 0 and state.phase ~= "Debt" and state.phase ~= "Auction" and state.phase ~= "GameOver" then
		state.resumePhase = state.phase
		state.phase = "Debt"
	end
	return ok, err
end

return Engine
