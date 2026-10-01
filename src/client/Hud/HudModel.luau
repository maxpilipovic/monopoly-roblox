--!strict
-- What the HUD should show for a snapshot: a status line and the buttons the local player may press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local EventText = require(script.Parent.EventText)

export type Button = {
	label: string,
	action: { [string]: any },
	confirm: string?, -- shown after the first click; the second click sends the action
}

local HudModel = {}

HudModel.BID_STEPS = { 10, 50, 100 }
HudModel.JAIL_FINE = 50 -- mirrors Engine.JAIL_FINE (server-only)
HudModel.JAIL_MAX_ATTEMPTS = 3 -- mirrors Engine.JAIL_MAX_ATTEMPTS (server-only)

function HudModel.names(snapshot: Protocol.Snapshot): { [string]: string }
	local names = {}
	for _, player in snapshot.players do
		names[player.id] = player.name
	end
	return names
end

local function findPlayer(snapshot: Protocol.Snapshot, id: string): Protocol.PlayerView?
	for _, player in snapshot.players do
		if player.id == id then
			return player
		end
	end
	return nil
end

-- The local player's seat, unless they're watching: not in the game, or a bot took their seat after they left.
local function seated(snapshot: Protocol.Snapshot, localId: string): Protocol.PlayerView?
	local me = findPlayer(snapshot, localId)
	return if me and not me.isBot then me else nil
end

function HudModel.isDebtor(snapshot: Protocol.Snapshot, localId: string): boolean
	return snapshot.phase == "Debt" and snapshot.debt ~= nil and snapshot.debt.debtor == localId
end

function HudModel.buttons(snapshot: Protocol.Snapshot, localId: string): { Button }
	local me = seated(snapshot, localId)
	if not me or snapshot.acting ~= localId then
		return {}
	end

	local phase = snapshot.phase
	if phase == "Roll" then
		local buttons = {}
		if me.inJail then
			table.insert(buttons, { label = "Try for doubles", action = { type = "Roll" } })
			if me.money >= HudModel.JAIL_FINE then
				table.insert(buttons, { label = `Pay ${HudModel.JAIL_FINE} fine`, action = { type = "PayJailFine" } })
			end
			if me.jailCards > 0 then
				table.insert(buttons, { label = "Use jail card", action = { type = "UseJailCard" } })
			end
		else
			table.insert(buttons, { label = "Roll dice", action = { type = "Roll" } })
		end
		return buttons
	elseif phase == "BuyDecision" then
		local buttons = {}
		local price = Tiles.at(me.position).price :: number
		if me.money >= price then
			table.insert(buttons, { label = `Buy for ${price}`, action = { type = "Buy" } })
		end
		table.insert(buttons, { label = "Don't buy", action = { type = "Decline" } })
		return buttons
	elseif phase == "Auction" and snapshot.auction then
		local buttons = {}
		for _, step in HudModel.BID_STEPS do
			local amount = snapshot.auction.highBid + step
			if amount <= me.money then
				table.insert(buttons, { label = `Bid ${amount}`, action = { type = "Bid", amount = amount } })
			end
		end
		table.insert(buttons, { label = "Pass", action = { type = "PassBid" } })
		return buttons
	elseif phase == "Debt" and snapshot.debt then
		local amount = snapshot.debt.amount
		if me.money >= amount then
			return { { label = `Pay ${amount}`, action = { type = "PayDebt" } } }
		end
		return { { label = "Go bankrupt", confirm = "Confirm bankruptcy?", action = { type = "Bankrupt" } } }
	elseif phase == "Trade" then
		return {
			{ label = "Accept", action = { type = "AcceptTrade" } },
			{ label = "Decline", action = { type = "DeclineTrade" } },
		}
	elseif phase == "EndTurn" then
		return { { label = "End turn", action = { type = "EndTurn" } } }
	end
	return {}
end

