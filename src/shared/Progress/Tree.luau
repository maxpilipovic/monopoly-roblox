--!strict
-- The Empire Tree: the long grind. A root in the middle and six branches growing out of it, each a
-- spine of nine challenges with a three-challenge spur forking off its fourth. A node opens when
-- the one before it is claimed, and only counts what you do from then on (its `start`), so every
-- node is fresh play. Rewards climb along a branch: coins, chest keys, dice skins, auras, titles,
-- an exclusive piece halfway and a legendary piece at the tip.

local Rewards = require(script.Parent.Rewards)

export type Node = {
	id: string,
	branch: string?, -- nil for the root
	parent: string?,
	stat: string,
	target: number,
	reward: Rewards.Reward,
	position: Vector2, -- on the tree's map, root at (0, 0), in map units
	tip: boolean?, -- the branch's last node
}

export type Branch = { id: string, name: string, color: Color3, angle: number, blurb: string }

local Tree = {}

Tree.ROOT = "Root"
Tree.RADIUS_START = 170 -- the first node of each branch, from the root
Tree.STEP = 112 -- between nodes along a branch
Tree.SPUR_ANGLE = 17 -- degrees off the spine
Tree.SPUR_FROM = 4 -- the spine node the spur forks from

type Entry = { any } -- { stat, target, reward }

local function coins(n: number): Rewards.Reward
	return { coins = n }
end
local function item(id: string): Rewards.Reward
	return { item = id }
end
local function key(chest: string): Rewards.Reward
	return { key = chest }
end

local BRANCHES: { { branch: Branch, spine: { Entry }, spur: { Entry } } } = {
	{
		branch = { id = "Tycoon", name = "Tycoon", color = Color3.fromRGB(255, 200, 70), angle = -90, blurb = "Buy up the board and bleed it for rent." },
		spine = {
			{ "propertiesBought", 5, coins(150) },
			{ "rentCollected", 1500, coins(200) },
			{ "propertiesBought", 15, item("TitleLandlord") },
			{ "rentCollected", 5000, key("Silver") },
			{ "monopolies", 3, coins(400) },
			{ "propertiesBought", 40, item("AuraGoldDust") },
			{ "rentCollected", 20000, coins(600) },
			{ "wins", 5, key("Gold") },
			{ "rentCollected", 50000, item("TreasureChest") },
		},
		spur = {
			{ "propertiesBought", 25, coins(300) },
			{ "rentCollected", 10000, item("GoldenTopHat") },
			{ "monopolies", 6, item("TitleTycoon") },
		},
	},
	{
		branch = { id = "Builder", name = "Builder", color = Color3.fromRGB(90, 210, 120), angle = -30, blurb = "Houses, hotels, and colour sets to put them on." },
		spine = {
			{ "housesBuilt", 5, coins(150) },
			{ "monopolies", 1, coins(200) },
			{ "housesBuilt", 15, item("DiceBrick") },
			{ "hotelsBuilt", 2, key("Silver") },
			{ "housesBuilt", 30, coins(400) },
			{ "monopolies", 5, item("LittleHouse") },
			{ "hotelsBuilt", 6, coins(600) },
			{ "housesBuilt", 60, key("Gold") },
			{ "hotelsBuilt", 15, item("GrandHotel") },
		},
		spur = {
			{ "housesBuilt", 20, coins(300) },
			{ "hotelsBuilt", 4, item("AuraBlueprint") },
			{ "monopolies", 8, item("TitleMasterBuilder") },
		},
	},
	{
		branch = { id = "HighRoller", name = "High Roller", color = Color3.fromRGB(190, 120, 255), angle = 30, blurb = "Doubles, snake eyes and the luck of the draw." },
		spine = {
			{ "rolls", 30, coins(150) },
			{ "doubles", 5, coins(200) },
			{ "cardsDrawn", 10, item("DiceClover") },
			{ "snakeEyes", 1, key("Silver") },
			{ "doubles", 15, coins(400) },
			{ "boxcars", 2, item("DiceLava") },
			{ "cardsDrawn", 40, coins(600) },
			{ "doubles", 40, key("Gold") },
			{ "snakeEyes", 5, item("MysteryBox") },
		},
		spur = {
			{ "rolls", 150, coins(300) },
			{ "cardsDrawn", 25, item("AuraClover") },
			{ "doubles", 25, item("TitleHighRoller") },
		},
	},
	{
		branch = { id = "Outlaw", name = "Outlaw", color = Color3.fromRGB(255, 96, 96), angle = 90, blurb = "Jail time, jailbreaks and ruined rivals." },
		spine = {
			{ "jailVisits", 2, coins(150) },
			{ "jailEscapes", 1, coins(200) },
			{ "bankruptcies", 1, item("DiceBone") },
			{ "jailVisits", 8, key("Silver") },
			{ "jailEscapes", 5, coins(400) },
			{ "bankruptcies", 3, item("GhostShip") },
			{ "jailVisits", 20, coins(600) },
			{ "bankruptcies", 8, key("Gold") },
			{ "jailEscapes", 15, item("ShadowRacer") },
		},
		spur = {
			{ "jailVisits", 12, coins(300) },
			{ "bankruptcies", 5, item("AuraShadow") },
			{ "jailEscapes", 10, item("TitleEscapeArtist") },
		},
	},
	{
		branch = { id = "Dealmaker", name = "Dealmaker", color = Color3.fromRGB(80, 170, 255), angle = 150, blurb = "Auctions, trades and creative financing." },
		spine = {
			{ "auctionsWon", 1, coins(150) },
			{ "tradesMade", 1, coins(200) },
			{ "auctionsWon", 4, item("DiceMoney") },
			{ "tradesMade", 3, key("Silver") },
			{ "mortgages", 5, coins(400) },
			{ "auctionsWon", 10, item("WaterWorks") },
			{ "tradesMade", 8, coins(600) },
			{ "auctionsWon", 20, key("Gold") },
			{ "tradesMade", 15, item("ExpressTrain") },
		},
		spur = {
			{ "mortgages", 12, coins(300) },
			{ "auctionsWon", 15, item("AuraCashFlow") },
			{ "tradesMade", 12, item("TitleDealmaker") },
		},
	},
	{
		branch = { id = "Champion", name = "Champion", color = Color3.fromRGB(255, 150, 60), angle = 210, blurb = "Games, wins and ranked glory." },
		spine = {
			{ "games", 3, coins(150) },
			{ "wins", 1, coins(200) },
			{ "passGo", 20, item("DiceChampion") },
			{ "podiums", 3, key("Silver") },
			{ "wins", 3, coins(400) },
			{ "games", 15, item("Flagship") },
			{ "wins", 8, coins(600) },
			{ "passGo", 150, key("Gold") },
			{ "wins", 15, item("PlatinumTrophy") },
		},
		spur = {
			{ "rankedWins", 1, coins(300) },
			{ "rankedWins", 3, item("AuraStarburst") },
			{ "rankedWins", 10, item("TitleChampion") },
		},
	},
}

