--!strict
-- Where each challenge-only item is won, for the collection's "how do I get this?" hints.

local Achievements = require(script.Parent.Achievements)
local Tree = require(script.Parent.Tree)

local Unlocks = {}

local sources: { [string]: string } = {}
for _, track in Achievements.LIST do
	for index, tier in track.tiers do
		if tier.reward.item then
			sources[tier.reward.item] = `Achievement: {track.name} ({Achievements.TIER_NAMES[index]})`
		end
	end
end
for _, node in Tree.NODES do
	if node.reward.item and not sources[node.reward.item] then
		local branch = if node.branch then Tree.branchById[node.branch] else nil
		sources[node.reward.item] = if branch then `Empire Tree: {branch.name} branch` else "Empire Tree"
	end
end

function Unlocks.sourceOf(itemId: string): string?
	return sources[itemId]
end

-- The tree node that gives `itemId`, if one does (to jump the tree to it).
function Unlocks.nodeFor(itemId: string): string?
	for _, node in Tree.NODES do
		if node.reward.item == itemId then
			return node.id
		end
	end
	return nil
end

return Unlocks
