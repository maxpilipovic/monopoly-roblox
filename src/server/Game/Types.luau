--!strict
-- Shapes of the engine's game state, actions and events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeRules = require(ReplicatedStorage.Shared.Rules.TradeRules)

export type Phase = "Roll" | "BuyDecision" | "Auction" | "EndTurn" | "Debt" | "Trade" | "GameOver"

export type Player = {
	id: string,
	name: string,
	isBot: boolean,
	money: number,
	position: number,
	bankrupt: boolean,
	inJail: boolean,
	jailAttempts: number, -- failed doubles rolls during this jail stay
	jailCards: { string }, -- ids of held Get Out of Jail Free cards
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
	fromBankruptcy: boolean, -- sold off a bankrupt player's deeds; ends with resume, not finishMove
}

-- An IOU: a forced payment the debtor couldn't cover yet. creditor nil = the bank.
export type Debt = {
	debtor: string,
	creditor: string?,
	amount: number,
	reason: string,
}

-- An offer waiting for its receiver's answer.
export type PendingTrade = {
	from: string,
	offer: TradeRules.Offer,
	returnPhase: Phase, -- Roll, EndTurn or Debt
}

-- Events are plain tables with a `type` and event-specific fields, e.g.
-- { type = "Moved", player = "p1", from = 38, to = 3, passedGo = true, style = "Walk" }.
export type Event = { [string]: any }

export type Action = { [string]: any } -- { type = "Roll" | "Buy" | "Decline" | "Bid" | "PassBid" | "EndTurn" | "PayJailFine" | "UseJailCard" | "Build" | "SellBuilding" | "Mortgage" | "Unmortgage" | "PayDebt" | "Bankrupt" | "ProposeTrade" | "AcceptTrade" | "DeclineTrade", amount = number?, position = number?, offer = table? }

export type DiceRoller = () -> (number, number)

export type Shuffler = (ids: { string }) -> () -- shuffles in place

export type GameState = {
	players: { Player },
	currentIndex: number,
	phase: Phase,
	properties: { [number]: Ownership }, -- keyed by board position; absent = owned by the bank
	lastRoll: { number }?,
	doublesCount: number, -- doubles rolled so far this turn
	rollAgain: boolean, -- the move being resolved earned another roll
	decks: { [string]: { string } }, -- card ids per deck; index 1 is the top
	bankHouses: number, -- houses left in the bank
	bankHotels: number, -- hotels left in the bank
	auction: Auction?,
	debts: { Debt }, -- open IOUs, settled first to last
	resumePhase: Phase?, -- where play continues once the debts are settled
	auctionQueue: { number }, -- a bankrupt player's deeds waiting to be auctioned by the bank
	winner: string?,
	trade: PendingTrade?,
	tradeOffers: { [string]: number }, -- offers each player has made this turn
	events: { Event },
	rollDice: DiceRoller,
}

return nil
