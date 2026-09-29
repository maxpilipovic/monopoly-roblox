--!strict
-- Whether a player may build, sell, mortgage or unmortgage, and what it costs. Pure: works on any
-- view with properties + the bank's supply, so the server (GameState) and the HUD (snapshot) agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Ownership = {
	owner: string,
	houses: number, -- 0-4 houses, 5 = hotel
	mortgaged: boolean,
}

export type View = {
	properties: { [number]: Ownership },
	bankHouses: number,
	bankHotels: number,
}

local PropertyRules = {}

PropertyRules.HOTEL = 5
PropertyRules.HOUSES_PER_HOTEL = 4

local groupCache: { [string]: { number } } = {}

function PropertyRules.groupPositions(group: string): { number }
	local cached = groupCache[group]
	if not cached then
		local positions = {}
		for _, tile in Tiles.list do
			if tile.group == group then
				table.insert(positions, tile.position)
			end
		end
		cached = table.freeze(positions)
		groupCache[group] = cached
	end
	return cached
end

function PropertyRules.housePrice(position: number): number
	local tile = Tiles.at(position)
	assert(tile.kind == "Property", `{tile.name} can't have buildings`)
	return ColorGroups[tile.group :: string].houseCost
end

function PropertyRules.mortgageValue(position: number): number
	return (Tiles.at(position).price :: number) // 2
end

function PropertyRules.unmortgageCost(position: number): number
	local value = PropertyRules.mortgageValue(position)
	return value + math.ceil(value / 10) -- integer math: value * 1.1 has rounding error
end

local function owned(view: View, playerId: string, position: number): Ownership?
	local ownership = view.properties[position]
	return if ownership and ownership.owner == playerId then ownership else nil
end

function PropertyRules.canBuild(view: View, playerId: string, money: number, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	end
	local tile = Tiles.at(position)
	if tile.kind ~= "Property" then
		return false, "only streets can have buildings"
	end
	local fewest = math.huge
	for _, other in PropertyRules.groupPositions(tile.group :: string) do
		local otherOwnership = owned(view, playerId, other)
		if not otherOwnership then
			return false, "you need the whole color set"
		elseif otherOwnership.mortgaged then
			return false, "a property in this set is mortgaged"
		end
		fewest = math.min(fewest, otherOwnership.houses)
	end
	if ownership.houses >= PropertyRules.HOTEL then
		return false, "it already has a hotel"
	elseif ownership.houses > fewest then
		return false, "build evenly across the set"
	elseif ownership.houses == PropertyRules.HOUSES_PER_HOTEL and view.bankHotels < 1 then
		return false, "the bank has no hotels left"
	elseif ownership.houses < PropertyRules.HOUSES_PER_HOTEL and view.bankHouses < 1 then
		return false, "the bank has no houses left"
	elseif money < PropertyRules.housePrice(position) then
		return false, "not enough money"
	end
	return true
end

function PropertyRules.canSell(view: View, playerId: string, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	elseif ownership.houses == 0 then
		return false, "no buildings to sell"
	end
	for _, other in PropertyRules.groupPositions(Tiles.at(position).group :: string) do
		local otherOwnership = view.properties[other]
		if otherOwnership and otherOwnership.houses > ownership.houses then
			return false, "sell evenly across the set"
		end
	end
	if ownership.houses == PropertyRules.HOTEL and view.bankHouses < PropertyRules.HOUSES_PER_HOTEL then
		return false, "the bank doesn't have 4 houses to replace the hotel"
	end
	return true
end

function PropertyRules.canMortgage(view: View, playerId: string, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	elseif ownership.mortgaged then
		return false, "it is already mortgaged"
	end
	local tile = Tiles.at(position)
	if tile.kind == "Property" then
		for _, other in PropertyRules.groupPositions(tile.group :: string) do
			local otherOwnership = view.properties[other]
			if otherOwnership and otherOwnership.houses > 0 then
				return false, "sell the buildings in this set first"
			end
		end
	end
	return true
end

function PropertyRules.canUnmortgage(view: View, playerId: string, money: number, position: number): (boolean, string?)
	local ownership = owned(view, playerId, position)
	if not ownership then
		return false, "you don't own it"
	elseif not ownership.mortgaged then
		return false, "it isn't mortgaged"
	elseif money < PropertyRules.unmortgageCost(position) then
		return false, "not enough money"
	end
	return true
end

-- What a player is worth if everything were counted at face value: used to rank players at the end.
function PropertyRules.netWorth(view: View, playerId: string, money: number): number
	local worth = money
	for position, ownership in view.properties do
		if ownership.owner ~= playerId then
			continue
		end
		worth += if ownership.mortgaged
			then PropertyRules.mortgageValue(position)
			else Tiles.at(position).price :: number
		if ownership.houses > 0 then
			worth += ownership.houses * PropertyRules.housePrice(position)
		end
	end
	return worth
end

return PropertyRules
