--!strict
-- The chests sold for Robux: price, odds per rarity (shown before purchase, as Roblox requires for
-- paid random items) and the roll itself. Within a rarity every droppable item is equally likely.

local Catalog = require(script.Parent.Parent.Cosmetics.Catalog)
local Products = require(script.Parent.Products)

export type Chest = {
	id: string,
	name: string,
	price: number, -- Robux, as set on the developer product
	productId: number,
	odds: { [string]: number }, -- rarity -> chance, summing to 1
	blurb: string,
}

local Chests = {}

Chests.LIST = {
	{
		id = "Silver",
		name = "Silver Chest",
		price = 49,
		productId = Products.Silver,
		odds = { Common = 0.7, Rare = 0.25, Epic = 0.045, Legendary = 0.005 },
		blurb = "A solid start: mostly commons, a shot at something rare.",
	},
	{
		id = "Gold",
		name = "Gold Chest",
		price = 149,
		productId = Products.Gold,
		odds = { Common = 0.35, Rare = 0.45, Epic = 0.17, Legendary = 0.03 },
		blurb = "Rares are likely and epics are common.",
	},
	{
		id = "Diamond",
		name = "Diamond Chest",
		price = 399,
		productId = Products.Diamond,
		odds = { Common = 0, Rare = 0.4, Epic = 0.45, Legendary = 0.15 },
		blurb = "No commons. A real chance at a legendary.",
	},
} :: { Chest }

Chests.byId = {} :: { [string]: Chest }
for _, chest in Chests.LIST do
	Chests.byId[chest.id] = chest
end

function Chests.forProduct(productId: number): Chest?
	if productId == 0 then
		return nil
	end
	for _, chest in Chests.LIST do
		if chest.productId == productId then
			return chest
		end
	end
	return nil
end

-- "Rare 25%" lines for the shop, in rarity order.
function Chests.oddsLines(chest: Chest): { string }
	local lines = {}
	for _, rarity in Catalog.RARITIES do
		local percent = (chest.odds[rarity] or 0) * 100
		local text = if percent == math.floor(percent) then tostring(math.floor(percent)) else string.format("%.1f", percent)
		table.insert(lines, `{rarity} {text}%`)
	end
	return lines
end

-- Every item this chest can give and its own chance (its rarity's chance shared out among that
-- rarity's items), most likely first: what the shop shows before you buy.
function Chests.itemOdds(chest: Chest): { { id: string, name: string, rarity: string, chance: number } }
	local lines = {}
	for _, rarity in Catalog.RARITIES do
		local odds = chest.odds[rarity] or 0
		local items = Catalog.droppable(rarity)
		if odds > 0 and #items > 0 then
			for _, item in items do
				table.insert(lines, { id = item.id, name = item.name, rarity = rarity, chance = odds / #items })
			end
		end
	end
	table.sort(lines, function(a, b)
		return a.chance > b.chance
	end)
	return lines
end

-- Picks an item id from `chestId`: a rarity by the odds, then an item of that rarity.
function Chests.roll(chestId: string, random: Random): string
	local chest = assert(Chests.byId[chestId], `no chest {chestId}`)
	local pick = random:NextNumber()
	local rarity = Catalog.RARITIES[#Catalog.RARITIES]
	local running = 0
	for _, candidate in Catalog.RARITIES do
		running += chest.odds[candidate] or 0
		if pick < running then
			rarity = candidate
			break
		end
	end
	local items = Catalog.droppable(rarity)
	return items[random:NextInteger(1, #items)].id
end

return Chests
