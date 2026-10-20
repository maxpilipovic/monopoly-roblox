--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["ids are unique and every item has a valid kind and rarity"] = function()
	local seen = {}
	for _, item in Catalog.ITEMS do
		Expect.equal(seen[item.id], nil, `duplicate {item.id}`)
		seen[item.id] = true
		Expect.equal(table.find(Catalog.KINDS, item.kind) ~= nil, true, `{item.id} kind`)
		Expect.equal(table.find(Catalog.RARITIES, item.rarity) ~= nil, true, `{item.id} rarity`)
		Expect.equal(Catalog.byId[item.id], item)
	end
end

tests["the three defaults are the top hat, battleship and race car"] = function()
	Expect.equal(table.concat(Catalog.DEFAULT_PIECES, ","), "TopHat,Battleship,RaceCar")
	for _, id in Catalog.DEFAULT_PIECES do
		Expect.equal(Catalog.byId[id].default, true)
	end
	Expect.equal(Catalog.DEFAULT_PIECE, "TopHat")
end

tests["every chest and challenge piece and every aura has a special effect; defaults are plain"] = function()
	for _, item in Catalog.ITEMS do
		if item.kind == "Piece" or item.kind == "Aura" then
			Expect.equal(item.effect ~= nil, not item.default, `{item.id} effect`)
		end
	end
end

tests["chests never give challenge items or titles"] = function()
	for _, rarity in Catalog.RARITIES do
		for _, item in Catalog.droppable(rarity) do
			Expect.equal(item.exclusive, nil, item.id)
			Expect.equal(item.kind ~= "Title", true, item.id)
		end
	end
end

tests["a piece on another model says where that model is"] = function()
	Expect.equal(select(2, Catalog.modelOf("Crown")), "Crown")
	local kind, model = Catalog.modelOf("GrandHotel")
	Expect.equal(kind, "Buildings")
	Expect.equal(model, "Hotel")
	Expect.equal(Catalog.byId.DiceIvory.default, true, "everyone has ivory dice")
end

tests["every rarity has something to drop"] = function()
	for _, rarity in Catalog.RARITIES do
		Expect.equal(#Catalog.droppable(rarity) > 0, true, rarity)
	end
	for _, item in Catalog.droppable("Common") do
		Expect.equal(item.default, nil, "defaults never drop")
	end
end

tests["there are at least twelve chest pieces and six rent effects"] = function()
	local pieces, effects = 0, 0
	for _, item in Catalog.ITEMS do
		if item.kind == "Piece" and not item.default then
			pieces += 1
		elseif item.kind == "RentEffect" then
			effects += 1
		end
	end
	Expect.equal(pieces >= 12, true, `{pieces} pieces`)
	Expect.equal(effects >= 6, true, `{effects} effects`)
end

return tests
