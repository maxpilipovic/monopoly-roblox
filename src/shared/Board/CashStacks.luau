--!strict
-- How the Free Parking pot looks in the middle of the board: a bundle of bills per $100, piled in
-- stacks of up to six, the stacks laid out in a ring around the pot's plaque.

export type Stack = { offset: Vector3, bundles: number } -- offset from the board centre, on the surface

local CashStacks = {}

CashStacks.PER_BUNDLE = 100
CashStacks.MAX_BUNDLES = 6
CashStacks.MAX_STACKS = 12
CashStacks.SPACING = 3.4 -- studs between stack centres
local RING_RADIUS = 9

function CashStacks.layout(pot: number): { Stack }
	local total = math.min(math.ceil(math.max(pot, 0) / CashStacks.PER_BUNDLE), CashStacks.MAX_STACKS * CashStacks.MAX_BUNDLES)
	local stacks: { Stack } = {}
	if total == 0 then
		return stacks
	end
	local count = math.min(math.ceil(total / CashStacks.MAX_BUNDLES), CashStacks.MAX_STACKS)
	-- Spread the stacks evenly round the ring; spacing along the arc never drops below SPACING.
	local radius = math.max(RING_RADIUS, CashStacks.SPACING * count / (2 * math.pi) + 0.5)
	-- Share the bundles out evenly; the first stacks take any extra.
	local base, extra = total // count, total % count
	for index = 1, count do
		local angle = (index - 1) / count * 2 * math.pi + math.pi / 2
		local bundles = base + (if index <= extra then 1 else 0)
		table.insert(stacks, { offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), bundles = bundles })
	end
	return stacks
end

return CashStacks
