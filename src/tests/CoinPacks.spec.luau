--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinPacks = require(ReplicatedStorage.Shared.Store.CoinPacks)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["four coin packs, the only thing sold for Robux"] = function()
	local expected = {
		{ id = "Pouch", coins = 1000, price = 49 },
		{ id = "Bag", coins = 3500, price = 149 },
		{ id = "Pile", coins = 10000, price = 399 },
		{ id = "Vault", coins = 30000, price = 999 },
	}
	Expect.equal(#CoinPacks.LIST, #expected, "pack count")
	for index, want in expected do
		local pack = CoinPacks.LIST[index]
		Expect.equal(pack.id, want.id, `pack {index}`)
		Expect.equal(pack.coins, want.coins, `{want.id} coins`)
		Expect.equal(pack.price, want.price, `{want.id} price`)
		Expect.equal(CoinPacks.byId[want.id], pack, `{want.id} by id`)
		assert(#pack.name > 0, `{want.id} name`)
	end
end

tests["bigger packs give more coins per Robux"] = function()
	for index = 2, #CoinPacks.LIST do
		local smaller, bigger = CoinPacks.LIST[index - 1], CoinPacks.LIST[index]
		assert(bigger.coins / bigger.price > smaller.coins / smaller.price, `{bigger.id} is no better value than {smaller.id}`)
	end
end

tests["packs are found by their developer product id; an unset id finds nothing"] = function()
	Expect.equal(CoinPacks.forProduct(0), nil, "unset")
	Expect.equal(CoinPacks.forProduct(-1), nil, "unknown")
	for _, pack in CoinPacks.LIST do
		Expect.equal(CoinPacks.forProduct(pack.productId), if pack.productId ~= 0 then pack else nil, pack.id)
	end
end

return tests