function HudModel.status(snapshot: Protocol.Snapshot, localId: string): string
	local names = HudModel.names(snapshot)
	if snapshot.phase == "GameOver" then
		local winner = snapshot.winner
		local prefix = EventText.WIN_PREFIX[snapshot.winReason or ""] or ""
		return `{prefix}{if winner then names[winner] or winner else "Nobody"} wins!`
	end
	if not seated(snapshot, localId) then
		localId = "" -- a bot holds their seat (or they never had one): they watch like any spectator
	end
	local debt = snapshot.debt
	if snapshot.phase == "Debt" and debt then
		if debt.debtor == localId then
			local me = findPlayer(snapshot, localId) :: Protocol.PlayerView
			local creditor = if debt.creditor then names[debt.creditor] or debt.creditor else "the bank"
			return `You owe {creditor} ${debt.amount}. You have ${me.money}.`
		end
		return `Waiting for {names[debt.debtor] or debt.debtor} to raise ${debt.amount}…`
	end
	local trade = snapshot.trade
	if snapshot.phase == "Trade" and trade then
		local from = names[trade.from] or trade.from
		if trade.to == localId then
			return `{from} offers you a trade`
		end
		return `Waiting for {names[trade.to] or trade.to} to answer {from}'s offer`
	end
	local auction = snapshot.auction
	if auction then
		local tile = Tiles.at(auction.position).name
		local yours = if auction.currentBidder == localId then " · your bid" else ""
		if auction.highBidder then
			return `Auction: {tile} — high bid ${auction.highBid} ({names[auction.highBidder]}){yours}`
		end
		return `Auction: {tile} — no bids yet{yours}`
	end
	if snapshot.currentPlayer == localId then
		local me = findPlayer(snapshot, localId)
		if me and me.inJail and snapshot.phase == "Roll" then
			if me.jailAttempts >= HudModel.JAIL_MAX_ATTEMPTS - 1 then
				return `Your turn — last try in jail: miss and you pay ${HudModel.JAIL_FINE}`
			end
			return "Your turn — you're in jail"
		end
		return "Your turn"
	end
	return `Waiting for {names[snapshot.currentPlayer] or snapshot.currentPlayer}`
end

HudModel.URGENT_SECONDS = 5

