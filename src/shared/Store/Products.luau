--!strict
-- Developer Product ids for the coin packs, the only thing sold for Robux. Create one product per
-- pack on the Creator Dashboard (Monetization > Developer Products, at the price below) and paste
-- its id here. While an id is 0 the pack can only be test-bought in Studio; live servers refuse it.

return table.freeze({
	Pouch = 0, -- 49 Robux: 1,000 coins
	Bag = 0, -- 149 Robux: 3,500 coins
	Pile = 0, -- 399 Robux: 10,000 coins
	Vault = 0, -- 999 Robux: 30,000 coins
})
