--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Chests = require(ReplicatedStorage.Shared.Store.Chests)
local Rewards = require(ReplicatedStorage.Shared.Progress.Rewards)
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

tests["chests are opened with coins or keys, never sold for Robux"] = function()
	for _, chest in Chests.LIST do
		Expect.equal((chest :: any).productId, nil, `{chest.id} has no product`)
		assert((Rewards.CHEST_COINS[chest.id] or 0) > 0, `{chest.id} has a coin price`)
	end
end

tests["every item's own chance is listed and they add up to one"] = function()
	for _, chest in Chests.LIST do
		local total = 0
		local lines = Chests.itemOdds(chest)
		for _, line in lines do
			Expect.equal(Catalog.byId[line.id] ~= nil, true, line.id)
			Expect.equal(line.chance > 0, true, `{chest.id} {line.id} listed with no chance`)
			total += line.chance
		end
		Expect.near(total, 1, `{chest.id} item odds`, 1e-9)
		Expect.equal(lines[1].chance >= lines[#lines].chance, true, "most likely first")
	end
	local silver = Chests.itemOdds(Chests.byId.Silver)
	local commons = #Catalog.droppable("Common")
	local duck
	for _, line in silver do
		if line.id == "Duck" then
			duck = line
		end
	end
	Expect.near(duck.chance, 0.7 / commons, "a common's share of its rarity")
end

return tests
