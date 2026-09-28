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
	inJail: boolean,
	jailAttempts: number, -- failed doubles rolls during this jail stay
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
-- { type = "Moved", player = "p1", from = 38, to = 3, passedGo = true, style = "Walk" }.
export type Event = { [string]: any }

export type Action = { [string]: any } -- { type = "Roll" | "Buy" | "Decline" | "Bid" | "PassBid" | "EndTurn" | "PayJailFine", amount = number? }

export type DiceRoller = () -> (number, number)

export type GameState = {
	players: { Player },
	currentIndex: number,
	phase: Phase,
	properties: { [number]: Ownership }, -- keyed by board position; absent = owned by the bank
	lastRoll: { number }?,
	doublesCount: number, -- doubles rolled so far this turn
	rollAgain: boolean, -- the move being resolved earned another roll
	auction: Auction?,
	events: { Event },
	rollDice: DiceRoller,
}

return nil
