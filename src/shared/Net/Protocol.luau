--!strict
-- The contract between server and clients: remote names and the shapes sent over them.

export type PlayerView = {
	id: string,
	name: string,
	isBot: boolean,
	money: number,
	position: number,
	bankrupt: boolean,
	inJail: boolean,
	jailCards: number, -- Get Out of Jail Free cards held
	jailAttempts: number, -- failed doubles rolls this jail stay; the fine is forced after the third
	seat: number, -- 1-based turn order; also picks the token spot and color
	netWorth: number,
}

export type PropertyView = {
	position: number,
	owner: string,
	houses: number,
	mortgaged: boolean,
}

export type AuctionView = {
	position: number,
	highBid: number,
	highBidder: string?,
	currentBidder: string?,
}

export type DebtView = {
	debtor: string,
	creditor: string?, -- nil = the bank (also when the creditor has since gone bankrupt)
	amount: number,
	reason: string,
}

export type TradeSideView = {
	properties: { number },
	cash: number,
	jailCards: number,
}

export type TradeView = {
	from: string,
	to: string,
	give: TradeSideView, -- from `from`
	get: TradeSideView, -- from `to`
}

export type MatchView = {
	timer: string, -- MatchSettings timer id
	length: string, -- MatchSettings length id
	round: number,
	roundLimit: number?,
	endsAt: number?, -- server time the minutes limit runs out
	turnDeadline: number?, -- server time the acting human's decision times out
}

-- Arrays only (RemoteEvents drop sparse numeric keys).
export type Snapshot = {
	phase: string,
	currentPlayer: string,
	acting: string?, -- whoever the game is waiting on (bidder, debtor, trade receiver); nil once it's over
	players: { PlayerView },
	properties: { PropertyView },
	auction: AuctionView?,
	lastRoll: { number }?,
	bankHouses: number,
	bankHotels: number,
	debt: DebtView?, -- the IOU being settled, while phase is "Debt"
	trade: TradeView?, -- the offer waiting for an answer, while phase is "Trade"
	tradeOffersLeft: number, -- offers the acting player may still make this turn
	match: MatchView,
	winReason: string?, -- "Bankruptcy" | "RoundLimit" | "TimeLimit", once the game is over
	winner: string?,
}

export type Update = {
	snapshot: Snapshot?, -- nil while no game is running (lobby)
	events: { { [string]: any } },
	notice: string?, -- only to a player whose action was refused: why
}

local Protocol = {}

Protocol.REMOTES_FOLDER = "Remotes"
Protocol.ACTION = "GameAction"
Protocol.LOBBY = "LobbyRequest"
Protocol.UPDATE = "GameUpdate"
Protocol.READY = "ClientReady"

return table.freeze(Protocol)
