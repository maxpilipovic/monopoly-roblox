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
	piece: string?, -- Catalog piece id this player plays with
	rentEffect: string?, -- Catalog rent effect played over whoever pays them rent
	aura: string?, -- Catalog aura worn on their piece
	dice: string?, -- Catalog dice skin they roll with
	title: string?, -- Catalog title shown with their name
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
	map: string, -- Maps id; clients switch to it before drawing
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
	freeParkingPot: number, -- money waiting on Free Parking (always 0 unless that rule is on)
	scene: string, -- Scenes id: what surrounds the board
	rules: { auctions: boolean, freeParking: boolean },
}

export type Update = {
	snapshot: Snapshot?, -- nil while no game is running (lobby)
	events: { { [string]: any } },
	notice: string?, -- only to a player whose action was refused: why
}

-- A player's own saved data, as their client sees it (progression in the shape Shared.Progress.Progress reads).
export type ProfileView = {
	stats: { wins: number, games: number, streak: number, bestStreak: number, elo: number, peakElo: number, rankedGames: number, rankedWins: number },
	inventory: { [string]: number },
	equipped: { piece: string, rentEffect: string?, aura: string?, dice: string?, title: string? },
	coins: number,
	counters: { [string]: number },
	keys: { [string]: number },
	daily: any, -- Progress.DailyState
	achievements: { [string]: number },
	tree: { claimed: { [string]: boolean }, starts: { [string]: number } },
}

-- The casual games on this server and which one (if any) the receiving player is in.
export type RoomsUpdate = {
	rooms: { any }, -- Rooms.RoomView
	mine: number?,
	hostOf: number?, -- the room this player hosts
	notice: string?, -- why their last request was refused
	queue: { mode: string, since: number }?, -- their place in the ranked queue (server time joined)
}

-- Requests on the LOBBY remote: { type = "Create", settings } | { type = "Join", room } | { type = "Leave" }
-- | { type = "Settings", settings } | { type = "Start" } | { type = "ReturnToLobby" }
-- | { type = "Queue", mode = "Duel" | "Table" } | { type = "Unqueue" }
-- Requests on the STORE remote: { type = "Equip", item } | { type = "Unequip", kind } | { type = "UnequipEffect" }
-- | { type = "Buy", chest } (Robux) | { type = "BuyWithCoins", chest } | { type = "UseKey", chest }
-- | { type = "TestOpen", chest } (Studio only)
-- refund: the item was already owned, so it became this many coins instead.
export type ChestResult = { chest: string, item: string, count: number, refund: number? }

-- Requests on the PROGRESS remote: { type = "ClaimDaily", slot } | { type = "SwapDaily", slot }
-- | { type = "ClaimAchievement", track } | { type = "ClaimNode", node }
-- A claimed reward, sent back for the celebration (or just a notice when the claim was refused).
export type RewardView = { source: string, title: string, coins: number?, item: string?, key: string?, notice: string? }

local Protocol = {}

Protocol.REMOTES_FOLDER = "Remotes"
Protocol.ACTION = "GameAction"
Protocol.LOBBY = "LobbyRequest"
Protocol.UPDATE = "GameUpdate"
Protocol.READY = "ClientReady"
Protocol.PROFILE = "ProfileUpdate"
Protocol.ROOMS = "RoomsUpdate"
Protocol.STORE = "StoreRequest"
Protocol.CHEST = "ChestOpened"
Protocol.PROGRESS = "ProgressRequest"
Protocol.REWARD = "RewardEarned"
Protocol.MUTE = "MuteRequest" -- client: { userId, muted }; server replies with the muted user ids

return table.freeze(Protocol)
