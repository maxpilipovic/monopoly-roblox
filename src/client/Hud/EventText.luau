--!strict
-- One log line per game event worth showing; nil for the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local EventText = {}

function EventText.describe(event: { [string]: any }, names: { [string]: string }): string?
	local function name(id: string?): string
		return if id then names[id] or id else "The bank"
	end
	local function tileName(position: number): string
		return Tiles.at(position).name
	end

	local kind = event.type
	if kind == "TurnStarted" then
		return `{name(event.player)}'s turn`
	elseif kind == "Rolled" then
		return `{name(event.player)} rolled {event.dice[1]} + {event.dice[2]}`
	elseif kind == "Paid" then
		if event.reason == "Go" then
			return `{name(event.to)} collected ${event.amount} for passing Go`
		elseif event.reason == "Rent" then
			return `{name(event.from)} paid ${event.amount} rent to {name(event.to)}`
		elseif event.reason == "Tax" then
			return `{name(event.from)} paid ${event.amount} tax`
		end
		return nil
	elseif kind == "Bought" then
		return `{name(event.player)} bought {tileName(event.position)} for ${event.price}`
	elseif kind == "AuctionStarted" then
		return `Auction for {tileName(event.position)}`
	elseif kind == "BidPlaced" then
		return `{name(event.player)} bid ${event.amount}`
	elseif kind == "BidPassed" then
		return `{name(event.player)} passed`
	elseif kind == "AuctionEnded" then
		if event.winner then
			return `{name(event.winner)} won {tileName(event.position)} for ${event.amount}`
		end
		return `Nobody bought {tileName(event.position)}`
	elseif kind == "PlayerReplaced" then
		return `{name(event.player)} left; a bot takes over`
	end
	return nil
end

return EventText
