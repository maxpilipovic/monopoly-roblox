--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TalkScope = require(ReplicatedStorage.Shared.Net.TalkScope)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["the lobby talks together, and each table among itself"] = function()
	Expect.equal(TalkScope.together(nil, nil), true, "both in the lobby")
	Expect.equal(TalkScope.together(3, 3), true, "same table")
	Expect.equal(TalkScope.together(3, 4), false, "different tables")
	Expect.equal(TalkScope.together(3, nil), false, "table and lobby")
end

tests["a player's table is read from the Table attribute"] = function()
	local holder = Instance.new("Folder")
	Expect.equal(TalkScope.tableOf(holder), nil, "lobby")
	holder:SetAttribute(TalkScope.ATTRIBUTE, 7)
	Expect.equal(TalkScope.tableOf(holder), 7, "at table 7")
	holder:SetAttribute(TalkScope.ATTRIBUTE, "7")
	Expect.equal(TalkScope.tableOf(holder), nil, "only a number counts")
	holder:Destroy()
end

tests["a game table is cut off from the lobby and from other tables, both ways"] = function()
	local lobby = { id = 1, table = nil }
	local atTable = { id = 2, table = 5 }
	local sameTable = { id = 3, table = 5 }
	local otherTable = { id = 4, table = 6 }
	local everyone = { lobby, atTable, sameTable, otherTable }
	Expect.equal(table.concat(TalkScope.listeners({}, atTable, everyone), ","), "3", "table 5 hears table 5 only")
	Expect.equal(#TalkScope.listeners({}, lobby, everyone), 0, "nobody at a table hears the lobby")
	Expect.equal(#TalkScope.listeners({}, otherTable, everyone), 0, "table 6 alone")
end

tests["muting someone stops you hearing them, and only you"] = function()
	local a, b, c = { id = 1, table = 5 }, { id = 2, table = 5 }, { id = 3, table = 5 }
	local mutes = { [1] = { [2] = true } }
	Expect.equal(TalkScope.hears(mutes, a, b), false, "1 muted 2")
	Expect.equal(TalkScope.hears(mutes, b, a), true, "2 still hears 1")
	Expect.equal(TalkScope.hears(mutes, c, b), true, "3 still hears 2")
	Expect.equal(table.concat(TalkScope.listeners(mutes, b, { a, b, c }), ","), "3")
end

return tests
