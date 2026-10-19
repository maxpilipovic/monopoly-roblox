--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Chests = require(ReplicatedStorage.Shared.Store.Chests)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["each chest's odds add up to one and are shown as percentages"] = function()
	for _, chest in Chests.LIST do
		local total = 0
		for _, rarity in Catalog.RARITIES do
			total += chest.odds[rarity] or 0
		end
		Expect.near(total, 1, `{chest.id} odds`, 1e-9)
		Expect.equal(#Chests.oddsLines(chest), #Catalog.RARITIES)
	end
	Expect.equal(Chests.oddsLines(Chests.byId.Silver)[4], "Legendary 0.5%")
end

tests["a roll is the same for the same random seed and always a droppable item"] = function()
	for _, chest in Chests.LIST do
		local a = Chests.roll(chest.id, Random.new(42))
		local b = Chests.roll(chest.id, Random.new(42))
		Expect.equal(a, b, `{chest.id} deterministic`)
		local item = Catalog.byId[a]
		Expect.equal(item ~= nil and not item.default, true, `{chest.id} gave {a}`)
	end
end

tests["the diamond chest never gives a common"] = function()
	local random = Random.new(7)
	for _ = 1, 300 do
		Expect.equal(Catalog.byId[Chests.roll("Diamond", random)].rarity ~= "Common", true)
	end
end

tests["every droppable item can come from some chest"] = function()
	for _, rarity in Catalog.RARITIES do
		local reachable = false
		for _, chest in Chests.LIST do
			if (chest.odds[rarity] or 0) > 0 then
				reachable = true
			end
		end
		Expect.equal(reachable, true, rarity)
	end
end

tests["chests are found by their developer product id"] = function()
	local silver = Chests.byId.Silver
	Expect.equal(Chests.forProduct(silver.productId), if silver.productId ~= 0 then silver else nil)
	Expect.equal(Chests.forProduct(-1), nil)
end

return tests
