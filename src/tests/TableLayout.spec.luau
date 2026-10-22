--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableLayout = require(ReplicatedStorage.Shared.Lobby.TableLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local REACH = TableLayout.CHAIR_RADIUS + 1.5 -- a chair and the player in it

tests["twelve tables: eight casual, four ranked"] = function()
	Expect.equal(TableLayout.COUNT, 12)
	Expect.equal(#TableLayout.ids("Casual"), 8)
	Expect.equal(#TableLayout.ids("Ranked"), 4)
	Expect.equal(TableLayout.kind(1), "Casual")
	Expect.equal(TableLayout.kind(8), "Casual")
	Expect.equal(TableLayout.kind(9), "Ranked")
	Expect.equal(TableLayout.kind(12), "Ranked")
end

tests["every table and chair fits in the centre square without overlapping"] = function()
	for id = 1, TableLayout.COUNT do
		local offset = TableLayout.offset(id)
		Expect.equal(offset.Y, 0, `table {id} on the floor`)
		assert(math.abs(offset.X) + REACH <= TableLayout.CENTRE_HALF, `table {id} off the centre square (x)`)
		assert(math.abs(offset.Z) + REACH <= TableLayout.CENTRE_HALF, `table {id} off the centre square (z)`)
		for other = id + 1, TableLayout.COUNT do
			local gap = (offset - TableLayout.offset(other)).Magnitude
			assert(gap >= 2 * REACH, `tables {id} and {other} overlap`)
		end
	end
end

tests["six chairs round each table, facing it"] = function()
	Expect.equal(TableLayout.CHAIRS, 6)
	for index = 1, TableLayout.CHAIRS do
		local chair = TableLayout.chair(index)
		Expect.near(chair.Position.Magnitude, TableLayout.CHAIR_RADIUS, `chair {index} distance`)
		assert(chair.LookVector:Dot(-chair.Position.Unit) > 0.99, `chair {index} faces away`)
	end
end

tests["ranked tables sit inside the ranked area, casual ones outside it"] = function()
	local area = TableLayout.RANKED_AREA
	local function inside(id: number): boolean
		local offset = TableLayout.offset(id)
		return offset.X - REACH >= area.min.X and offset.X + REACH <= area.max.X and offset.Z - REACH >= area.min.Y and offset.Z + REACH <= area.max.Y
	end
	for _, id in TableLayout.ids("Ranked") do
		assert(inside(id), `ranked table {id} outside the ranked area`)
	end
	for _, id in TableLayout.ids("Casual") do
		local offset = TableLayout.offset(id)
		assert(offset.Z - REACH > area.max.Y, `casual table {id} reaches into the ranked area`)
	end
end

return tests