local function clockText(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Time left on the acting human's decision, e.g. "0:14", and whether it's nearly up.
function HudModel.countdown(snapshot: Protocol.Snapshot, now: number): (string?, boolean)
	local deadline = snapshot.match.turnDeadline
	if not deadline then
		return nil, false
	end
	local left = math.max(0, math.ceil(deadline - now))
	return clockText(left), left <= HudModel.URGENT_SECONDS
end

-- The speed options in play, e.g. "Fast · Round 7 of 25" or "Relaxed · 23:10 left".
function HudModel.matchLine(snapshot: Protocol.Snapshot, now: number): string?
	local match = snapshot.match
	if snapshot.phase == "GameOver" then
		return nil -- the results screen says how it ended
	end
	local parts = {}
	if match.timer ~= "Off" then
		table.insert(parts, match.timer)
	end
	if match.roundLimit then
		table.insert(parts, `Round {math.min(match.round, match.roundLimit)} of {match.roundLimit}`)
	elseif match.endsAt then
		local left = math.ceil(match.endsAt - now)
		table.insert(parts, if left > 0 then `{clockText(left)} left` else "Final turn")
	end
	return if #parts > 0 then table.concat(parts, " · ") else nil
end

export type PlayerRow = {
	id: string,
	name: string,
	seat: number,
	money: number,
	bankrupt: boolean,
	inJail: boolean,
	isYou: boolean,
	isCurrent: boolean,
	deeds: number, -- how many properties they own
}

-- One row per player for the player list, in seat order.
function HudModel.playerRows(snapshot: Protocol.Snapshot, localId: string): { PlayerRow }
	local deeds = {}
	for _, property in snapshot.properties do
		deeds[property.owner] = (deeds[property.owner] or 0) + 1
	end
	local rows = {}
	for _, player in snapshot.players do
		table.insert(rows, {
			id = player.id,
			name = player.name,
			seat = player.seat,
			money = player.money,
			bankrupt = player.bankrupt,
			inJail = player.inJail,
			isYou = player.id == localId,
			isCurrent = player.id == snapshot.currentPlayer and snapshot.phase ~= "GameOver",
			deeds = deeds[player.id] or 0,
		})
	end
	table.sort(rows, function(a, b)
		return a.seat < b.seat
	end)
	return rows
end

-- The tile whose deed everyone should be looking at: the one being bought or auctioned.
function HudModel.deedFocus(snapshot: Protocol.Snapshot): number?
	if snapshot.auction then
		return snapshot.auction.position
	elseif snapshot.phase == "BuyDecision" then
		local current = findPlayer(snapshot, snapshot.currentPlayer)
		return if current then current.position else nil
	end
	return nil
end

function HudModel.canTrade(snapshot: Protocol.Snapshot, localId: string): boolean
	local phase = snapshot.phase
	if not seated(snapshot, localId) or snapshot.acting ~= localId or snapshot.tradeOffersLeft <= 0 then
		return false
	elseif phase ~= "Roll" and phase ~= "EndTurn" and phase ~= "Debt" then
		return false
	end
	for _, player in snapshot.players do
		if player.id ~= localId and not player.bankrupt then
			return true
		end
	end
	return false
end

-- For the receiver of an open offer: what they would give and get, in words.
function HudModel.tradeSummary(snapshot: Protocol.Snapshot, localId: string): { give: string, get: string }?
	local trade = snapshot.trade
	if snapshot.phase ~= "Trade" or not trade or trade.to ~= localId then
		return nil
	end
	local view = HudModel.rulesView(snapshot)
	return { give = EventText.tradeSide(trade.get, view), get = EventText.tradeSide(trade.give, view) }
end

export type Chip = { position: number, name: string, color: Color3?, mortgaged: boolean }
export type OfferSide = { title: string, chips: { Chip }, cash: number, jailCards: number }
export type Offer = { title: string, left: OfferSide, right: OfferSide }

local function offerSide(title: string, side: Protocol.TradeSideView, mortgaged: { [number]: boolean }): OfferSide
	local positions = table.clone(side.properties)
	table.sort(positions)
	local chips = {}
	for _, position in positions do
		local tile = Tiles.at(position)
		local group = if tile.group then ColorGroups[tile.group] else nil
		table.insert(chips, {
			position = position,
			name = tile.name,
			color = if group then group.color else nil,
			mortgaged = mortgaged[position] == true,
		})
	end
	return { title = title, chips = chips, cash = side.cash, jailCards = side.jailCards }
end

-- The open offer as this viewer should read it: the receiver and the proposer see "You give / You
-- get", everyone else sees who gives what.
function HudModel.tradeOffer(snapshot: Protocol.Snapshot, localId: string): Offer?
	local trade = snapshot.trade
	if snapshot.phase ~= "Trade" or not trade then
		return nil
	end
	local names = HudModel.names(snapshot)
	local from, to = names[trade.from] or trade.from, names[trade.to] or trade.to
	local mortgaged = {}
	for _, property in snapshot.properties do
		mortgaged[property.position] = property.mortgaged
	end
	if trade.to == localId then
		return {
			title = `{from} offers you a trade`,
			left = offerSide("You give", trade.get, mortgaged),
			right = offerSide("You get", trade.give, mortgaged),
		}
	elseif trade.from == localId then
		return {
			title = `Your offer to {to}`,
			left = offerSide("You give", trade.give, mortgaged),
			right = offerSide("You get", trade.get, mortgaged),
		}
	end
	return {
		title = `{from} offers {to} a trade`,
		left = offerSide(`{from} gives`, trade.give, mortgaged),
		right = offerSide(`{to} gives`, trade.get, mortgaged),
	}
end

-- Cash changes between two snapshots, for players in both. No previous snapshot: nothing to show.
function HudModel.moneyDeltas(previous: Protocol.Snapshot?, next: Protocol.Snapshot): { [string]: number }
	local deltas = {}
	if previous then
		local before = {}
		for _, player in previous.players do
			before[player.id] = player.money
		end
		for _, player in next.players do
			local was = before[player.id]
			if was and was ~= player.money then
				deltas[player.id] = player.money - was
			end
		end
	end
	return deltas
end

-- Whether the turn has just become the local player's (doubles keep the turn; that isn't a new one).
function HudModel.becameMyTurn(previous: Protocol.Snapshot?, next: Protocol.Snapshot, localId: string): boolean
	if not seated(next, localId) or next.phase ~= "Roll" or next.currentPlayer ~= localId then
		return false
	end
	return previous == nil or previous.currentPlayer ~= localId
