--!strict
-- A property's deed: what it costs, what it earns at each level, and which level applies right now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Line = { label: string, value: string, current: boolean }

export type Deed = {
	position: number,
	name: string,
	kind: string, -- "Property" | "Railroad" | "Utility"
	color: Color3?, -- the colour group's; none for railroads and utilities
	price: number,
	lines: { Line },
	footer: { { label: string, value: string } },
	owner: string?,
	mortgaged: boolean,
}

local DeedModel = {}

-- Mirrors of the server's Rent constants (server-only module); DeedModel.spec pins them equal.
DeedModel.RAILROAD_RENT = { 25, 50, 100, 200 }
DeedModel.UTILITY_MULTIPLIER = { 4, 10 }

local HOUSE_LABELS = { "1 house", "2 houses", "3 houses", "4 houses", "Hotel" }
local UTILITY_LABELS = { "One owned", "Both owned" }

function DeedModel.of(position: number, snapshot: Protocol.Snapshot?): Deed?
	local tile = Tiles.at(position)
	if tile.kind ~= "Property" and tile.kind ~= "Railroad" and tile.kind ~= "Utility" then
		return nil
	end

	local owners: { [number]: Protocol.PropertyView } = {}
	if snapshot then
		for _, property in snapshot.properties do
			owners[property.position] = property
		end
	end
	local ownership = owners[position]
	local owner = if ownership then ownership.owner else nil
	local earning = ownership ~= nil and not ownership.mortgaged

	-- How many tiles matching `matches` the owner holds (mortgaged ones still count toward the set).
	local function ownedCount(matches: (Tiles.Tile) -> boolean): number
		local count = 0
		for _, other in Tiles.list do
			local held = owners[other.position]
			if matches(other) and held and held.owner == owner then
				count += 1
			end
		end
		return count
	end

	local lines: { Line } = {}
	local footer = {}
	if tile.kind == "Property" then
		local rent = tile.rent :: { number }
		local houses = if ownership then ownership.houses else 0
		local groupSize = #PropertyRules.groupPositions(tile.group :: string)
		local fullSet = owner ~= nil and ownedCount(function(other)
			return other.group == tile.group
		end) == groupSize
		table.insert(lines, { label = "Rent", value = `${rent[1]}`, current = earning and houses == 0 and not fullSet })
		table.insert(lines, { label = "With full set", value = `${rent[1] * 2}`, current = earning and houses == 0 and fullSet })
		for level, label in HOUSE_LABELS do
			table.insert(lines, { label = label, value = `${rent[level + 1]}`, current = earning and houses == level })
		end
		table.insert(footer, { label = "House cost", value = `${PropertyRules.housePrice(position)}` })
	elseif tile.kind == "Railroad" then
		local count = if owner then ownedCount(function(other)
			return other.kind == "Railroad"
		end) else 0
		for owned, rent in DeedModel.RAILROAD_RENT do
			table.insert(lines, { label = `{owned} owned`, value = `${rent}`, current = earning and count == owned })
		end
	else
		local count = if owner then ownedCount(function(other)
			return other.kind == "Utility"
		end) else 0
		for owned, multiplier in DeedModel.UTILITY_MULTIPLIER do
			table.insert(lines, { label = UTILITY_LABELS[owned], value = `{multiplier}× dice`, current = earning and count == owned })
		end
	end
	table.insert(footer, { label = "Mortgage value", value = `${PropertyRules.mortgageValue(position)}` })

	local group = if tile.group then ColorGroups[tile.group] else nil
	return {
		position = position,
		name = tile.name,
		kind = tile.kind,
		color = if group then group.color else nil,
		price = tile.price :: number,
		lines = lines,
		footer = footer,
		owner = owner,
		mortgaged = ownership ~= nil and ownership.mortgaged,
	}
end

return DeedModel
