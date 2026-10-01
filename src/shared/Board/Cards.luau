--!strict
-- The Chance and Community Chest cards. A new game's decks start in the order listed here and are
-- then shuffled. Each list starts with money-only cards (Chance: three, Community Chest: one):
-- tests that roll onto a card tile with unshuffled decks rely on that, so keep them first.

export type DeckName = "Chance" | "CommunityChest"

-- kind: Collect / Pay / PayEachPlayer / CollectFromEachPlayer (amount), AdvanceTo (position),
-- AdvanceToNearest (tileKind: "Railroad" | "Utility"), GoBack (spaces), GoToJail, JailFree,
-- Repairs (perHouse, perHotel).
export type Effect = {
	kind: string,
	amount: number?,
	position: number?,
	tileKind: string?,
	spaces: number?,
	perHouse: number?,
	perHotel: number?,
}

export type Card = {
	id: string,
	deck: DeckName,
	text: string,
	effect: Effect,
}

type Entry = { id: string, text: string, effect: Effect }

local CHANCE: { Entry } = {
	{ id = "chance.dividend", text = "Bank pays you a dividend of $50.", effect = { kind = "Collect", amount = 50 } },
	{ id = "chance.loan", text = "Your building loan matures. Collect $150.", effect = { kind = "Collect", amount = 150 } },
	{ id = "chance.speeding", text = "Speeding fine: pay $15.", effect = { kind = "Pay", amount = 15 } },
	{ id = "chance.boardwalk", text = "Advance to Boardwalk.", effect = { kind = "AdvanceTo", position = 39 } },
	{ id = "chance.go", text = "Advance to Go. Collect $200.", effect = { kind = "AdvanceTo", position = 0 } },
	{
		id = "chance.illinois",
		text = "Advance to Illinois Avenue. If you pass Go, collect $200.",
		effect = { kind = "AdvanceTo", position = 24 },
	},
	{
		id = "chance.stCharles",
		text = "Advance to St. Charles Place. If you pass Go, collect $200.",
		effect = { kind = "AdvanceTo", position = 11 },
	},
	{
		id = "chance.reading",
		text = "Take a trip to Reading Railroad. If you pass Go, collect $200.",
		effect = { kind = "AdvanceTo", position = 5 },
	},
	{
		id = "chance.railroad1",
		text = "Advance to the nearest Railroad. If it is owned, pay the owner twice the rent.",
		effect = { kind = "AdvanceToNearest", tileKind = "Railroad" },
	},
	{
		id = "chance.railroad2",
		text = "Advance to the nearest Railroad. If it is owned, pay the owner twice the rent.",
		effect = { kind = "AdvanceToNearest", tileKind = "Railroad" },
	},
	{
		id = "chance.utility",
		text = "Advance to the nearest Utility. If it is owned, roll the dice and pay the owner ten times the roll.",
		effect = { kind = "AdvanceToNearest", tileKind = "Utility" },
	},
	{ id = "chance.jailFree", text = "Get Out of Jail Free. Keep this card until needed.", effect = { kind = "JailFree" } },
	{ id = "chance.back3", text = "Go back 3 spaces.", effect = { kind = "GoBack", spaces = 3 } },
	{ id = "chance.jail", text = "Go to Jail. Do not pass Go, do not collect $200.", effect = { kind = "GoToJail" } },
	{
		id = "chance.repairs",
		text = "Make general repairs on all your property: pay $25 per house and $100 per hotel.",
		effect = { kind = "Repairs", perHouse = 25, perHotel = 100 },
	},
	{
		id = "chance.chairman",
		text = "You have been elected Chairman of the Board. Pay each player $50.",
		effect = { kind = "PayEachPlayer", amount = 50 },
	},
}