end

-- The share (0-1) of the acting player's decision time that's left; nil when no clock is running.
function HudModel.timerFraction(snapshot: Protocol.Snapshot, now: number): number?
	local deadline = snapshot.match.turnDeadline
	if not deadline then
		return nil
	end
	local total = MatchSettings.timerSeconds({ timer = snapshot.match.timer, length = snapshot.match.length, map = snapshot.map })
	if snapshot.phase == "Auction" then
		total = MatchSettings.bidSeconds(total)
	end
	if total <= 0 then
		return nil
	end
	return math.clamp((deadline - now) / total, 0, 1)
end

export type PropertyRow = {
	position: number,
	name: string,
	group: string, -- color group, or "Railroad" / "Utility"
	houses: number,
	mortgaged: boolean,
	buttons: { Button },
}

local KIND_ORDER = { Property = 1, Railroad = 2, Utility = 3 }

function HudModel.rulesView(snapshot: Protocol.Snapshot): PropertyRules.View
	local properties = {}
	for _, property in snapshot.properties do
		properties[property.position] = { owner = property.owner, houses = property.houses, mortgaged = property.mortgaged }
	end
	return { properties = properties, bankHouses = snapshot.bankHouses, bankHotels = snapshot.bankHotels }
end

-- The local player's deeds with the property actions they may take right now.
function HudModel.propertyRows(snapshot: Protocol.Snapshot, localId: string): { PropertyRow }
	local me = seated(snapshot, localId)
	if not me then
		return {}
	end
	-- On your own turn you may do everything; while settling a debt only sell and mortgage.
	local canImprove = snapshot.currentPlayer == localId
		and snapshot.auction == nil
		and (snapshot.phase == "Roll" or snapshot.phase == "EndTurn")
	local canRaise = canImprove or HudModel.isDebtor(snapshot, localId)
	local view = HudModel.rulesView(snapshot)

	local rows = {}
	for _, property in snapshot.properties do
		if property.owner ~= localId then
			continue
		end
		local position = property.position
		local tile = Tiles.at(position)
		local buttons = {}
		if canRaise then
			if tile.kind == "Property" then
				local price = PropertyRules.housePrice(position)
				if canImprove and PropertyRules.canBuild(view, localId, me.money, position) then
					local icon = if property.houses == PropertyRules.HOUSES_PER_HOTEL then "🏨" else "🏠"
					table.insert(buttons, { label = `+{icon} ${price}`, action = { type = "Build", position = position } })
				end
				if PropertyRules.canSell(view, localId, position) then
					local icon = if property.houses == PropertyRules.HOTEL then "🏨" else "🏠"
					table.insert(buttons, {
						label = `−{icon} +${select(2, PropertyRules.sale(view, position))}`,
						action = { type = "SellBuilding", position = position },
					})
				end
			end
			if PropertyRules.canMortgage(view, localId, position) then
				table.insert(buttons, {
					label = `Mortgage +${PropertyRules.mortgageValue(position)}`,
					action = { type = "Mortgage", position = position },
				})
			end
			if canImprove and PropertyRules.canUnmortgage(view, localId, me.money, position) then
				table.insert(buttons, {
					label = `Unmortgage ${PropertyRules.unmortgageCost(position)}`,
					action = { type = "Unmortgage", position = position },
				})
			end
		end
		table.insert(rows, {
			position = position,
			name = tile.name,
			group = tile.group or tile.kind,
			houses = property.houses,
			mortgaged = property.mortgaged,
			buttons = buttons,
		})
	end

	table.sort(rows, function(a, b)
		local kindA, kindB = KIND_ORDER[Tiles.at(a.position).kind], KIND_ORDER[Tiles.at(b.position).kind]
		if kindA ~= kindB then
			return kindA < kindB
		end
		return a.position < b.position
	end)
	return rows
