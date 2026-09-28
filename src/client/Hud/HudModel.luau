--!strict
-- What the HUD should show for a snapshot: a status line and the buttons the local player may press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Button = {
	label: string,
	action: { [string]: any },
}

local HudModel = {}

HudModel.BID_STEPS = { 10, 50, 100 }
HudModel.JAIL_FINE = 50 -- mirrors Engine.JAIL_FINE (server-only)

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

local function actingPlayer(snapshot: Protocol.Snapshot): string?
	if snapshot.phase == "GameOver" then
		return nil
	elseif snapshot.auction then
		return snapshot.auction.currentBidder
	end
	return snapshot.currentPlayer
end

function HudModel.buttons(snapshot: Protocol.Snapshot, localId: string): { Button }
	local me = findPlayer(snapshot, localId)
	if not me or actingPlayer(snapshot) ~= localId then
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
	elseif phase == "EndTurn" then
		return { { label = "End turn", action = { type = "EndTurn" } } }
	end
	return {}
end

function HudModel.status(snapshot: Protocol.Snapshot, localId: string): string
	local names = HudModel.names(snapshot)
	local auction = snapshot.auction
	if auction then
		local tile = Tiles.at(auction.position).name
		if auction.highBidder then
			return `Auction: {tile} — high bid ${auction.highBid} ({names[auction.highBidder]})`
		end
		return `Auction: {tile} — no bids yet`
	end
	if snapshot.currentPlayer == localId then
		local me = findPlayer(snapshot, localId)
		if me and me.inJail and snapshot.phase == "Roll" then
			return "Your turn — you're in jail"
		end
		return "Your turn"
	end
	return `Waiting for {names[snapshot.currentPlayer] or snapshot.currentPlayer}`
end

return HudModel