local COMMUNITY_CHEST: { Entry } = {
	{ id = "chest.taxRefund", text = "Income tax refund. Collect $20.", effect = { kind = "Collect", amount = 20 } },
	{ id = "chest.bankError", text = "Bank error in your favor. Collect $200.", effect = { kind = "Collect", amount = 200 } },
	{ id = "chest.doctor", text = "Doctor's fee. Pay $50.", effect = { kind = "Pay", amount = 50 } },
	{ id = "chest.stock", text = "From sale of stock you get $50.", effect = { kind = "Collect", amount = 50 } },
	{ id = "chest.go", text = "Advance to Go. Collect $200.", effect = { kind = "AdvanceTo", position = 0 } },
	{ id = "chest.jailFree", text = "Get Out of Jail Free. Keep this card until needed.", effect = { kind = "JailFree" } },
	{ id = "chest.jail", text = "Go to Jail. Do not pass Go, do not collect $200.", effect = { kind = "GoToJail" } },
	{ id = "chest.holiday", text = "Holiday fund matures. Collect $100.", effect = { kind = "Collect", amount = 100 } },
	{
		id = "chest.birthday",
		text = "It is your birthday. Collect $10 from every player.",
		effect = { kind = "CollectFromEachPlayer", amount = 10 },
	},
	{ id = "chest.lifeInsurance", text = "Life insurance matures. Collect $100.", effect = { kind = "Collect", amount = 100 } },
	{ id = "chest.hospital", text = "Pay hospital fees of $100.", effect = { kind = "Pay", amount = 100 } },
	{ id = "chest.school", text = "Pay school fees of $50.", effect = { kind = "Pay", amount = 50 } },
	{ id = "chest.consultancy", text = "Receive a $25 consultancy fee.", effect = { kind = "Collect", amount = 25 } },
	{
		id = "chest.streetRepairs",
		text = "You are assessed for street repairs: pay $40 per house and $115 per hotel.",
		effect = { kind = "Repairs", perHouse = 40, perHotel = 115 },
	},
	{
		id = "chest.beautyContest",
		text = "You have won second prize in a beauty contest. Collect $10.",
		effect = { kind = "Collect", amount = 10 },
	},
	{ id = "chest.inherit", text = "You inherit $100.", effect = { kind = "Collect", amount = 100 } },
}

-- College text for each classic card; same effect, same order, id "college.<classic id>".
local COLLEGE_TEXT: { [string]: string } = {
	["chance.dividend"] = "Your campus job pays out. Collect $50.",
	["chance.loan"] = "Your scholarship comes through. Collect $150.",
	["chance.speeding"] = "Library late fee: pay $15.",
	["chance.boardwalk"] = "Tickets to the big game: advance to the Football Stadium.",
	["chance.go"] = "Back to Orientation. Collect $200.",
	["chance.illinois"] = "Advance to Engineering Hall. If you pass Orientation, collect $200.",
	["chance.stCharles"] = "Advance to the Art Studio. If you pass Orientation, collect $200.",
	["chance.reading"] = "Catch the North Campus Shuttle. If you pass Orientation, collect $200.",
	["chance.railroad1"] = "Run for the nearest shuttle. If it is owned, pay the owner twice the fare.",
	["chance.railroad2"] = "Run for the nearest shuttle. If it is owned, pay the owner twice the fare.",
	["chance.utility"] = "Head to the nearest utility. If it is owned, roll the dice and pay the owner ten times the roll.",
	["chance.jailFree"] = "Doctor's note: get out of the Dean's Office free. Keep this card until needed.",
	["chance.back3"] = "Forgot your student ID. Go back 3 spaces.",
	["chance.jail"] = "Caught plagiarizing. Go to the Dean's Office. Do not pass Orientation, do not collect $200.",
	["chance.repairs"] = "Dorm damage inspection: pay $25 per house and $100 per hotel.",
	["chance.chairman"] = "Elected class president. Buy each player a $50 pizza.",
	["chest.taxRefund"] = "Textbook buyback. Collect $20.",
	["chest.bankError"] = "Financial aid office error in your favor. Collect $200.",
	["chest.doctor"] = "Campus clinic copay. Pay $50.",
	["chest.stock"] = "Sold your old laptop. Collect $50.",
	["chest.go"] = "Back to Orientation. Collect $200.",
	["chest.jailFree"] = "Get out of the Dean's Office free. Keep this card until needed.",
	["chest.jail"] = "Pulled the fire alarm. Go to the Dean's Office. Do not pass Orientation, do not collect $200.",
	["chest.holiday"] = "Summer internship pays off. Collect $100.",
	["chest.birthday"] = "It's your birthday. Collect $10 from every player.",
	["chest.lifeInsurance"] = "Won the hackathon. Collect $100.",
	["chest.hospital"] = "Slept through the final. Pay $100 to retake it.",
	["chest.school"] = "Lab fees due. Pay $50.",
	["chest.consultancy"] = "Tutored a classmate. Collect $25.",
	["chest.streetRepairs"] = "Housing fines for your parties: pay $40 per house and $115 per hotel.",
	["chest.beautyContest"] = "Second place in the talent show. Collect $10.",
	["chest.inherit"] = "Care package from home with $100 inside.",
}

