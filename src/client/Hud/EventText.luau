--!strict
-- One log line per game event worth showing; nil for the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Cards = require(ReplicatedStorage.Shared.Board.Cards)

local EventText = {}

local DEBT_REASONS = {
	Rent = " in rent",
	Tax = " in tax",
	JailFine = " for the jail fine",
	Card = " for a card",
	MortgageInterest = " in mortgage interest",
}

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
		elseif event.reason == "Card" and event.from and event.to then
			return `{name(event.from)} paid ${event.amount} to {name(event.to)}`
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
	elseif kind == "SentToJail" then
		if event.reason == "Doubles" then
			return `{name(event.player)} rolled doubles three times and went to jail`
		end
		return `{name(event.player)} went to jail`
	elseif kind == "LeftJail" then
		if event.reason == "Doubles" then
			return `{name(event.player)} rolled doubles and got out of jail`
		elseif event.reason == "Fine" then
			return `{name(event.player)} paid $50 and got out of jail`
		end
		return `{name(event.player)} used a Get Out of Jail Free card`
	elseif kind == "CardDrawn" then
		local card = Cards.byId[event.card]
		if not card then
			return nil
		end
		return `{name(event.player)} drew {Cards.DECK_TITLES[card.deck]}: {card.text}`
	elseif kind == "Built" then
		return `{name(event.player)} built a {if event.hotel then "hotel" else "house"} on {tileName(event.position)}`
	elseif kind == "BuildingSold" then
		return `{name(event.player)} sold a {if event.hotel then "hotel" else "house"} on {tileName(event.position)}`
	elseif kind == "Mortgaged" then
		return `{name(event.player)} mortgaged {tileName(event.position)} for ${event.amount}`
	elseif kind == "Unmortgaged" then
		return `{name(event.player)} paid ${event.amount} to unmortgage {tileName(event.position)}`
	elseif kind == "DebtOwed" then
		local creditor = if event.creditor then name(event.creditor) else "the bank"
		return `{name(event.debtor)} owes {creditor} ${event.amount}{DEBT_REASONS[event.reason] or ""}`
	elseif kind == "WentBankrupt" then
		return `{name(event.player)} went bankrupt to {if event.creditor then name(event.creditor) else "the bank"}`
	elseif kind == "GameOver" then
		return `{name(event.winner)} wins!`
	elseif kind == "PlayerReplaced" then
		return `{name(event.player)} left; a bot takes over`
	end
	return nil
end

return EventText
