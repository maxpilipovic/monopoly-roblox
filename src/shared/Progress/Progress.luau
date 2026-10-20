--!strict
-- The rules of progression, on a player's saved progress: lifetime counters, coins, chest keys, the
-- day's challenges, achievement tiers claimed, and the Empire Tree. Pure, and shared: the server
-- changes a profile with it, the client reads its own copy with it to draw the same state.

local Catalog = require(script.Parent.Parent.Cosmetics.Catalog)
local Achievements = require(script.Parent.Achievements)
local Dailies = require(script.Parent.Dailies)
local Rewards = require(script.Parent.Rewards)
local Tree = require(script.Parent.Tree)

export type DailyState = {
	day: number,
	ids: { string },
	starts: { number }, -- the counter when each challenge was set
	claimed: { boolean },
	swaps: number, -- used today
	bonus: boolean, -- the all-three bonus paid
}

export type Data = {
	coins: number,
	counters: { [string]: number },
	keys: { [string]: number },
	daily: DailyState,
	achievements: { [string]: number }, -- track id -> tiers claimed
	tree: { claimed: { [string]: boolean }, starts: { [string]: number } },
	inventory: { [string]: number },
}

export type NodeState = "Locked" | "Active" | "Ready" | "Claimed"

local Progress = {}

function Progress.newDaily(): DailyState
	return { day = -1, ids = {}, starts = {}, claimed = {}, swaps = 0, bonus = false }
end

function Progress.counter(data: Data, stat: string): number
	return data.counters[stat] or 0
end

-- Adds to the lifetime counters.
function Progress.add(data: Data, counts: { [string]: number })
	for stat, n in counts do
		if n ~= 0 then
			data.counters[stat] = (data.counters[stat] or 0) + n
		end
	end
end

function Progress.addCoins(data: Data, n: number)
	if n > 0 then
		data.coins += n
		data.counters.coinsEarned = (data.counters.coinsEarned or 0) + n
	end
end

function Progress.owns(data: Data, id: string): boolean
	local item = Catalog.byId[id]
	return item ~= nil and (item.default == true or (data.inventory[id] or 0) > 0)
end

-- Pays out a challenge reward.
function Progress.grant(data: Data, reward: Rewards.Reward)
	if reward.coins then
		Progress.addCoins(data, reward.coins)
	end
	if reward.item and Catalog.byId[reward.item] and not Progress.owns(data, reward.item) then
		data.inventory[reward.item] = 1
	end
	if reward.key then
		data.keys[reward.key] = (data.keys[reward.key] or 0) + 1
	end
end

-- Daily challenges ---------------------------------------------------------------------------------

-- Deals the day's challenges if the day has turned. Returns whether anything changed.
function Progress.refreshDaily(data: Data, userId: number, day: number): boolean
	if data.daily.day == day and #data.daily.ids == #Dailies.TIERS then
		return false
	end
	local ids = Dailies.pick(userId, day)
	local starts = {}
	local claimed = {}
	for index, id in ids do
		starts[index] = Progress.counter(data, Dailies.byId[id].stat)
		claimed[index] = false
	end
	data.daily = { day = day, ids = ids, starts = starts, claimed = claimed, swaps = 0, bonus = false }
	return true
end

export type DailyLine = { slot: number, daily: Dailies.Daily, progress: number, claimed: boolean, ready: boolean }

function Progress.dailies(data: Data): { DailyLine }
	local lines = {}
	for slot, id in data.daily.ids do
		local daily = Dailies.byId[id]
		if daily then
			local progress = math.clamp(Progress.counter(data, daily.stat) - (data.daily.starts[slot] or 0), 0, daily.target)
			local claimed = data.daily.claimed[slot] == true
			table.insert(lines, { slot = slot, daily = daily, progress = progress, claimed = claimed, ready = not claimed and progress >= daily.target })
		end
	end
	return lines
end

-- Claims a finished daily; finishing the third also pays the all-three bonus. Returns the coins paid.
function Progress.claimDaily(data: Data, slot: number): (boolean, string | number)
	local line = nil
	for _, candidate in Progress.dailies(data) do
		if candidate.slot == slot then
			line = candidate
		end
	end
	if not line then
		return false, "no such challenge"
	elseif line.claimed then
		return false, "already claimed"
	elseif not line.ready then
		return false, "not finished yet"
	end
	data.daily.claimed[slot] = true
	data.counters.dailyCompleted = (data.counters.dailyCompleted or 0) + 1
	local paid = line.daily.coins
	local all = true
	for index = 1, #data.daily.ids do
		all = all and data.daily.claimed[index] == true
	end
	if all and not data.daily.bonus then
		data.daily.bonus = true
		paid += Rewards.DAILY_SWEEP
	end
	Progress.addCoins(data, paid)
	return true, paid