local function collegeEntries(entries: { Entry }): { Entry }
	local out = {}
	for _, entry in entries do
		local text = COLLEGE_TEXT[entry.id]
		assert(text, `no college text for {entry.id}`)
		table.insert(out, { id = `college.{entry.id}`, text = text, effect = table.clone(entry.effect) })
	end
	return out
end

local Cards = {}

Cards.DECKS = table.freeze({ "Chance", "CommunityChest" } :: { DeckName })

type MapCards = { list: { Card }, idsByDeck: { [string]: { string } }, titles: { [string]: string } }

local byId: { [string]: Card } = {}
local titleById: { [string]: string } = {} -- each card's deck title on its own map

local function buildMap(chance: { Entry }, chest: { Entry }, titles: { [string]: string }): MapCards
	local list: { Card } = {}
	local idsByDeck: { [string]: { string } } = {}
	local function addDeck(deck: DeckName, entries: { Entry })
		local ids = {}
		for _, entry in entries do
			local card: Card = { id = entry.id, deck = deck, text = entry.text, effect = table.freeze(entry.effect) }
			table.freeze(card)
			table.insert(list, card)
			byId[card.id] = card
			titleById[card.id] = titles[deck]
			table.insert(ids, card.id)
		end
		idsByDeck[deck] = table.freeze(ids)
	end
	addDeck("Chance", chance)
	addDeck("CommunityChest", chest)
	return { list = table.freeze(list), idsByDeck = idsByDeck, titles = table.freeze(titles) }
end

local MAPS: { [string]: MapCards } = {
	Classic = buildMap(CHANCE, COMMUNITY_CHEST, { Chance = "Chance", CommunityChest = "Community Chest" }),
	College = buildMap(collegeEntries(CHANCE), collegeEntries(COMMUNITY_CHEST), { Chance = "Pop Quiz", CommunityChest = "Student Union" }),
}
local active = MAPS.Classic

-- Every map's cards, so a card id from any game can be shown.
Cards.byId = table.freeze(byId)
-- The active map's cards and deck titles; switched by Cards.use.
Cards.list = active.list
Cards.DECK_TITLES = active.titles

function Cards.use(mapId: string)
	active = assert(MAPS[mapId], `unknown map {mapId}`)
	Cards.list = active.list
	Cards.DECK_TITLES = active.titles
end

-- The deck title a card was printed with ("Pop Quiz" for a college Chance card), whatever map is active.
function Cards.titleFor(cardId: string): string?
	return titleById[cardId]
end

-- A new array of the active map's card ids for a deck, in listed order (callers may shuffle it).
function Cards.idsFor(deck: string): { string }
	return table.clone(assert(active.idsByDeck[deck], `unknown deck {deck}`))
end

return Cards
