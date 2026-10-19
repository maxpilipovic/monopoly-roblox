--!strict
-- Where everyone finished, for ranked ratings. Players still solvent at the end come first: the winner,
-- then the rest by net worth (equal net worth shares a place). The bankrupt follow in reverse order of
-- going broke, so lasting longer places higher. Someone walking out of a game places as if they went
-- broke that moment: behind everyone still in, ahead of anyone already out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Types = require(script.Parent.Types)

local Placement = {}

-- Places `ranked` (best first) with ties for equal `key`s; returns the next free place.
local function assign(places: { [string]: number }, ranked: { { id: string, key: number } }, from: number): number
	local place = from
	for index, entry in ranked do
		if index > 1 and entry.key ~= ranked[index - 1].key then
			place = from + index - 1
		end
		places[entry.id] = place
	end
	return from + #ranked
end

local function solventOrder(state: Types.GameState, except: string?): { { id: string, key: number } }
	local ranked = {}
	for _, player in state.players do
		if not player.bankrupt and player.id ~= except then
			local worth = PropertyRules.netWorth(state, player.id, player.money)
			-- The winner sorts first even on equal net worth (the engine broke that tie).
			local key = if player.id == state.winner then math.huge else worth
			table.insert(ranked, { id = player.id, key = key })
		end
	end
	table.sort(ranked, function(a, b)
		return a.key > b.key
	end)
	return ranked
end

local function brokeOrder(state: Types.GameState, places: { [string]: number }, from: number)
	local order = state.bankruptOrder
	local place = from
	for index = #order, 1, -1 do
		local id = order[index]
		if places[id] == nil then
			places[id] = place
			place += 1
		end
	end
	-- Anyone bankrupt but missing from the order (shouldn't happen) comes last.
	for _, player in state.players do
		if places[player.id] == nil then
			places[player.id] = place
			place += 1
		end
	end
end

function Placement.of(state: Types.GameState): { [string]: number }
	local places: { [string]: number } = {}
	local nextPlace = assign(places, solventOrder(state, nil), 1)
	brokeOrder(state, places, nextPlace)
	return places
end

function Placement.leaving(state: Types.GameState, leaverId: string): { [string]: number }
	local places: { [string]: number } = {}
	local nextPlace = assign(places, solventOrder(state, leaverId), 1)
	places[leaverId] = nextPlace
	brokeOrder(state, places, nextPlace + 1)
	return places
end

function Placement.ordinal(place: number): string
	local lastTwo = place % 100
	local suffix = if lastTwo >= 11 and lastTwo <= 13 then "th"
		elseif place % 10 == 1 then "st"
		elseif place % 10 == 2 then "nd"
		elseif place % 10 == 3 then "rd"
		else "th"
	return `{place}{suffix}`
end

return Placement
