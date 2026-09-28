--!strict
-- A simple bot: keeps a cash reserve when buying, bidding and building, lifts mortgages when rich,
-- and leaves jail as soon as it can spare the fine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Bot = {}

Bot.CASH_RESERVE = 150
Bot.BID_STEP = 10
Bot.RICH_MULTIPLIER = 3 -- unmortgage only when this many reserves would remain

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
	elseif state.phase == "EndTurn" then
		return { type = "EndTurn" }
	end
	return nil
end

return Bot
