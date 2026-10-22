--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableLayout = require(ReplicatedStorage.Shared.Lobby.TableLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local REACH = TableLayout.CHAIR_RADIUS + 1.5 -- a chair and the player in it
local CARPET_HALF = 5

local function angleOf(offset: Vector3): number
	return math.atan2(offset.Z, offset.X)
end

local function angleBetween(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

tests["eight tables: four casual, four ranked"] = function()
	Expect.equal(TableLayout.COUNT, 8)
	Expect.equal(#TableLayout.ids("Casual"), 4)
	Expect.equal(#TableLayout.ids("Ranked"), 4)
	Expect.equal(TableLayout.kind(1), "Casual")
	Expect.equal(TableLayout.kind(4), "Casual")
	Expect.equal(TableLayout.kind(5), "Ranked")
	Expect.equal(TableLayout.number(5), 1, "ranked tables count from 1")
	Expect.equal(TableLayout.number(3), 3)
	Expect.equal(TableLayout.kind(8), "Ranked")
end

tests["every table stands on the plaza, clear of the fountain and of each other"] = function()
	for id = 1, TableLayout.COUNT do
		local offset = TableLayout.offset(id)
		Expect.equal(offset.Y, 0, `table {id} on the floor`)
		assert(offset.Magnitude + REACH <= TableLayout.PLAZA_RADIUS - 6, `table {id} too near the wall`)
		assert(offset.Magnitude - REACH >= TableLayout.FOUNTAIN_RADIUS + 3, `table {id} too near the fountain`)
		for other = id + 1, TableLayout.COUNT do
			local gap = (offset - TableLayout.offset(other)).Magnitude
			assert(gap >= 2 * REACH, `tables {id} and {other} overlap`)
		end
	end
end

tests["the casual tables leave the red carpets clear"] = function()
	for _, id in TableLayout.ids("Casual") do
		local offset = TableLayout.offset(id)
		for _, carpet in TableLayout.CARPET_ANGLES do
			local along = Vector3.new(math.cos(carpet), 0, math.sin(carpet))
			if offset:Dot(along) > 0 then
				local across = (offset - along * offset:Dot(along)).Magnitude
				assert(across >= REACH + CARPET_HALF, `table {id} reaches onto a carpet`)
			end
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

tests["ranked tables sit inside the VIP area, casual ones outside it"] = function()
	local area = TableLayout.RANKED_AREA
	for _, id in TableLayout.ids("Ranked") do
		local offset = TableLayout.offset(id)
		assert(offset.Magnitude - REACH >= area.inner and offset.Magnitude + REACH <= area.outer, `ranked table {id} outside the VIP ring`)
		assert(angleBetween(angleOf(offset), area.angle) <= area.halfAngle, `ranked table {id} outside the VIP sector`)
	end
	for _, id in TableLayout.ids("Casual") do
		assert(TableLayout.offset(id).Magnitude + REACH < area.inner, `casual table {id} reaches into the VIP area`)
	end
end

tests["the VIP area faces away from the spawn side"] = function()
	assert(angleBetween(TableLayout.RANKED_AREA.angle, -math.pi / 2) < 0.2, "the VIP area is not at the far side")
end

return tests
