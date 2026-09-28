--!strict
-- Rent owed to a tile's owner. Callers decide whether rent applies (e.g. not to the owner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Types = require(script.Parent.Types)

local Rent = {}

Rent.RAILROAD_RENT = { 25, 50, 100, 200 }
Rent.UTILITY_MULTIPLIER = { 4, 10 }

local function countOwnedOfKind(state: Types.GameState, owner: string, kind: string): number
	local count = 0
	for _, tile in Tiles.list do
		local ownership = state.properties[tile.position]
		if tile.kind == kind and ownership and ownership.owner == owner then
			count += 1
		end
	end
	return count
end

function Rent.ownsGroup(state: Types.GameState, owner: string, group: string): boolean
	for _, tile in Tiles.list do
		if tile.group == group then
			local ownership = state.properties[tile.position]
			if not ownership or ownership.owner ~= owner then
				return false
			end
		end
	end
	return true
end

function Rent.calculate(state: Types.GameState, position: number, diceTotal: number): number
	local ownership = state.properties[position]
	if not ownership or ownership.mortgaged then
		return 0
	end

	local tile = Tiles.at(position)
	if tile.kind == "Property" then
		local rent = tile.rent :: { number }
		if ownership.houses > 0 then
			return rent[ownership.houses + 1]
		elseif Rent.ownsGroup(state, ownership.owner, tile.group :: string) then
			return rent[1] * 2
		end
		return rent[1]
	elseif tile.kind == "Railroad" then
		return Rent.RAILROAD_RENT[countOwnedOfKind(state, ownership.owner, "Railroad")]
	elseif tile.kind == "Utility" then
		return diceTotal * Rent.UTILITY_MULTIPLIER[countOwnedOfKind(state, ownership.owner, "Utility")]
	end
	return 0
end

return Rent
