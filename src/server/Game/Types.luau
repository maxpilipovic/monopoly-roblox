--!strict
-- Shapes of the engine's game state, actions and events.

export type Phase = "Roll" | "BuyDecision" | "Auction" | "EndTurn" | "GameOver"

export type Player = {
	id: string,
	name: string,
	isBot: boolean,
	money: number,
	position: number,
	bankrupt: boolean,
}

export type Ownership = {
	owner: string,
	houses: number, -- 0-4 houses, 5 = hotel
	mortgaged: boolean,
}

export type Auction = {
	position: number,
	highBid: number,
	highBidder: string?,
	bidders: { string }, -- players still bidding, in bidding order
	nextBidder: number, -- index into bidders of who acts next
}

-- Events are plain tables with a `type` and event-specific fields, e.g.
-- { type = "Moved", player = "p1", from = 38, to = 3, passedGo = true }.
export type Event = { [string]: any }

export type Action = { [string]: any } -- { type = "Roll" | "Buy" | "Decline" | "Bid" | "PassBid" | "EndTurn", amount = number? }

export type DiceRoller = () -> (number, number)

export type GameState = {
	players: { Player },
	currentIndex: number,
	phase: Phase,
	properties: { [number]: Ownership }, -- keyed by board position; absent = owned by the bank
	lastRoll: { number }?,
	auction: Auction?,
	events: { Event },
	rollDice: DiceRoller,
}

return nil
