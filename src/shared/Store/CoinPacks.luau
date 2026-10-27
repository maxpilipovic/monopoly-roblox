--!strict
-- The coin packs sold for Robux. Coins are also earned by playing and from challenges, and they
-- open the chests (Rewards.CHEST_COINS); bigger packs give more coins per Robux.

local Products = require(script.Parent.Products)

export type Pack = {
	id: string,
	name: string,
	coins: number,
	price: number, -- Robux, as set on the developer product
	productId: number,
}

local CoinPacks = {}

CoinPacks.LIST = {
	{ id = "Pouch", name = "Pouch of Coins", coins = 1000, price = 49, productId = Products.Pouch },
	{ id = "Bag", name = "Bag of Coins", coins = 3500, price = 149, productId = Products.Bag },
	{ id = "Pile", name = "Pile of Coins", coins = 10000, price = 399, productId = Products.Pile },
	{ id = "Vault", name = "Vault of Coins", coins = 30000, price = 999, productId = Products.Vault },
} :: { Pack }

CoinPacks.byId = {} :: { [string]: Pack }
for _, pack in CoinPacks.LIST do
	CoinPacks.byId[pack.id] = pack
end

function CoinPacks.forProduct(productId: number): Pack?
	if productId == 0 then
		return nil
	end
	for _, pack in CoinPacks.LIST do
		if pack.productId == productId then
			return pack
		end
	end
	return nil
end

return CoinPacks
