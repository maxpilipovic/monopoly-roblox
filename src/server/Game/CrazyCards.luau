--!strict
-- What the Crazy Chance cards do (Cards.CRAZY). The engine hands over its own helpers for moving
-- money and pieces, so these follow the same rules and emit the same events as everything else.
-- "Richest" and "poorest" go by net worth, ties to the earlier seat. A property can only change
-- hands while its colour set has no buildings. Random picks come from state.random, so tests can
-- script them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Types = require(script.Parent.Types)

type GameState = Types.GameState
type Player = Types.Player

export type Ops = {
	transfer: (state: GameState, fromId: string?, toId: string?, amount: number, reason: string) -> (),
	charge: (state: GameState, payer: Player, creditorId: string?, amount: number, reason: string) -> (),
	moveTo: (state: GameState, player: Player, to: number, style: string, flight: boolean?) -> (),
	emit: (state: GameState, event: Types.Event) -> (),
	jail: (state: GameState, player: Player) -> (), -- into the cell, without ending anyone's move
	release: (state: GameState, player: Player, reason: string?) -> (), -- reason defaults to "Card"
	jailPosition: number,
	houseLimit: number, -- houses on a street before a hotel
}

local CrazyCards = {}

CrazyCards.KINDS = table.freeze({
	SwapWithLeader = true,
	Scatter = true,
	Reverse = true,
	ExtraTurn = true,
	RobinHood = true,
	Lottery = true,
	SplitCash = true,
	Heist = true,
	SwapDeed = true,
	FreeHouse = true,
	Demolition = true,
	MassArrest = true,
	Jailbreak = true,
	BailOut = true,
	RaidKind = true,
})

local function active(state: GameState): { Player }
	local list = {}
	for _, player in state.players do
		if not player.bankrupt then
			table.insert(list, player)
		end
	end
	return list
end

local function worth(state: GameState, player: Player): number
	return PropertyRules.netWorth(state :: any, player.id, player.money)
end

-- The richest (or poorest) of `players`, the earlier seat winning ties.
local function extreme(state: GameState, players: { Player }, richest: boolean): Player?
	local best: Player? = nil
	local bestWorth = 0
	for _, player in players do
		local value = worth(state, player)
		if not best or (richest and value > bestWorth) or (not richest and value < bestWorth) then
			best, bestWorth = player, value
		end
	end
	return best
end

local function others(state: GameState, drawer: Player): { Player }
	local list = {}
	for _, player in active(state) do
		if player ~= drawer then
			table.insert(list, player)
		end
	end
	return list
end

-- Positions this player owns that may change hands: no buildings anywhere in the colour set.
local function movableDeeds(state: GameState, playerId: string): { number }
	local deeds = {}
	for position = 0, Tiles.COUNT - 1 do
		local ownership = state.properties[position]
		if ownership and ownership.owner == playerId then
			local group = Tiles.at(position).group
			local built = false
			if group then
				for _, other in PropertyRules.groupPositions(group) do
					local o = state.properties[other]
					if o and o.houses > 0 then
						built = true
					end
				end
			end
			if not built then
				table.insert(deeds, position)
			end
		end
	end
	return deeds
end