end

export type PropertyGroup = {
	key: string, -- colour group, or "Railroad" / "Utility"
	title: string,
	color: Color3?,
	owned: number,
	size: number, -- how many tiles make the full set
	rows: { PropertyRow },
}

local KIND_TITLES = { Railroad = "Railroads", Utility = "Utilities" }
local KIND_SIZES = { Railroad = 4, Utility = 2 }

-- Property rows gathered into their sets, in the order the sets first appear.
function HudModel.propertyGroups(rows: { PropertyRow }): { PropertyGroup }
	local groups: { PropertyGroup } = {}
	local byKey: { [string]: PropertyGroup } = {}
	for _, row in rows do
		local group = byKey[row.group]
		if not group then
			local colorGroup = ColorGroups[row.group]
			group = {
				key = row.group,
				-- "LightBlue" -> "Light Blue"
				title = KIND_TITLES[row.group] or (row.group:gsub("(%l)(%u)", "%1 %2")),
				color = if colorGroup then colorGroup.color else nil,
				owned = 0,
				size = KIND_SIZES[row.group] or #PropertyRules.groupPositions(row.group),
				rows = {},
			}
			byKey[row.group] = group
			table.insert(groups, group)
		end
		group.owned += 1
		table.insert(group.rows, row)
	end
	return groups
end

-- What the Properties panel says when it has no rows.
function HudModel.noPropertiesText(snapshot: Protocol.Snapshot, localId: string): string
	return if seated(snapshot, localId) then "You don't own any property yet" else "You're not playing in this game"
end

-- The Properties toggle gives way during auctions, when the bid buttons need the whole bar
-- (the panel is view-only then anyway), and once the game is over, when it has no use.
function HudModel.showsPropertiesToggle(snapshot: Protocol.Snapshot): boolean
	return snapshot.phase ~= "Auction" and snapshot.phase ~= "GameOver"
end

export type Standing = {
	name: string,
	netWorth: number,
	bankrupt: boolean,
	winner: boolean,
}

-- Final ranking: players still in by net worth (richest first, then seat), bankrupt players last.
function HudModel.standings(snapshot: Protocol.Snapshot): { Standing }
	local players = table.clone(snapshot.players)
	table.sort(players, function(a, b)
		if a.bankrupt ~= b.bankrupt then
			return not a.bankrupt
		elseif a.netWorth ~= b.netWorth then
			return a.netWorth > b.netWorth
		end
		return a.seat < b.seat
	end)
	local standings = {}
	for _, player in players do
		table.insert(standings, {
			name = player.name,
			netWorth = player.netWorth,
			bankrupt = player.bankrupt,
			winner = player.id == snapshot.winner,
		})
	end
	return standings
end

function HudModel.buildingText(row: PropertyRow): string
	if row.mortgaged then
		return "MORTGAGED"
	elseif row.houses == PropertyRules.HOTEL then
		return "🏨"
	end
	return string.rep("🏠", row.houses)
end

return HudModel
