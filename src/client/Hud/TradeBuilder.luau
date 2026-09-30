--!strict
-- The trade window's working offer: who it's for and what each side puts in. Pure, so the
-- window only draws it; TradeRules (the same rules the server uses) decides if it may be sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local TradeRules = require(ReplicatedStorage.Shared.Rules.TradeRules)
local HudModel = require(script.Parent.HudModel)

export type SideName = "give" | "get"

export type Builder = {
	partner: string?,
	give: TradeRules.Side,
	get: TradeRules.Side,
}

export type DeedRow = {
	position: number,
	name: string,
	selected: boolean,
	mortgaged: boolean,
	tradable: boolean,
	reason: string?,
}

local TradeBuilder = {}

local function emptySide(): TradeRules.Side
	return { properties = {}, cash = 0, jailCards = 0 }
end

function TradeBuilder.new(): Builder
	return { partner = nil, give = emptySide(), get = emptySide() }
end

function TradeBuilder.setPartner(builder: Builder, id: string)
	builder.partner = id
	builder.give = emptySide()
	builder.get = emptySide()
end

function TradeBuilder.toggle(builder: Builder, sideName: SideName, position: number)
	local properties = builder[sideName].properties
	local index = table.find(properties, position)
	if index then
		table.remove(properties, index)
	else
		table.insert(properties, position)
	end
end

function TradeBuilder.stepCash(builder: Builder, sideName: SideName, delta: number, max: number)
	local side = builder[sideName]
	side.cash = math.clamp(side.cash + delta, 0, math.max(max, 0))
end

function TradeBuilder.stepJailCards(builder: Builder, sideName: SideName, delta: number, max: number)
	local side = builder[sideName]
	side.jailCards = math.clamp(side.jailCards + delta, 0, math.max(max, 0))
end

function TradeBuilder.offer(builder: Builder): TradeRules.Offer
	return TradeRules.copy({ to = builder.partner or "", give = builder.give, get = builder.get })
end

function TradeBuilder.partners(snapshot: Protocol.Snapshot, localId: string): { { id: string, name: string } }
	local partners = {}
	for _, player in snapshot.players do
		if player.id ~= localId and not player.bankrupt then
			table.insert(partners, { id = player.id, name = player.name })
		end
	end
	return partners
end

function TradeBuilder.rows(snapshot: Protocol.Snapshot, ownerId: string, side: TradeRules.Side): { DeedRow }
	local view = HudModel.rulesView(snapshot)
	local rows = {}
	for _, property in snapshot.properties do -- already sorted by position
		if property.owner == ownerId then
			local tradable, reason = TradeRules.tradable(view, property.position)
			table.insert(rows, {
				position = property.position,
				name = Tiles.at(property.position).name,
				selected = table.find(side.properties, property.position) ~= nil,
				mortgaged = property.mortgaged,
				tradable = tradable,
				reason = reason,
			})
		end
	end
	return rows
end

function TradeBuilder.check(snapshot: Protocol.Snapshot, localId: string, builder: Builder): (boolean, string?)
	if not builder.partner then
		return false, "pick a player"
	end
	-- The snapshot only shows the open debt; the server also checks debts still waiting in the queue.
	local debtor = if snapshot.debt then snapshot.debt.debtor else nil
	local parties = {}
	for _, player in snapshot.players do
		parties[player.id] = {
			id = player.id,
			name = player.name,
			money = player.money,
			jailCards = player.jailCards,
			bankrupt = player.bankrupt,
			inDebt = player.id == debtor,
		}
	end
	return TradeRules.validate(HudModel.rulesView(snapshot), parties, localId, TradeBuilder.offer(builder))
end

return TradeBuilder
