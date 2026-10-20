--!strict
-- Turns a game's events into the lifetime counters challenges are measured on (Shared.Progress.Stats),
-- per player. One Tally per game: it remembers which colour sets each player has already been
-- counted for, so holding a set (or losing and regaining it) counts once a game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local Types = require(script.Parent.Types)

export type Tally = { sets: { [string]: boolean } }
export type Counts = { [string]: { [string]: number } } -- player id -> stat -> count

local Tally = {}

function Tally.new(): Tally
	return { sets = {} }
end

-- The counts `events` add, and any colour set completed by the state they left.
function Tally.count(tally: Tally, events: { Types.Event }, state: Types.GameState): Counts
	local counts: Counts = {}
	local function add(player: string?, stat: string, n: number?)
		if not player then
			return
		end
		local mine = counts[player]
		if not mine then
			mine = {}
			counts[player] = mine
		end
		mine[stat] = (mine[stat] or 0) + (n or 1)
	end
	for _, event in events do
		local kind = event.type
		if kind == "Rolled" and not event.forCard then
			local a, b = event.dice[1], event.dice[2]
			add(event.player, "rolls")
			if a == b then
				add(event.player, "doubles")
				if a == 1 then
					add(event.player, "snakeEyes")
				elseif a == 6 then
					add(event.player, "boxcars")
				end
			end
		elseif kind == "Moved" and event.passedGo then
			add(event.player, "passGo")
		elseif kind == "Bought" then
			add(event.player, "propertiesBought")
		elseif kind == "AuctionEnded" and event.winner then
			add(event.winner, "auctionsWon")
			add(event.winner, "propertiesBought")
		elseif kind == "Built" then
			add(event.player, if event.hotel then "hotelsBuilt" else "housesBuilt")
		elseif kind == "Paid" and event.reason == "Rent" and event.to then
			add(event.to, "rentCollected", event.amount)
		elseif kind == "SentToJail" then
			add(event.player, "jailVisits")
		elseif kind == "LeftJail" and event.reason == "Doubles" then
			add(event.player, "jailEscapes")
		elseif kind == "CardDrawn" then
			add(event.player, "cardsDrawn")
		elseif kind == "TradeAccepted" then
			add(event.from, "tradesMade")
			add(event.to, "tradesMade")
		elseif kind == "Mortgaged" then
			add(event.player, "mortgages")
		elseif kind == "WentBankrupt" then
			add(event.creditor, "bankruptcies")
		end
	end
	for group in ColorGroups do
		local owner: string? = nil
		local whole = true
		for _, position in PropertyRules.groupPositions(group) do
			local ownership = state.properties[position]
			if not ownership or (owner and ownership.owner ~= owner) then
				whole = false
				break
			end
			owner = ownership.owner
		end
		if whole and owner then
			local key = `{owner}:{group}`
			if not tally.sets[key] then
				tally.sets[key] = true
				add(owner, "monopolies")
			end
		end
	end
	return counts
end

return Tally
