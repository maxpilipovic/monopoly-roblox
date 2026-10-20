--!strict
-- Lifetime achievements: one track per stat, five tiers each (Bronze to Diamond), measured on the
-- lifetime counter. Each tier is claimed in turn for coins; the higher tiers of some tracks also
-- unlock an exclusive dice skin, aura, piece or title.

local Rewards = require(script.Parent.Rewards)

export type Tier = { target: number, reward: Rewards.Reward }
export type Track = { id: string, name: string, stat: string, tiers: { Tier } }

local Achievements = {}

Achievements.TIER_NAMES = { "Bronze", "Silver", "Gold", "Platinum", "Diamond" }
Achievements.TIER_COLORS = {
	Color3.fromRGB(205, 127, 70),
	Color3.fromRGB(200, 208, 222),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(110, 230, 220),
	Color3.fromRGB(170, 140, 255),
}
Achievements.TIER_COINS = { 100, 250, 600, 1500, 4000 }

-- `unlocks` adds an item to the tier at that index.
local function track(id: string, name: string, stat: string, targets: { number }, unlocks: { [number]: string }?): Track
	local tiers = {}
	for index, target in targets do
		tiers[index] = {
			target = target,
			reward = { coins = Achievements.TIER_COINS[index], item = if unlocks then unlocks[index] else nil },
		}
	end
	return { id = id, name = name, stat = stat, tiers = tiers }
end

Achievements.LIST = {
	track("Winner", "Winner", "wins", { 1, 10, 50, 150, 500 }, { [4] = "DiceGalaxy", [5] = "TitleMogul" }),
	track("Regular", "Regular", "games", { 5, 25, 100, 300, 1000 }, { [3] = "AuraStardust", [5] = "TitleVeteran" }),
	track("Climber", "Ranked Climber", "rankedWins", { 1, 10, 40, 100, 300 }, { [5] = "TitleLegend" }),
	track("Podium", "Podium Finisher", "podiums", { 3, 25, 100, 300, 800 }),
	track("Landlord", "Landlord", "propertiesBought", { 10, 100, 500, 2000, 6000 }),
	track("RentCollector", "Rent Collector", "rentCollected", { 2000, 25000, 150000, 600000, 2000000 }, { [5] = "TitleRentLord" }),
	track("Builder", "Builder", "housesBuilt", { 10, 100, 500, 1500, 5000 }, { [5] = "TitleArchitect" }),
	track("Hotelier", "Hotelier", "hotelsBuilt", { 1, 15, 75, 250, 800 }, { [5] = "TitleHotelier" }),
	track("Monopolist", "Monopolist", "monopolies", { 1, 15, 75, 250, 800 }, { [5] = "TitleMonopolist" }),
	track("Roller", "High Roller", "doubles", { 10, 100, 500, 2000, 6000 }),
	track("SnakeEyes", "Snake Eyes", "snakeEyes", { 1, 10, 50, 150, 500 }, { [5] = "TitleLucky" }),
	track("Globetrotter", "Globetrotter", "passGo", { 10, 100, 500, 2000, 6000 }, { [5] = "TitleGlobetrotter" }),
	track("Jailbird", "Jailbird", "jailVisits", { 3, 25, 100, 300, 1000 }, { [5] = "TitleJailbird" }),
	track("Auctioneer", "Auctioneer", "auctionsWon", { 1, 15, 75, 250, 800 }, { [5] = "TitleAuctioneer" }),
	track("Trader", "Trader", "tradesMade", { 1, 15, 75, 250, 800 }),
	track("Shark", "Shark", "bankruptcies", { 1, 15, 75, 250, 800 }, { [5] = "TitleShark" }),
	track("Collector", "Collector", "chestsOpened", { 1, 10, 50, 150, 400 }, { [4] = "DiceDiamond", [5] = "TitleCollector" }),
	track("Dedicated", "Dedicated", "dailyCompleted", { 3, 30, 150, 500, 1500 }, { [3] = "DiceCandy", [4] = "DiceFrozen", [5] = "TitleDedicated" }),
	track("TreeTopper", "Tree Climber", "treeNodes", { 5, 20, 40, 60, 73 }, { [4] = "BrightIdea", [5] = "TitleTreeTopper" }),
} :: { Track }

Achievements.byId = {} :: { [string]: Track }
for _, t in Achievements.LIST do
	Achievements.byId[t.id] = t
end

return Achievements
