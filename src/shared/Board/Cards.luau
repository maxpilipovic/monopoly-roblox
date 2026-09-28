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

local Cards = {}

Cards.DECKS = table.freeze({ "Chance", "CommunityChest" } :: { DeckName })
Cards.DECK_TITLES = table.freeze({ Chance = "Chance", CommunityChest = "Community Chest" })

local list: { Card } = {}
local byId: { [string]: Card } = {}
local idsByDeck: { [string]: { string } } = {}

local function addDeck(deck: DeckName, entries: { Entry })
	local ids = {}
	for _, entry in entries do
		local card: Card = { id = entry.id, deck = deck, text = entry.text, effect = table.freeze(entry.effect) }
		table.freeze(card)
		table.insert(list, card)
		byId[card.id] = card
		table.insert(ids, card.id)
	end
	idsByDeck[deck] = table.freeze(ids)
end

addDeck("Chance", CHANCE)
addDeck("CommunityChest", COMMUNITY_CHEST)

Cards.list = table.freeze(list)
Cards.byId = table.freeze(byId)

-- A new array of the deck's card ids in listed order (callers may shuffle it).
function Cards.idsFor(deck: string): { string }
	return table.clone(assert(idsByDeck[deck], `unknown deck {deck}`))
end

return Cards
