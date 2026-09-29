--!strict
-- The public view of a game, in a shape RemoteEvents can carry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Snapshot = {}

function Snapshot.fromState(state: Types.GameState): Protocol.Snapshot
	local players = {}
	for seat, player in state.players do
		table.insert(players, {
			id = player.id,
			name = player.name,
			isBot = player.isBot,
			money = player.money,
			position = player.position,
			bankrupt = player.bankrupt,
			inJail = player.inJail,
			jailCards = #player.jailCards,
			seat = seat,
			netWorth = PropertyRules.netWorth(state, player.id, player.money),
		})
	end

	local properties = {}
	for position, ownership in state.properties do
		table.insert(properties, {
			position = position,
			owner = ownership.owner,
			houses = ownership.houses,
			mortgaged = ownership.mortgaged,
		})
	end
	table.sort(properties, function(a, b)
		return a.position < b.position
	end)

	local auction: Protocol.AuctionView? = nil
	if state.auction then
		auction = {
			position = state.auction.position,
			highBid = state.auction.highBid,
			highBidder = state.auction.highBidder,
			currentBidder = Engine.currentBidder(state),
		}
	end

	local openDebt = state.debts[1]
	local debt: Protocol.DebtView? = if openDebt
		then { debtor = openDebt.debtor, creditor = openDebt.creditor, amount = openDebt.amount, reason = openDebt.reason }
		else nil

	local trade: Protocol.TradeView? = nil
	if state.trade then
		local offer = state.trade.offer
		trade = {
			from = state.trade.from,
			to = offer.to,
			give = { properties = table.clone(offer.give.properties), cash = offer.give.cash, jailCards = offer.give.jailCards },
			get = { properties = table.clone(offer.get.properties), cash = offer.get.cash, jailCards = offer.get.jailCards },
		}
	end
	local acting = Engine.actingPlayer(state)
	local offersLeft = if acting then Engine.MAX_TRADE_OFFERS - (state.tradeOffers[acting] or 0) else 0

	return {
		phase = state.phase,
		currentPlayer = Engine.currentPlayer(state).id,
		players = players,
		properties = properties,
		auction = auction,
		lastRoll = if state.lastRoll then table.clone(state.lastRoll) else nil,
		bankHouses = state.bankHouses,
		bankHotels = state.bankHotels,
		debt = debt,
		trade = trade,
		tradeOffersLeft = offersLeft,
		winner = state.winner,
	}
end

return Snapshot
