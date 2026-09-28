--!strict
-- A simple bot: buys what it can afford while keeping a cash reserve, and bids up to face value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Bot = {}

Bot.CASH_RESERVE = 150
Bot.BID_STEP = 10

function Bot.chooseAction(state: Types.GameState, botId: string): Types.Action?
	if Engine.actingPlayer(state) ~= botId then
		return nil
	end
	local me = Engine.getPlayer(state, botId) :: Types.Player

	if state.phase == "Roll" then
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
