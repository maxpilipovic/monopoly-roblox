--!strict
-- Everything a player can own and show off:
--   Piece       what stands for you on the board (three defaults; chest pieces carry an effect)
--   Aura        an effect worn on whatever piece you play
--   Dice        the skin your dice roll in
--   RentEffect  played over whoever pays you rent
--   Title       a name tag under yours in the lobby and at the table
-- Chest items drop from chests; exclusive items only come from challenges (the Empire Tree and
-- achievements), never from a chest.

export type Item = {
	id: string,
	kind: string, -- "Piece" | "Aura" | "Dice" | "RentEffect" | "Title"
	name: string,
	rarity: string,
	effect: string?, -- a piece's or an aura's particle effect (PieceEffects)
	default: boolean?, -- everyone owns it
	exclusive: boolean?, -- challenge reward only
	model: string?, -- a piece's model, when it isn't its own id (e.g. a gold Top Hat)
	modelKind: string?, -- the Assets folder that model is in (default "Pieces")
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
Catalog.KINDS = { "Piece", "Aura", "Dice", "RentEffect", "Title" }
Catalog.KIND_NAMES = table.freeze({
	Piece = "Piece",
	Aura = "Aura",
	Dice = "Dice skin",
	RentEffect = "Rent effect",
	Title = "Title",
})

local function piece(id: string, name: string, rarity: string, effect: string?, blurb: string, default: boolean?): Item
	return { id = id, kind = "Piece", name = name, rarity = rarity, effect = effect, blurb = blurb, default = default }
end

-- A challenge-only piece, often a new finish on another piece's model.
local function special(id: string, name: string, rarity: string, effect: string, model: string, modelKind: string, blurb: string): Item
	return {
		id = id,
		kind = "Piece",
		name = name,
		rarity = rarity,
		effect = effect,
		exclusive = true,
		model = model,
		modelKind = modelKind,
		blurb = blurb,
	}
end

local function rentEffect(id: string, name: string, rarity: string, blurb: string): Item
	return { id = id, kind = "RentEffect", name = name, rarity = rarity, blurb = blurb }
end

local function aura(id: string, name: string, rarity: string, effect: string, blurb: string, exclusive: boolean?): Item
	return { id = id, kind = "Aura", name = name, rarity = rarity, effect = effect, blurb = blurb, exclusive = exclusive }
end

local function dice(id: string, name: string, rarity: string, blurb: string, exclusive: boolean?, default: boolean?): Item
	return { id = id, kind = "Dice", name = name, rarity = rarity, blurb = blurb, exclusive = exclusive, default = default }
end

local function title(id: string, name: string, rarity: string, blurb: string): Item
	return { id = id, kind = "Title", name = name, rarity = rarity, blurb = blurb, exclusive = true }
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

	-- Challenge pieces.
	special("GoldenTopHat", "Golden Top Hat", "Epic", "GoldDust", "TopHat", "Pieces", "Solid gold, for a landlord of means."),
	special("TreasureChest", "Treasure Chest", "Legendary", "CoinShower", "Chest", "Emblems", "Spills coins wherever it goes."),
	special("LittleHouse", "Little House", "Epic", "Chimney", "House", "Buildings", "Home sweet home, chimney smoking."),
	special("GrandHotel", "Grand Hotel", "Legendary", "Starburst", "Hotel", "Buildings", "Five stars and fireworks."),
	special("MysteryBox", "Mystery Box", "Legendary", "Rainbow", "Question", "Emblems", "Nobody knows what's inside."),
	special("GhostShip", "Ghost Ship", "Epic", "Mist", "Battleship", "Pieces", "Sails through the fog, crewless."),
	special("ShadowRacer", "Shadow Racer", "Legendary", "ShadowFlames", "RaceCar", "Pieces", "Obsidian, red-lit and on fire."),
	special("WaterWorks", "Water Works", "Epic", "Droplets", "Tap", "Emblems", "The utility that never runs dry."),
	special("ExpressTrain", "Express Train", "Legendary", "Steam", "Locomotive", "Emblems", "Full steam round the board."),
	special("Flagship", "Flagship", "Epic", "Confetti", "Battleship", "Pieces", "Navy and gold, flying the colours."),
	special("PlatinumTrophy", "Platinum Trophy", "Legendary", "Starburst", "Trophy", "Pieces", "For champions only."),
	special("BrightIdea", "Bright Idea", "Legendary", "Lightbulb", "Bulb", "Emblems", "The idea that started it all."),

	aura("AuraStardust", "Stardust", "Common", "Stardust", "Twinkles round your piece."),
	aura("AuraBubbles", "Bubbles", "Common", "Bubbles", "A stream of bubbles."),
	aura("AuraEmbers", "Embers", "Rare", "Embers", "Glowing embers drift up."),
	aura("AuraSnowfall", "Snowfall", "Rare", "Snowfall", "Your own little snow cloud."),
	aura("AuraStorm", "Storm", "Epic", "Storm", "Crackles with lightning."),
	aura("AuraRainbow", "Rainbow", "Legendary", "Rainbow", "Leaves a rainbow behind."),
	aura("AuraGoldDust", "Gold Dust", "Epic", "GoldDust", "Gold flakes fall where you walk.", true),
	aura("AuraBlueprint", "Blueprint", "Epic", "Blueprint", "Drawn up by an architect.", true),
	aura("AuraClover", "Lucky Clover", "Epic", "Clover", "Luck clings to you.", true),
	aura("AuraShadow", "Shadow", "Epic", "Shadow", "Dark smoke follows you.", true),
	aura("AuraCashFlow", "Cash Flow", "Epic", "CashFlow", "Money trails behind you.", true),
	aura("AuraStarburst", "Starburst", "Legendary", "Starburst", "A champion's starry glow.", true),

	dice("DiceIvory", "Ivory", "Common", "The classic.", nil, true),
	dice("DiceMidnight", "Midnight", "Common", "Black with silver pips."),
	dice("DiceRuby", "Ruby", "Common", "Deep red with white pips."),
	dice("DiceEmerald", "Emerald", "Common", "Green felt-table green."),
	dice("DiceSapphire", "Sapphire", "Rare", "Polished blue glass."),
	dice("DiceMarble", "Marble", "Rare", "Cool white marble."),
	dice("DiceWalnut", "Walnut", "Rare", "Carved from dark wood."),
	dice("DiceNeon", "Neon", "Epic", "Glowing pink pips."),
	dice("DiceCrystal", "Crystal", "Epic", "Clear as ice."),
	dice("DiceGold", "Solid Gold", "Legendary", "Heavy, shiny, lucky."),
	dice("DiceBrick", "Brick", "Rare", "Built to last.", true),
	dice("DiceClover", "Lucky Clover", "Epic", "Green and gold luck.", true),
	dice("DiceLava", "Lava", "Legendary", "Black rock with molten pips.", true),
	dice("DiceBone", "Bone", "Epic", "Bone white, blood-red pips.", true),
	dice("DiceMoney", "Greenback", "Epic", "Printed on banknote green.", true),
	dice("DiceChampion", "Champion", "Legendary", "White and gold, for winners.", true),
	dice("DiceGalaxy", "Galaxy", "Legendary", "A night sky full of stars.", true),
	dice("DiceFrozen", "Frozen", "Epic", "Ice that never melts.", true),
	dice("DiceDiamond", "Diamond", "Legendary", "Cut diamond, sparkling.", true),
	dice("DiceCandy", "Candy", "Rare", "Sweet pink and white.", true),

	rentEffect("CoinBurst", "Coin Burst", "Common", "Coins burst over whoever pays you."),
	rentEffect("ConfettiPop", "Confetti Pop", "Common", "A pop of confetti on payday."),
	rentEffect("MoneyRain", "Money Rain", "Rare", "Bills rain down on your tenant."),
	rentEffect("GoldenAura", "Golden Aura", "Rare", "A golden glow claims your due."),
	rentEffect("Lightning", "Lightning Strike", "Epic", "Lightning strikes the payer."),
	rentEffect("Fireworks", "Fireworks", "Epic", "Fireworks for every rent paid."),
	rentEffect("BlackHole", "Black Hole", "Legendary", "A black hole swallows their cash."),

	title("TitleLandlord", "Landlord", "Rare", "Owns a street or two."),
	title("TitleTycoon", "Tycoon", "Epic", "Owns the whole block."),
	title("TitleMasterBuilder", "Master Builder", "Epic", "Hotels on every corner."),
	title("TitleHighRoller", "High Roller", "Epic", "Lives by the dice."),
	title("TitleEscapeArtist", "Escape Artist", "Epic", "No cell holds them."),
	title("TitleDealmaker", "Dealmaker", "Epic", "Every trade a win."),
	title("TitleChampion", "Champion", "Legendary", "Beats the best."),
	title("TitleMogul", "Mogul", "Legendary", "Five hundred wins."),
	title("TitleVeteran", "Veteran", "Epic", "A thousand games played."),
	title("TitleLegend", "Legend", "Legendary", "Three hundred ranked wins."),
	title("TitleRentLord", "Rent Lord", "Legendary", "Two million in rent."),
	title("TitleArchitect", "Architect", "Epic", "Five thousand houses."),
	title("TitleHotelier", "Hotelier", "Epic", "Eight hundred hotels."),
	title("TitleLucky", "Lucky", "Epic", "Snake eyes, again and again."),
	title("TitleGlobetrotter", "Globetrotter", "Rare", "Passed GO six thousand times."),
	title("TitleJailbird", "Jailbird", "Rare", "Knows every guard by name."),
	title("TitleShark", "Shark", "Legendary", "Bankrupted eight hundred rivals."),
	title("TitleAuctioneer", "Auctioneer", "Epic", "Going, going, gone."),
	title("TitleCollector", "Collector", "Epic", "Opened four hundred chests."),
	title("TitleDedicated", "Dedicated", "Legendary", "Daily challenges, every day."),
	title("TitleMonopolist", "Monopolist", "Legendary", "Owns every colour set there is."),
	title("TitleTreeTopper", "Tree Topper", "Legendary", "Finished the Empire Tree."),
}

Catalog.byId = {} :: { [string]: Item }
for _, item in Catalog.ITEMS do
	Catalog.byId[item.id] = item
end

Catalog.DEFAULT_PIECES = { "TopHat", "Battleship", "RaceCar" }
Catalog.DEFAULT_PIECE = "TopHat"
Catalog.DEFAULT_DICE = "DiceIvory"

-- What a chest can give at this rarity (never the defaults, challenge items or titles).
function Catalog.droppable(rarity: string): { Item }
	local items = {}
	for _, item in Catalog.ITEMS do
		if item.rarity == rarity and not item.default and not item.exclusive and item.kind ~= "Title" then
			table.insert(items, item)
		end
	end
	return items
end

-- Where a piece's model lives: the Assets folder and the model's name in it.
function Catalog.modelOf(id: string): (string, string)
	local item = Catalog.byId[id]
	if not item then
		return "Pieces", id
	end
	return item.modelKind or "Pieces", item.model or item.id
end

return Catalog
