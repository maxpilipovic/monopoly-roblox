--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingChanges = require(ReplicatedStorage.Shared.Board.BuildingChanges)
local Expect = require(script.Parent.Expect)

local tests = {}

local function describe(changes: { BuildingChanges.Change }): string
	local parts = {}
	for _, change in changes do
		table.insert(parts, `{change.position}:{change.from}>{change.to}`)
	end
	return table.concat(parts, " ")
end

tests["new, grown, upgraded, sold and razed streets are each one change, in board order"] = function()
	local old = { [1] = 1, [3] = 4, [6] = 2, [39] = 5, [37] = 3 }
	local new = { [1] = 3, [3] = 5, [6] = 1, [39] = 0, [11] = 1 }
	Expect.equal(describe(BuildingChanges.diff(old, new)), "1:1>3 3:4>5 6:2>1 11:0>1 37:3>0 39:5>0")
end

tests["nothing changed, no changes"] = function()
	Expect.equal(#BuildingChanges.diff({ [1] = 2 }, { [1] = 2 }), 0)
	Expect.equal(#BuildingChanges.diff({}, {}), 0)
end

tests["a hotel broken back into houses is a change down"] = function()
	Expect.equal(describe(BuildingChanges.diff({ [24] = 5 }, { [24] = 4 })), "24:5>4")
end

return tests
