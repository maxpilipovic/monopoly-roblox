--!strict
-- Where the lobby hall's game tables stand. Four casual tables round the fountain, inside the
-- statues, one in each quarter between the red carpets. Four ranked tables stand in the VIP area at the
-- far side of the hall from the spawn, in front of the leaderboards, either side of the carpet that
-- runs into it. Six chairs round each table. Offsets are relative to the lobby's centre; the
-- builder and anything that needs a table's place share these numbers (and the hall's).

export type Kind = "Casual" | "Ranked"

local TableLayout = {}

TableLayout.COUNT = 8
TableLayout.CHAIRS = 6
TableLayout.TABLE_RADIUS = 6
TableLayout.CHAIR_RADIUS = 9.5
TableLayout.PLAZA_RADIUS = 115 -- the hall's floor (LobbyBuilder)
TableLayout.FOUNTAIN_RADIUS = 15

-- The red carpets run out from the fountain along these angles (LobbyBuilder's doorways).
local FIRST_CARPET = 0.5 / 40 * 2 * math.pi
TableLayout.CARPET_ANGLES = table.freeze({ FIRST_CARPET, FIRST_CARPET + math.pi / 2, FIRST_CARPET + math.pi, FIRST_CARPET + 3 * math.pi / 2 })

-- The VIP area: a ring sector round the carpet opposite the spawn (which is at angle pi/2).
TableLayout.RANKED_AREA = table.freeze({
	angle = FIRST_CARPET - math.pi / 2,
	halfAngle = 0.85,
	inner = 70,
	outer = 100,
})

local CASUAL_RADIUS = 46
local CASUAL_ANGLES = { 45, 135, 225, 315 } -- degrees past the first carpet: one per quarter
local RANKED_RADIUS = 86
local RANKED_SPREAD = { -0.65, -0.3, 0.3, 0.65 } -- radians either side of the VIP carpet

function TableLayout.kind(id: number): Kind
	return if id > 4 then "Ranked" else "Casual"
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

-- The table's number within its kind, as players see it: "Table 2", "Ranked table 1".
function TableLayout.number(id: number): number
	return if TableLayout.kind(id) == "Ranked" then id - 4 else id
end

local function polar(radius: number, angle: number): Vector3
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

function TableLayout.offset(id: number): Vector3
	assert(id % 1 == 0 and id >= 1 and id <= TableLayout.COUNT, `no table {id}`)
	if id <= 4 then
		return polar(CASUAL_RADIUS, FIRST_CARPET + math.rad(CASUAL_ANGLES[id]))
	end
	return polar(RANKED_RADIUS, TableLayout.RANKED_AREA.angle + RANKED_SPREAD[id - 4])
end

-- Chair `index`'s place relative to its table's centre, facing the table.
function TableLayout.chair(index: number): CFrame
	local angle = math.rad((index - 1) * 360 / TableLayout.CHAIRS)
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * TableLayout.CHAIR_RADIUS
	return CFrame.lookAt(position, Vector3.zero)
end

return TableLayout
