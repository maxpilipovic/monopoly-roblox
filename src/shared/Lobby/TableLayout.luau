--!strict
-- Where the lobby's game tables stand, in the giant board's centre square: four columns by three
-- rows, the two rows nearer GO casual (ids 1-8), the far row ranked (9-12) in its roped-off VIP
-- area. Six chairs round each table. Offsets are relative to the lobby's centre; the builder
-- (server) and anything that needs a table's place share these numbers.

export type Kind = "Casual" | "Ranked"

local TableLayout = {}

TableLayout.COUNT = 12
TableLayout.CHAIRS = 6
TableLayout.TABLE_RADIUS = 6
TableLayout.CHAIR_RADIUS = 9.5
TableLayout.CENTRE_HALF = 81 -- half the board's centre square at three times size

-- The VIP carpet: x from min.X to max.X, z from min.Y to max.Y.
TableLayout.RANKED_AREA = table.freeze({ min = Vector2.new(-68, -66), max = Vector2.new(68, -26) })

local COLUMNS = { -48, -16, 16, 48 }
local ROWS = { 38, 6, -44 } -- the GO side (+Z) first; the last row is ranked

function TableLayout.kind(id: number): Kind
	return if id > 8 then "Ranked" else "Casual"
end

function TableLayout.ids(kind: Kind): { number }
	local ids = {}
	for id = 1, TableLayout.COUNT do
		if TableLayout.kind(id) == kind then
			table.insert(ids, id)
		end
	end
	return ids
end

function TableLayout.offset(id: number): Vector3
	assert(id % 1 == 0 and id >= 1 and id <= TableLayout.COUNT, `no table {id}`)
	local column = (id - 1) % #COLUMNS + 1
	local row = (id - 1) // #COLUMNS + 1
	return Vector3.new(COLUMNS[column], 0, ROWS[row])
end

-- Chair `index`'s place relative to its table's centre, facing the table.
function TableLayout.chair(index: number): CFrame
	local angle = math.rad((index - 1) * 360 / TableLayout.CHAIRS)
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * TableLayout.CHAIR_RADIUS
	return CFrame.lookAt(position, Vector3.zero)
end

return TableLayout