end

-- Trades an unclaimed daily for another of the same difficulty, once a day.
function Progress.swapDaily(data: Data, userId: number, slot: number): (boolean, string?)
	local id = data.daily.ids[slot]
	if not id then
		return false, "no such challenge"
	elseif data.daily.claimed[slot] then
		return false, "already claimed"
	elseif data.daily.swaps >= Dailies.SWAPS_PER_DAY then
		return false, "you've used today's swap"
	end
	local replacement = Dailies.swap(userId, data.daily.day, id, data.daily.ids)
	if not replacement then
		return false, "nothing to swap to"
	end
	data.daily.ids[slot] = replacement
	data.daily.starts[slot] = Progress.counter(data, Dailies.byId[replacement].stat)
	data.daily.swaps += 1
	return true, nil
end

-- Achievements -------------------------------------------------------------------------------------

export type AchievementLine = {
	track: Achievements.Track,
	claimed: number, -- tiers claimed
	tier: Achievements.Tier?, -- the next tier to earn (nil: all done)
	progress: number,
	ready: boolean,
}

function Progress.achievement(data: Data, trackId: string): AchievementLine
	local track = assert(Achievements.byId[trackId], `no achievement {trackId}`)
	local claimed = math.clamp(data.achievements[trackId] or 0, 0, #track.tiers)
	local tier = track.tiers[claimed + 1]
	local progress = Progress.counter(data, track.stat)
	return { track = track, claimed = claimed, tier = tier, progress = progress, ready = tier ~= nil and progress >= tier.target }
end

function Progress.claimAchievement(data: Data, trackId: string): (boolean, string | Rewards.Reward)
	if not Achievements.byId[trackId] then
		return false, "no such achievement"
	end
	local line = Progress.achievement(data, trackId)
	if not line.tier then
		return false, "all tiers done"
	elseif not line.ready then
		return false, "not reached yet"
	end
	data.achievements[trackId] = line.claimed + 1
	Progress.grant(data, line.tier.reward)
	return true, line.tier.reward
end

-- The Empire Tree ----------------------------------------------------------------------------------

-- The root is open from the start, counting everything ever played.
function Progress.ensureTree(data: Data)
	if data.tree.starts[Tree.ROOT] == nil then
		data.tree.starts[Tree.ROOT] = 0
	end
end

function Progress.node(data: Data, nodeId: string): (NodeState, number, number)
	local node = assert(Tree.byId[nodeId], `no node {nodeId}`)
	if data.tree.claimed[nodeId] then
		return "Claimed", node.target, node.target
	end
	local start = data.tree.starts[nodeId]
	local open = start ~= nil and (node.parent == nil or data.tree.claimed[node.parent] == true)
	if not open then
		return "Locked", 0, node.target
	end
	local progress = math.clamp(Progress.counter(data, node.stat) - (start :: number), 0, node.target)
	return if progress >= node.target then "Ready" else "Active", progress, node.target
end

-- Claims a finished node and opens the ones after it, counting from now.
function Progress.claimNode(data: Data, nodeId: string): (boolean, string | Rewards.Reward)
	local node = Tree.byId[nodeId]
	if not node then
		return false, "no such node"
	end
	local state = Progress.node(data, nodeId)
	if state ~= "Ready" then
		return false, if state == "Claimed" then "already claimed" else "not finished yet"
	end
	data.tree.claimed[nodeId] = true
	data.counters.treeNodes = (data.counters.treeNodes or 0) + 1
	Progress.grant(data, node.reward)
	for _, childId in Tree.children[nodeId] do
		local child = Tree.byId[childId]
		data.tree.starts[childId] = Progress.counter(data, child.stat)
	end
	return true, node.reward
end

function Progress.treeClaimed(data: Data): number
	local count = 0
	for _ in data.tree.claimed do
		count += 1
	end
	return count
end

-- How many rewards are waiting to be claimed, by section (for the badges).
function Progress.claimable(data: Data): { daily: number, achievements: number, tree: number, total: number }
	local daily, achievements, tree = 0, 0, 0
	for _, line in Progress.dailies(data) do
		if line.ready then
			daily += 1
		end
	end
	for _, track in Achievements.LIST do
		if Progress.achievement(data, track.id).ready then
			achievements += 1
		end
	end
	for _, node in Tree.NODES do
		if (Progress.node(data, node.id)) == "Ready" then
			tree += 1
		end
	end
	return { daily = daily, achievements = achievements, tree = tree, total = daily + achievements + tree }
end

return Progress
