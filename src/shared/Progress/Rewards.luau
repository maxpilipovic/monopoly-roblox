--!strict
-- Coins: what a finished game pays, what chests cost in coins, what a duplicate turns into, and the
-- shape of a challenge reward (coins, an item, or a chest key).

local Rewards = {}

export type Reward = {
	coins: number?,
	item: string?, -- Catalog id
	key: string?, -- a chest id: one free opening of that chest
}

-- A game pays everyone who saw it through: a base, a share for each player finished ahead of, and a
-- bonus for the win, half again in ranked. Nobody is paid for walking out, or for a game they
-- barely played (fewer than MIN_ROLLS rolls: no farming games by leaving bots to it).
Rewards.GAME_BASE = 40
Rewards.GAME_PER_BEATEN = 20
Rewards.GAME_WIN = 100
Rewards.RANKED_MULTIPLIER = 1.5
Rewards.MIN_ROLLS = 6

function Rewards.gameCoins(place: number, players: number, ranked: boolean, finished: boolean, rolls: number): number
	if not finished or rolls < Rewards.MIN_ROLLS then
		return 0
	end
	local coins = Rewards.GAME_BASE + Rewards.GAME_PER_BEATEN * math.max(players - place, 0)
	if place == 1 then
		coins += Rewards.GAME_WIN
	end
	if ranked then
		coins *= Rewards.RANKED_MULTIPLIER
	end
	return math.floor(coins)
end

-- Chests bought with coins.
Rewards.CHEST_COINS = table.freeze({
	Silver = 750,
	Gold = 2000,
	Diamond = 5000,
})

-- An item you already own turns into coins instead.
Rewards.DUPLICATE_COINS = table.freeze({
	Common = 100,
	Rare = 250,
	Epic = 600,
	Legendary = 1500,
})

-- Finishing all three of the day's challenges.
Rewards.DAILY_SWEEP = 300

function Rewards.describe(reward: Reward, itemName: ((string) -> string)?): string
	local parts = {}
	if reward.coins then
		table.insert(parts, `{reward.coins} coins`)
	end
	if reward.item then
		table.insert(parts, if itemName then itemName(reward.item) else reward.item)
	end
	if reward.key then
		table.insert(parts, `{reward.key} Chest key`)
	end
	return table.concat(parts, " + ")
end

return Rewards
