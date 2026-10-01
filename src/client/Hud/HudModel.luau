--!strict
-- What the HUD should show for a snapshot: a status line and the buttons the local player may press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
