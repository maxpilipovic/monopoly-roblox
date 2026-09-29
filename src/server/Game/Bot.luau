--!strict
-- A simple bot: keeps a cash reserve when buying, bidding and building, lifts mortgages when rich,
-- leaves jail as soon as it can spare the fine, in debt sells, then mortgages, then gives up,
-- and weighs trade offers by value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Bot = {}

Bot.CASH_RESERVE = 150
Bot.BID_STEP = 10
Bot.RICH_MULTIPLIER = 3 -- unmortgage only when this many reserves would remain
Bot.TRADE_MARGIN_TENTHS = 11 -- accept at 110% of what it gives (integer math)
Bot.JAIL_CARD_VALUE = 50

-- Before rolling: lift the cheapest mortgage when rich, else build the cheapest legal house.
local function propertyPlan(state: Types.GameState, me: Types.Player): Types.Action?
	local best: number?, bestCost = nil, math.huge
	for _, tile in Tiles.list do
		local position = tile.position
		if PropertyRules.canUnmortgage(state, me.id, me.money, position) then
			local cost = PropertyRules.unmortgageCost(position)
			if me.money - cost >= Bot.RICH_MULTIPLIER * Bot.CASH_RESERVE and cost < bestCost then
				best, bestCost = position, cost
			end
		end
	end
	if best then
		return { type = "Unmortgage", position = best }
	end

	for _, tile in Tiles.list do
		local position = tile.position
		if tile.kind == "Property" and PropertyRules.canBuild(state, me.id, me.money, position) then
			local price = PropertyRules.housePrice(position)
			if me.money - price >= Bot.CASH_RESERVE and price < bestCost then
				best, bestCost = position, price
			end
		end
	end
	if best then
		return { type = "Build", position = best }
	end
	return nil
end

-- In debt: sell the priciest building (the rules keep sets even), else mortgage the cheapest bare deed.
local function raiseCash(state: Types.GameState, me: Types.Player): Types.Action?
	local best: number?, bestPrice = nil, -math.huge
	for _, tile in Tiles.list do
		if tile.kind == "Property" and PropertyRules.canSell(state, me.id, tile.position) then
			local price = PropertyRules.housePrice(tile.position)
			if price >= bestPrice then
				best, bestPrice = tile.position, price
			end
		end
	end
	if best then
		return { type = "SellBuilding", position = best }
	end

	local cheapest = math.huge
	for _, tile in Tiles.list do
		if PropertyRules.canMortgage(state, me.id, tile.position) then
			local value = PropertyRules.mortgageValue(tile.position)
			if value < cheapest then
				best, cheapest = tile.position, value
			end
		end
	end
	return if best then { type = "Mortgage", position = best } else nil
end

-- Whether owner holds a street's whole color set once gained/lost deeds change hands.
local function completesSet(state: Types.GameState, ownerId: string, position: number, gained: { number }, lost: { number }): boolean
	local tile = Tiles.at(position)
	if tile.kind ~= "Property" then
		return false
	end
	for _, other in PropertyRules.groupPositions(tile.group :: string) do
		local ownership = state.properties[other]
		local keeps = ownership ~= nil and ownership.owner == ownerId and not table.find(lost, other)
		if not keeps and not table.find(gained, other) then
			return false
		end
	end
	return true
end

local function deedValue(state: Types.GameState, position: number): number
	local price = Tiles.at(position).price :: number
	return if state.properties[position].mortgaged then price - PropertyRules.unmortgageCost(position) else price
end

-- A deal is worth taking when what the bot gets is at least TRADE_MARGIN_TENTHS/10 of what it gives.
local function acceptsTrade(state: Types.GameState, me: Types.Player, trade: Types.PendingTrade): boolean
	local offer = trade.offer
	local received = offer.give.cash + offer.give.jailCards * Bot.JAIL_CARD_VALUE
	for _, position in offer.give.properties do
		local worth = deedValue(state, position)
		received += if completesSet(state, me.id, position, offer.give.properties, offer.get.properties) then 2 * worth else worth
	end
	local given = offer.get.cash + offer.get.jailCards * Bot.JAIL_CARD_VALUE
	for _, position in offer.get.properties do
		local worth = deedValue(state, position)
		given += if completesSet(state, trade.from, position, offer.get.properties, offer.give.properties) then 2 * worth else worth
	end
	if given == 0 then
		return true
	elseif offer.get.cash > 0 and me.money - offer.get.cash < Bot.CASH_RESERVE then
		return false
	end
	return received * 10 >= given * Bot.TRADE_MARGIN_TENTHS
end

function Bot.chooseAction(state: Types.GameState, botId: string): Types.Action?
	if Engine.actingPlayer(state) ~= botId then
		return nil
	end
	local me = Engine.getPlayer(state, botId) :: Types.Player

	if state.phase == "Roll" then
		local plan = propertyPlan(state, me)
		if plan then
			return plan
		end
		if me.inJail then
			if #me.jailCards > 0 then
				return { type = "UseJailCard" }
			elseif me.money - Engine.JAIL_FINE >= Bot.CASH_RESERVE then
				return { type = "PayJailFine" }
			end
		end
		return { type = "Roll" }
	elseif state.phase == "BuyDecision" then
		local price = Tiles.at(me.position).price :: number
		return if me.money - price >= Bot.CASH_RESERVE then { type = "Buy" } else { type = "Decline" }
	elseif state.phase == "Auction" then
		local auction = state.auction :: Types.Auction
		local limit = math.min(Tiles.at(auction.position).price :: number, me.money - Bot.CASH_RESERVE)
		local nextBid = auction.highBid + Bot.BID_STEP
		return if nextBid <= limit then { type = "Bid", amount = nextBid } else { type = "PassBid" }
	elseif state.phase == "Debt" then
		if me.money >= state.debts[1].amount then
			return { type = "PayDebt" }
		end
		return raiseCash(state, me) or { type = "Bankrupt" }
	elseif state.phase == "Trade" then
		local trade = state.trade :: Types.PendingTrade
		return { type = if acceptsTrade(state, me, trade) then "AcceptTrade" else "DeclineTrade" }
	elseif state.phase == "EndTurn" then
		return { type = "EndTurn" }
	end
	return nil
end

return Bot