local function pick<T>(state: GameState, list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[state.random(#list)]
end

local function giveDeed(state: GameState, ops: Ops, position: number, toId: string)
	local ownership = state.properties[position] :: Types.Ownership
	local fromId = ownership.owner
	ownership.owner = toId
	ops.emit(state, { type = "DeedMoved", from = fromId, to = toId, position = position })
end

local function teleport(state: GameState, ops: Ops, player: Player, to: number)
	if player.position ~= to then
		ops.moveTo(state, player, to, "Teleport", true)
	end
end

-- The street in one of the player's complete, unmortgaged sets where a free house goes (the one
-- with fewest houses, keeping the set even), or nil.
local function freeHouseSpot(state: GameState, ops: Ops, playerId: string): number?
	local spots = {}
	local seen = {}
	for position = 0, Tiles.COUNT - 1 do
		local group = Tiles.at(position).group
		if group and not seen[group] then
			seen[group] = true
			local best: number? = nil
			local complete = true
			for _, member in PropertyRules.groupPositions(group) do
				local o = state.properties[member]
				if not o or o.owner ~= playerId or o.mortgaged then
					complete = false
					break
				end
				if o.houses < ops.houseLimit and (not best or o.houses < (state.properties[best] :: Types.Ownership).houses) then
					best = member
				end
			end
			if complete and best then
				table.insert(spots, best)
			end
		end
	end
	return pick(state, spots)
end

-- Applies a crazy card's effect. The engine ends the move afterwards (the drawer never resolves a
-- landing: pieces moved by a crazy card just arrive).
function CrazyCards.apply(state: GameState, drawer: Player, effect: Cards.Effect, ops: Ops)
	local kind = effect.kind
	if kind == "SwapWithLeader" then
		local richest = extreme(state, active(state), true)
		local partner = if richest == drawer then extreme(state, others(state, drawer), false) else extreme(state, others(state, drawer), true)
		if partner then
			local mine, theirs = drawer.position, partner.position
			teleport(state, ops, drawer, theirs)
			teleport(state, ops, partner, mine)
		end
	elseif kind == "Scatter" then
		for _, player in active(state) do
			if not player.inJail then
				teleport(state, ops, player, state.random(Tiles.COUNT) - 1)
			end
		end
	elseif kind == "Reverse" then
		state.direction = -state.direction
		ops.emit(state, { type = "TurnOrderReversed", player = drawer.id })
	elseif kind == "ExtraTurn" then
		state.rollAgain = true
	elseif kind == "RobinHood" then
		local players = active(state)
		local richest, poorest = extreme(state, players, true), extreme(state, players, false)
		if richest and poorest and richest ~= poorest then
			ops.charge(state, richest, poorest.id, effect.amount :: number, "RobinHood")
		end
	elseif kind == "Lottery" then
		local stake = effect.amount :: number
		local entrants = {}
		for _, player in active(state) do
			if player.money >= stake then
				ops.transfer(state, player.id, nil, stake, "Lottery")
				table.insert(entrants, player)
			end
		end
		local winner = pick(state, entrants)
		if winner then
			ops.transfer(state, nil, winner.id, stake * #entrants, "Lottery")
		end
	elseif kind == "SplitCash" then
		local players = active(state)
		local total = 0
		for _, player in players do
			total += player.money
		end
		local share = total // #players
		-- Everyone above the share pays in first, then everyone below is paid out.
		for _, player in players do
			if player.money > share then
				ops.transfer(state, player.id, nil, player.money - share, "Split")
			end
		end
		for _, player in players do
			if player.money < share then
				ops.transfer(state, nil, player.id, share - player.money, "Split")
			end
		end
	elseif kind == "Heist" then
		local target = extreme(state, others(state, drawer), true)
		local position = if target then pick(state, movableDeeds(state, target.id)) else nil
		if position then
			giveDeed(state, ops, position, drawer.id)
		end
	elseif kind == "SwapDeed" then
		local mine = pick(state, movableDeeds(state, drawer.id))
		local partners = {}
		for _, player in others(state, drawer) do
			if #movableDeeds(state, player.id) > 0 then
				table.insert(partners, player)
			end
		end
		local partner = pick(state, partners)
		local theirs = if partner then pick(state, movableDeeds(state, partner.id)) else nil
		if mine and partner and theirs then
			giveDeed(state, ops, mine, partner.id)
			giveDeed(state, ops, theirs, drawer.id)
		end
	elseif kind == "FreeHouse" then
		local spot = if state.bankHouses > 0 then freeHouseSpot(state, ops, drawer.id) else nil
		if spot then
			local ownership = state.properties[spot] :: Types.Ownership
			ownership.houses += 1
			state.bankHouses -= 1
			ops.emit(state, { type = "Built", player = drawer.id, position = spot, amount = 0, hotel = false, free = true })
		else
			ops.transfer(state, nil, drawer.id, effect.amount :: number, "Card")
		end
	elseif kind == "Demolition" then
		local count = 0
		for position = 0, Tiles.COUNT - 1 do
			local ownership = state.properties[position]
			if ownership and ownership.houses > 0 then
				if ownership.houses > ops.houseLimit then
					-- A hotel goes back for four houses, if the bank has them.
					if state.bankHouses >= ops.houseLimit then
						ownership.houses = ops.houseLimit
						state.bankHotels += 1
						state.bankHouses -= ops.houseLimit
						count += 1
					end
				else
					ownership.houses -= 1
					state.bankHouses += 1
					count += 1
				end
			end
		end
		ops.emit(state, { type = "Demolished", player = drawer.id, count = count })
	elseif kind == "MassArrest" then
		for _, player in others(state, drawer) do
			if not player.inJail then
				ops.jail(state, player)
			end
		end
	elseif kind == "Jailbreak" then
		for _, player in active(state) do
			if player.inJail then
				ops.release(state, player)
			end
		end
	elseif kind == "BailOut" then
		-- Each jailed player walks as soon as their bail is charged; bail the drawer can't pay is an
		-- ordinary debt. With nobody to bail out, the buddy gets arrested instead.
		local jailed = {}
		for _, player in others(state, drawer) do
			if player.inJail then
				table.insert(jailed, player)
			end
		end
		if #jailed == 0 then
			local buddy = pick(state, others(state, drawer))
			if buddy then
				ops.jail(state, buddy)
			end
		end
		for _, player in jailed do
			ops.charge(state, drawer, nil, effect.amount :: number, "Bail")
			ops.release(state, player, "Bail")
		end
	elseif kind == "RaidKind" then
		local raided = {}
		for _, player in active(state) do
			if not player.inJail and Tiles.at(player.position).kind == effect.tileKind then
				table.insert(raided, player)
			end
		end
		for _, player in raided do
			ops.jail(state, player)
		end
		if #raided == 0 then
			ops.emit(state, { type = "RaidFoundNobody", player = drawer.id })
		end
	else
		error(`not a crazy card effect: {kind}`)
	end
end

return CrazyCards
