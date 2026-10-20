--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Achievements = require(ReplicatedStorage.Shared.Progress.Achievements)
local Dailies = require(ReplicatedStorage.Shared.Progress.Dailies)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Rewards = require(ReplicatedStorage.Shared.Progress.Rewards)
local Stats = require(ReplicatedStorage.Shared.Progress.Stats)
local Tree = require(ReplicatedStorage.Shared.Progress.Tree)
local Expect = require(script.Parent.Expect)

local tests = {}

local function fresh(): Progress.Data
	local data = {
		coins = 0,
		counters = {},
		keys = {},
		daily = Progress.newDaily(),
		achievements = {},
		tree = { claimed = {}, starts = {} },
		inventory = {},
	}
	Progress.ensureTree(data)
	return data
end

tests["every challenge names a real stat and every reward a real item or chest"] = function()
	local function checkReward(reward: Rewards.Reward, where: string)
		if reward.item then
			Expect.equal(Catalog.byId[reward.item] ~= nil, true, `{where}: item {reward.item}`)
		end
		if reward.key then
			Expect.equal(Rewards.CHEST_COINS[reward.key] ~= nil, true, `{where}: key {reward.key}`)
		end
	end
	for _, daily in Dailies.LIST do
		Expect.equal(Stats.byId[daily.stat] ~= nil, true, daily.id)
	end
	for _, track in Achievements.LIST do
		Expect.equal(Stats.byId[track.stat] ~= nil, true, track.id)
		Expect.equal(#track.tiers, 5, track.id)
		for index, tier in track.tiers do
			checkReward(tier.reward, track.id)
			if index > 1 then
				Expect.equal(tier.target > track.tiers[index - 1].target, true, `{track.id} tiers climb`)
			end
		end
	end
	for _, node in Tree.NODES do
		Expect.equal(Stats.byId[node.stat] ~= nil, true, node.id)
		checkReward(node.reward, node.id)
		if node.parent then
			Expect.equal(Tree.byId[node.parent] ~= nil, true, `{node.id} parent`)
		end
	end
end

tests["every exclusive item can be won from some challenge"] = function()
	local rewarded = {}
	for _, track in Achievements.LIST do
		for _, tier in track.tiers do
			if tier.reward.item then
				rewarded[tier.reward.item] = true
			end
		end
	end
	for _, node in Tree.NODES do
		if node.reward.item then
			rewarded[node.reward.item] = true
		end
	end
	for _, item in Catalog.ITEMS do
		if item.exclusive then
			Expect.equal(rewarded[item.id], true, `{item.id} has no way to be won`)
		end
	end
end

tests["the tree has a root, six branches of twelve, and its last achievement tier is the whole tree"] = function()
	Expect.equal(#Tree.BRANCHES, 6)
	Expect.equal(#Tree.NODES, 73)
	Expect.equal(Tree.byId.Root.parent, nil)
	Expect.equal(Achievements.byId.TreeTopper.tiers[5].target, #Tree.NODES)
	-- Nodes never sit on top of each other on the map.
	for i, a in Tree.NODES do
		for j = i + 1, #Tree.NODES do
			local b = Tree.NODES[j]
			Expect.equal((a.position - b.position).Magnitude > 90, true, `{a.id} and {b.id} overlap`)
		end
	end
end

tests["goals read naturally, with money and thousands"] = function()
	Expect.equal(Stats.goal("wins", 1), "Win a game")
	Expect.equal(Stats.goal("doubles", 5), "Roll 5 doubles")
	Expect.equal(Stats.goal("rentCollected", 1500), "Collect $1,500 in rent")
	Expect.equal(Stats.goal("passGo", 6000), "Pass GO 6,000 times")
	Expect.equal(Stats.commas(2000000), "2,000,000")
end

tests["a game pays by place, more for a win and in ranked, nothing for leaving or barely playing"] = function()
	Expect.equal(Rewards.gameCoins(1, 4, false, true, 20), 40 + 60 + 100)
	Expect.equal(Rewards.gameCoins(4, 4, false, true, 20), 40)
	Expect.equal(Rewards.gameCoins(1, 2, true, true, 20), math.floor((40 + 20 + 100) * 1.5))
	Expect.equal(Rewards.gameCoins(1, 4, false, false, 20), 0, "walked out")
	Expect.equal(Rewards.gameCoins(1, 4, false, true, 3), 0, "barely played")
end

tests["the day's dailies are one of each difficulty, the same all day, different another day"] = function()
	local a = Dailies.pick(123, 20000)
	Expect.equal(#a, 3)
	for index, tier in Dailies.TIERS do
		Expect.equal(Dailies.byId[a[index]].tier, tier)
	end
	Expect.equal(table.concat(Dailies.pick(123, 20000), ","), table.concat(a, ","))
	local differs = false
	for day = 20001, 20010 do
		differs = differs or table.concat(Dailies.pick(123, day), ",") ~= table.concat(a, ",")
	end
	Expect.equal(differs, true)
end

tests["a daily counts only what happens after it was dealt, pays once, and all three pay a bonus"] = function()
	local data = fresh()
	Progress.add(data, { games = 50, rolls = 900, doubles = 99, passGo = 99, propertiesBought = 99, cardsDrawn = 99, rentCollected = 99999 })
	Expect.equal(Progress.refreshDaily(data, 7, 100), true)
	Expect.equal(Progress.refreshDaily(data, 7, 100), false, "same day")
	for _, line in Progress.dailies(data) do
		Expect.equal(line.progress, 0, `{line.daily.id} counts old play`)
	end
	Expect.equal((Progress.claimDaily(data, 1)), false, "not finished")
	-- Finish all three.
	local counts = {}
	for _, line in Progress.dailies(data) do
		counts[line.daily.stat] = math.max(counts[line.daily.stat] or 0, line.daily.target)
	end
	Progress.add(data, counts)
	local ok1, paid1 = Progress.claimDaily(data, 1)
	Expect.equal(ok1, true)
	Expect.equal(paid1, Dailies.COINS.Easy)
	Expect.equal((Progress.claimDaily(data, 1)), false, "twice")
	Progress.claimDaily(data, 2)
	local _, paid3 = Progress.claimDaily(data, 3)
	Expect.equal(paid3, Dailies.COINS.Hard + Rewards.DAILY_SWEEP)
	Expect.equal(data.coins, Dailies.COINS.Easy + Dailies.COINS.Medium + Dailies.COINS.Hard + Rewards.DAILY_SWEEP)
	Expect.equal(data.counters.dailyCompleted, 3)
	Expect.equal(data.counters.coinsEarned, data.coins)
	-- A new day deals new ones.
	Expect.equal(Progress.refreshDaily(data, 7, 101), true)
	Expect.equal(data.daily.claimed[1], false)
end

tests["one daily may be swapped a day, for one of the same difficulty"] = function()
	local data = fresh()
	Progress.refreshDaily(data, 9, 300)
	local before = data.daily.ids[2]
	local ok = Progress.swapDaily(data, 9, 2)
	Expect.equal(ok, true)
	Expect.equal(data.daily.ids[2] ~= before, true)
	Expect.equal(Dailies.byId[data.daily.ids[2]].tier, "Medium")
	Expect.equal((Progress.swapDaily(data, 9, 1)), false, "second swap")
end

tests["achievement tiers are claimed in order on lifetime counts"] = function()
	local data = fresh()
	Progress.add(data, { wins = 12 })
	local line = Progress.achievement(data, "Winner")
	Expect.equal(line.ready, true)
	Expect.equal((Progress.claimAchievement(data, "Winner")), true)
	Expect.equal((Progress.claimAchievement(data, "Winner")), true, "silver (10) too")
	Expect.equal((Progress.claimAchievement(data, "Winner")), false, "gold needs 50")
	Expect.equal(data.achievements.Winner, 2)
	Expect.equal(data.coins, Achievements.TIER_COINS[1] + Achievements.TIER_COINS[2])
	Progress.add(data, { wins = 1000 })
	for _ = 3, 5 do
		Progress.claimAchievement(data, "Winner")
	end
	Expect.equal(Progress.owns(data, "DiceGalaxy"), true)
	Expect.equal(Progress.owns(data, "TitleMogul"), true)
	Expect.equal(Progress.achievement(data, "Winner").tier, nil)
end

tests["tree nodes open one after another, each counting from when it opened"] = function()
	local data = fresh()
	Expect.equal((Progress.node(data, "Root")), "Active")
	Expect.equal((Progress.node(data, "Tycoon1")), "Locked")
	Progress.add(data, { games = 1, propertiesBought = 100 })
	Expect.equal((Progress.node(data, "Root")), "Ready")
	Expect.equal((Progress.claimNode(data, "Tycoon1")), false, "locked")
	Expect.equal((Progress.claimNode(data, "Root")), true)
	Expect.equal(data.coins, 100)
	-- The 100 properties bought before Tycoon1 opened don't count.
	local state, progress = Progress.node(data, "Tycoon1")
	Expect.equal(state, "Active")
	Expect.equal(progress, 0)
	Progress.add(data, { propertiesBought = 5 })
	Expect.equal((Progress.node(data, "Tycoon1")), "Ready")
	Expect.equal((Progress.claimNode(data, "Tycoon1")), true)
	Expect.equal((Progress.claimNode(data, "Tycoon1")), false, "twice")
	Expect.equal((Progress.node(data, "Tycoon2")), "Active")
	Expect.equal(data.counters.treeNodes, 2)
	Expect.equal(Progress.treeClaimed(data), 2)
end

tests["a tree reward can be a key or an exclusive item"] = function()
	local data = fresh()
	Progress.grant(data, { key = "Silver" })
	Progress.grant(data, { key = "Silver" })
	Progress.grant(data, { item = "GoldenTopHat" })
	Expect.equal(data.keys.Silver, 2)
	Expect.equal(Progress.owns(data, "GoldenTopHat"), true)
end

tests["claimable counts what is waiting in each section"] = function()
	local data = fresh()
	Progress.refreshDaily(data, 1, 1)
	Expect.equal(Progress.claimable(data).total, 0)
	Progress.add(data, { games = 5, wins = 1 })
	local waiting = Progress.claimable(data)
	Expect.equal(waiting.tree, 1, "the root")
	Expect.equal(waiting.achievements, 2, "Winner and Regular bronze")
end

return tests
