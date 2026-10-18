--!strict
-- What changed on the board's streets between two snapshots, so each change can be animated:
-- houses going up, a hotel replacing four houses, buildings sold off.

export type Change = { position: number, from: number, to: number } -- houses, 5 = hotel

local BuildingChanges = {}

function BuildingChanges.diff(old: { [number]: number }, new: { [number]: number }): { Change }
	local changes: { Change } = {}
	local seen = {}
	for position, houses in new do
		seen[position] = true
		local before = old[position] or 0
		if before ~= houses then
			table.insert(changes, { position = position, from = before, to = houses })
		end
	end
	for position, houses in old do
		if not seen[position] and houses ~= 0 then
			table.insert(changes, { position = position, from = houses, to = 0 })
		end
	end
	table.sort(changes, function(a, b)
		return a.position < b.position
	end)
	return changes
end

return BuildingChanges
