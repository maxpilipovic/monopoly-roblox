--!strict
-- The lifetime counters every challenge is measured on, and how a goal on each one reads
-- ("Roll 5 doubles"). Counted by the server from game events (Tally), results and the shop.

export type Stat = {
	id: string,
	one: string, -- the goal for a single one, e.g. "Win a game"
	many: string, -- the goal for n, with {n} where the number goes, e.g. "Win {n} games"
	icon: string, -- the client's Icons name
	money: boolean?, -- counted in dollars (shown as $1,500)
}

local Stats = {}

local function stat(id: string, icon: string, one: string, many: string, money: boolean?): Stat
	return { id = id, icon = icon, one = one, many = many, money = money }
end

Stats.LIST = {
	stat("games", "Dice", "Play a game", "Play {n} games"),
	stat("wins", "Trophy", "Win a game", "Win {n} games"),
	stat("podiums", "Podium", "Finish in the top two", "Finish in the top two {n} times"),
	stat("rankedWins", "Swords", "Win a ranked game", "Win {n} ranked games"),
	stat("rolls", "Dice", "Roll the dice", "Roll the dice {n} times"),
	stat("doubles", "Doubles", "Roll doubles", "Roll {n} doubles"),
	stat("snakeEyes", "SnakeEyes", "Roll snake eyes (1 + 1)", "Roll snake eyes (1 + 1) {n} times"),
	stat("boxcars", "Boxcars", "Roll boxcars (6 + 6)", "Roll boxcars (6 + 6) {n} times"),
	stat("passGo", "Go", "Pass GO", "Pass GO {n} times"),
	stat("propertiesBought", "Deed", "Buy a property", "Buy {n} properties"),
	stat("rentCollected", "Cash", "Collect rent", "Collect {n} in rent", true),
	stat("housesBuilt", "House", "Build a house", "Build {n} houses"),
	stat("hotelsBuilt", "Hotel", "Build a hotel", "Build {n} hotels"),
	stat("monopolies", "ColorSet", "Complete a colour set", "Complete {n} colour sets"),
	stat("jailVisits", "Jail", "Go to jail", "Go to jail {n} times"),
	stat("jailEscapes", "LockOpen", "Roll doubles to break out of jail", "Roll doubles to break out of jail {n} times"),
	stat("cardsDrawn", "Chance", "Draw a Chance or Chest card", "Draw {n} Chance or Chest cards"),
	stat("auctionsWon", "Gavel", "Win an auction", "Win {n} auctions"),
	stat("tradesMade", "Trade", "Complete a trade", "Complete {n} trades"),
	stat("mortgages", "Mortgage", "Mortgage a property", "Mortgage {n} properties"),
	stat("bankruptcies", "BrokenCoin", "Bankrupt an opponent", "Bankrupt {n} opponents"),
	stat("chestsOpened", "Chest", "Open a chest", "Open {n} chests"),
	stat("dailyCompleted", "Calendar", "Complete a daily challenge", "Complete {n} daily challenges"),
	stat("coinsEarned", "Coins", "Earn coins", "Earn {n} coins"),
	stat("treeNodes", "Tree", "Claim an Empire Tree node", "Claim {n} Empire Tree nodes"),
} :: { Stat }

Stats.byId = {} :: { [string]: Stat }
for _, s in Stats.LIST do
	Stats.byId[s.id] = s
end

-- 1234567 -> "1,234,567"
function Stats.commas(n: number): string
	local text = tostring(math.floor(n))
	local sign, digits = text:match("^(%-?)(%d+)$")
	if not digits then
		return text
	end
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (sign or "") .. formatted
end

function Stats.amount(statId: string, n: number): string
	local s = Stats.byId[statId]
	return if s and s.money then "$" .. Stats.commas(n) else Stats.commas(n)
end

-- The goal "do `target` of `statId`" in words.
function Stats.goal(statId: string, target: number): string
	local s = assert(Stats.byId[statId], `no stat {statId}`)
	if target == 1 and not s.money then
		return s.one
	end
	return (s.many:gsub("{n}", Stats.amount(statId, target)))
end

return Stats
