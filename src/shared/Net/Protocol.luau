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
	creditor: string?, -- nil = the bank
	amount: number,
	reason: string,
}

-- Arrays only (RemoteEvents drop sparse numeric keys).
export type Snapshot = {
	phase: string,
	currentPlayer: string,
	players: { PlayerView },
	properties: { PropertyView },
	auction: AuctionView?,
	lastRoll: { number }?,
	bankHouses: number,
	bankHotels: number,
	debt: DebtView?, -- the IOU being settled, while phase is "Debt"
	winner: string?,
}

export type Update = {
	snapshot: Snapshot?, -- nil while no game is running (lobby)
	events: { { [string]: any } },
}

local Protocol = {}

Protocol.REMOTES_FOLDER = "Remotes"
Protocol.ACTION = "GameAction"
Protocol.LOBBY = "LobbyRequest"
Protocol.UPDATE = "GameUpdate"
Protocol.READY = "ClientReady"

return table.freeze(Protocol)
