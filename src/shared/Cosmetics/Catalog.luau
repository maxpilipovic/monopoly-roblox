--!strict
-- Everything a player can own and show off: game pieces (the three defaults everyone has, and chest
-- pieces with their own special effect) and rent effects (played over whoever pays you rent).

export type Item = {
	id: string,
	kind: string, -- "Piece" | "RentEffect"
	name: string,
	rarity: string,
	effect: string?, -- a piece's particle effect (PieceEffects)
	default: boolean?, -- everyone owns it
	blurb: string,
}

local Catalog = {}

Catalog.RARITIES = { "Common", "Rare", "Epic", "Legendary" }
Catalog.RARITY_COLORS = table.freeze({
	Common = Color3.fromRGB(176, 186, 204),
	Rare = Color3.fromRGB(86, 156, 255),
	Epic = Color3.fromRGB(178, 102, 255),
	Legendary = Color3.fromRGB(255, 190, 64),
})

local function piece(id: string, name: string, rarity: string, effect: string?, blurb: string, default: boolean?): Item
	return { id = id, kind = "Piece", name = name, rarity = rarity, effect = effect, blurb = blurb, default = default }
end

local function rentEffect(id: string, name: string, rarity: string, blurb: string): Item
	return { id = id, kind = "RentEffect", name = name, rarity = rarity, blurb = blurb }
end

Catalog.ITEMS = {
	piece("TopHat", "Top Hat", "Common", nil, "A gentleman's classic.", true),
	piece("Battleship", "Battleship", "Common", nil, "Rules the board's seven seas.", true),
	piece("RaceCar", "Race Car", "Common", nil, "Built for passing Go.", true),

	piece("Duck", "Rubber Duck", "Common", "Bubbles", "Leaves a trail of bubbles."),
	piece("Cactus", "Cactus", "Common", "SandPuff", "Kicks up desert sand."),
	piece("Anchor", "Anchor", "Common", "Droplets", "Drips with sea water."),
	piece("Robot", "Robot", "Rare", "NeonSparks", "Glows and throws sparks."),
	piece("Lighthouse", "Lighthouse", "Rare", "Beam", "A sweeping beacon."),
	piece("Trophy", "Trophy", "Rare", "Confetti", "Celebrates every step."),
	piece("Rocket", "Rocket", "Epic", "FireTrail", "Blasts off in a trail of fire."),
	piece("Ghost", "Ghost", "Epic", "Mist", "Half there, trailing mist."),
	piece("UFO", "UFO", "Epic", "TractorBeam", "Hovers on a tractor beam."),
	piece("Crown", "Crown", "Legendary", "GoldHalo", "Gold sparkles and a halo."),
	piece("Diamond", "Diamond", "Legendary", "Frost", "Cold, bright and rare."),
	piece("Skull", "Skull", "Legendary", "PurpleFlames", "Wreathed in purple flame."),

	rentEffect("CoinBurst", "Coin Burst", "Common", "Coins burst over whoever pays you."),
	rentEffect("ConfettiPop", "Confetti Pop", "Common", "A pop of confetti on payday."),
	rentEffect("MoneyRain", "Money Rain", "Rare", "Bills rain down on your tenant."),
	rentEffect("GoldenAura", "Golden Aura", "Rare", "A golden glow claims your due."),
	rentEffect("Lightning", "Lightning Strike", "Epic", "Lightning strikes the payer."),
	rentEffect("Fireworks", "Fireworks", "Epic", "Fireworks for every rent paid."),
	rentEffect("BlackHole", "Black Hole", "Legendary", "A black hole swallows their cash."),
}

Catalog.byId = {} :: { [string]: Item }
for _, item in Catalog.ITEMS do
	Catalog.byId[item.id] = item
end

Catalog.DEFAULT_PIECES = { "TopHat", "Battleship", "RaceCar" }
Catalog.DEFAULT_PIECE = "TopHat"

-- What a chest can give at this rarity (never the defaults).
function Catalog.droppable(rarity: string): { Item }
	local items = {}
	for _, item in Catalog.ITEMS do
		if item.rarity == rarity and not item.default then
			table.insert(items, item)
		end
	end
	return items
end

return Catalog
