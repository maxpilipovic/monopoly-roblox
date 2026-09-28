--!strict
-- The 40 board tiles in play order. Position 0 is Go; movement is (position + roll) % 40.

export type TileKind =
	"Go"
	| "Property"
	| "Railroad"
	| "Utility"
	| "Tax"
	| "Chance"
	| "CommunityChest"
	| "Jail"
	| "FreeParking"
	| "GoToJail"

export type Tile = {
	position: number,
	name: string,
	kind: TileKind,
	price: number?, -- Property, Railroad, Utility
	group: string?, -- Property only; key into ColorGroups
	rent: { number }?, -- Property only: { base, 1 house, 2, 3, 4, hotel }
	amount: number?, -- Tax only
}

local function property(name: string, group: string, price: number, rent: { number }): Tile
	return { position = -1, name = name, kind = "Property", group = group, price = price, rent = table.freeze(rent) }
end

local function railroad(name: string): Tile
	return { position = -1, name = name, kind = "Railroad", price = 200 }
end

local function utility(name: string): Tile
	return { position = -1, name = name, kind = "Utility", price = 150 }
end

local function tax(name: string, amount: number): Tile
	return { position = -1, name = name, kind = "Tax", amount = amount }
end

local function special(name: string, kind: TileKind): Tile
	return { position = -1, name = name, kind = kind }
end

local list: { Tile } = {
	special("Go", "Go"),
	property("Mediterranean Avenue", "Brown", 60, { 2, 10, 30, 90, 160, 250 }),
	special("Community Chest", "CommunityChest"),
	property("Baltic Avenue", "Brown", 60, { 4, 20, 60, 180, 320, 450 }),
	tax("Income Tax", 200),
	railroad("Reading Railroad"),
	property("Oriental Avenue", "LightBlue", 100, { 6, 30, 90, 270, 400, 550 }),
	special("Chance", "Chance"),
	property("Vermont Avenue", "LightBlue", 100, { 6, 30, 90, 270, 400, 550 }),
	property("Connecticut Avenue", "LightBlue", 120, { 8, 40, 100, 300, 450, 600 }),
	special("Jail", "Jail"),
	property("St. Charles Place", "Pink", 140, { 10, 50, 150, 450, 625, 750 }),
	utility("Electric Company"),
	property("States Avenue", "Pink", 140, { 10, 50, 150, 450, 625, 750 }),
	property("Virginia Avenue", "Pink", 160, { 12, 60, 180, 500, 700, 900 }),
	railroad("Pennsylvania Railroad"),
	property("St. James Place", "Orange", 180, { 14, 70, 200, 550, 750, 950 }),
	special("Community Chest", "CommunityChest"),
	property("Tennessee Avenue", "Orange", 180, { 14, 70, 200, 550, 750, 950 }),
	property("New York Avenue", "Orange", 200, { 16, 80, 220, 600, 800, 1000 }),
	special("Free Parking", "FreeParking"),
	property("Kentucky Avenue", "Red", 220, { 18, 90, 250, 700, 875, 1050 }),
	special("Chance", "Chance"),
	property("Indiana Avenue", "Red", 220, { 18, 90, 250, 700, 875, 1050 }),
	property("Illinois Avenue", "Red", 240, { 20, 100, 300, 750, 925, 1100 }),
	railroad("B. & O. Railroad"),
	property("Atlantic Avenue", "Yellow", 260, { 22, 110, 330, 800, 975, 1150 }),
	property("Ventnor Avenue", "Yellow", 260, { 22, 110, 330, 800, 975, 1150 }),
	utility("Water Works"),
	property("Marvin Gardens", "Yellow", 280, { 24, 120, 360, 850, 1025, 1200 }),
	special("Go To Jail", "GoToJail"),
	property("Pacific Avenue", "Green", 300, { 26, 130, 390, 900, 1100, 1275 }),
	property("North Carolina Avenue", "Green", 300, { 26, 130, 390, 900, 1100, 1275 }),
	special("Community Chest", "CommunityChest"),
	property("Pennsylvania Avenue", "Green", 320, { 28, 150, 450, 1000, 1200, 1400 }),
	railroad("Short Line"),
	special("Chance", "Chance"),
	property("Park Place", "DarkBlue", 350, { 35, 175, 500, 1100, 1300, 1500 }),
	tax("Luxury Tax", 100),
	property("Boardwalk", "DarkBlue", 400, { 50, 200, 600, 1400, 1700, 2000 }),
}

for i, tile in list do
	tile.position = i - 1
	table.freeze(tile)
end
table.freeze(list)

local Tiles = {}

Tiles.COUNT = #list
Tiles.list = list

function Tiles.at(position: number): Tile
	assert(position % 1 == 0 and position >= 0 and position < Tiles.COUNT, `invalid board position {position}`)
	return list[position + 1]
end

return Tiles
