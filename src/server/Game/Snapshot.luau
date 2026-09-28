--!strict
-- The public view of a game, in a shape RemoteEvents can carry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
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

	return {
		phase = state.phase,
		currentPlayer = Engine.currentPlayer(state).id,
		players = players,
		properties = properties,
		auction = auction,
		lastRoll = if state.lastRoll then table.clone(state.lastRoll) else nil,
	}
end

return Snapshot