Tree.BRANCHES = {} :: { Branch }
Tree.NODES = {} :: { Node }
Tree.byId = {} :: { [string]: Node }
Tree.children = {} :: { [string]: { string } }

local function polar(angle: number, radius: number): Vector2
	local r = math.rad(angle)
	return Vector2.new(math.cos(r) * radius, math.sin(r) * radius)
end

local function add(node: Node)
	table.insert(Tree.NODES, node)
	Tree.byId[node.id] = node
	Tree.children[node.id] = {}
	if node.parent then
		table.insert(Tree.children[node.parent], node.id)
	end
end

add({ id = Tree.ROOT, stat = "games", target = 1, reward = { coins = 100 }, position = Vector2.zero })
for _, entry in BRANCHES do
	local branch = entry.branch
	table.insert(Tree.BRANCHES, branch)
	local parent = Tree.ROOT
	for index, spec in entry.spine do
		local id = `{branch.id}{index}`
		add({
			id = id,
			branch = branch.id,
			parent = parent,
			stat = spec[1],
			target = spec[2],
			reward = spec[3],
			position = polar(branch.angle, Tree.RADIUS_START + (index - 1) * Tree.STEP),
			tip = index == #entry.spine,
		})
		parent = id
	end
	parent = `{branch.id}{Tree.SPUR_FROM}`
	for index, spec in entry.spur do
		local id = `{branch.id}S{index}`
		add({
			id = id,
			branch = branch.id,
			parent = parent,
			stat = spec[1],
			target = spec[2],
			reward = spec[3],
			position = polar(branch.angle + Tree.SPUR_ANGLE, Tree.RADIUS_START + (Tree.SPUR_FROM - 1 + index) * Tree.STEP),
		})
		parent = id
	end
end

Tree.branchById = {} :: { [string]: Branch }
for _, branch in Tree.BRANCHES do
	Tree.branchById[branch.id] = branch
end

-- How far the map reaches from the root in any direction.
Tree.EXTENT = Tree.RADIUS_START + 8 * Tree.STEP

return Tree
