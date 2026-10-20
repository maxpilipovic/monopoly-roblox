--!strict
-- Daily challenges: three a day (one easy, one medium, one hard), new at midnight UTC. Each player
-- gets their own three, picked from the pools by their user id and the day, and may swap one of
-- them for another of the same difficulty once a day.

local Dailies = {}

export type Daily = { id: string, stat: string, target: number, coins: number, tier: string }

Dailies.TIERS = { "Easy", "Medium", "Hard" }
Dailies.COINS = table.freeze({ Easy = 150, Medium = 250, Hard = 400 })
Dailies.TIER_COLORS = table.freeze({
	Easy = Color3.fromRGB(110, 210, 140),
	Medium = Color3.fromRGB(90, 170, 255),
	Hard = Color3.fromRGB(255, 120, 110),
})
Dailies.SWAPS_PER_DAY = 1
Dailies.DAY_SECONDS = 86400

local POOLS: { [string]: { { any } } } = {
	Easy = {
		{ "games", 2 },
		{ "rolls", 25 },
		{ "doubles", 3 },
		{ "passGo", 4 },
		{ "propertiesBought", 4 },
		{ "cardsDrawn", 4 },
		{ "rentCollected", 500 },
	},
	Medium = {
		{ "games", 4 },
		{ "doubles", 8 },
		{ "propertiesBought", 10 },
		{ "housesBuilt", 6 },
		{ "auctionsWon", 2 },
		{ "tradesMade", 1 },
		{ "rentCollected", 2000 },
		{ "jailVisits", 2 },
		{ "podiums", 2 },
	},
	Hard = {
		{ "wins", 1 },
		{ "hotelsBuilt", 1 },
		{ "monopolies", 2 },
		{ "rentCollected", 5000 },
		{ "bankruptcies", 1 },
		{ "doubles", 15 },
		{ "housesBuilt", 15 },
		{ "podiums", 3 },
	},
}

Dailies.LIST = {} :: { Daily }
Dailies.byId = {} :: { [string]: Daily }
Dailies.pools = {} :: { [string]: { Daily } }
for _, tier in Dailies.TIERS do
	Dailies.pools[tier] = {}
	for _, entry in POOLS[tier] do
		local daily = {
			id = `{tier}_{entry[1]}_{entry[2]}`,
			stat = entry[1],
			target = entry[2],
			coins = Dailies.COINS[tier],
			tier = tier,
		}
		table.insert(Dailies.LIST, daily)
		table.insert(Dailies.pools[tier], daily)
		Dailies.byId[daily.id] = daily
	end
end

function Dailies.dayOf(time: number): number
	return time // Dailies.DAY_SECONDS
end

-- Seconds until the next day's challenges.
function Dailies.secondsLeft(time: number): number
	return (Dailies.dayOf(time) + 1) * Dailies.DAY_SECONDS - time
end

local function randomFor(userId: number, day: number, salt: number): Random
	return Random.new((userId % 1000003) * 7919 + day * 104729 + salt)
end

-- The day's three challenge ids for this player, easy first.
function Dailies.pick(userId: number, day: number): { string }
	local picked = {}
	for index, tier in Dailies.TIERS do
		local pool = Dailies.pools[tier]
		picked[index] = pool[randomFor(userId, day, index):NextInteger(1, #pool)].id
	end
	return picked
end

-- Another challenge of the same difficulty as `current` (never one in `exclude`).
function Dailies.swap(userId: number, day: number, current: string, exclude: { string }): string?
	local daily = Dailies.byId[current]
	if not daily then
		return nil
	end
	local options = {}
	for _, candidate in Dailies.pools[daily.tier] do
		if candidate.id ~= current and not table.find(exclude, candidate.id) then
			table.insert(options, candidate.id)
		end
	end
	if #options == 0 then
		return nil
	end
	return options[randomFor(userId, day, 17):NextInteger(1, #options)]
end

return Dailies
