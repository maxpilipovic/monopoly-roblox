--!strict
-- The Chance and Community Chest cards. A new game's decks start in the order listed here and are
-- then shuffled. Each list starts with money-only cards (Chance: three, Community Chest: one):
-- tests that roll onto a card tile with unshuffled decks rely on that, so keep them first.

export type DeckName = "Chance" | "CommunityChest" | "Crazy"

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

-- Crazy Chance (a room setting): wild cards that turn the game over. When it's on, a third of
-- Chance draws come from this deck instead (EIU has its own, EIU_CRAZY). Effects beyond the classic
-- ones: SwapWithLeader, Scatter, Reverse, ExtraTurn, RobinHood (amount), Lottery (amount),
-- SplitCash, Heist, SwapDeed, FreeHouse (amount: paid when you have no set), Demolition,
-- MassArrest, Jailbreak.
local CRAZY: { Entry } = {
	{ id = "crazy.swapLeader", text = "Swap places on the board with the richest player.", effect = { kind = "SwapWithLeader" } },
	{ id = "crazy.scatter", text = "Earthquake! Every piece is thrown to a random square.", effect = { kind = "Scatter" } },
	{ id = "crazy.reverse", text = "Reverse! Play now goes the other way round the table.", effect = { kind = "Reverse" } },
	{ id = "crazy.extraTurn", text = "Take another turn after this one.", effect = { kind = "ExtraTurn" } },
	{ id = "crazy.robinHood", text = "Robin Hood: the richest player pays the poorest $200.", effect = { kind = "RobinHood", amount = 200 } },
	{ id = "crazy.lottery", text = "Lottery! Everyone puts in $50 and one lucky player takes the pot.", effect = { kind = "Lottery", amount = 50 } },
	{ id = "crazy.jackpot", text = "Bank error of the century. Collect $500.", effect = { kind = "Collect", amount = 500 } },
	{ id = "crazy.splitCash", text = "Everyone's cash goes in one pile and is split evenly.", effect = { kind = "SplitCash" } },
	{ id = "crazy.heist", text = "Heist! Take a random unbuilt property from the richest player.", effect = { kind = "Heist" } },
	{ id = "crazy.swapDeed", text = "Swap one of your unbuilt properties for a random one of someone else's.", effect = { kind = "SwapDeed" } },
	{ id = "crazy.freeHouse", text = "Building boom: a free house on one of your sets. No set? Collect $100.", effect = { kind = "FreeHouse", amount = 100 } },
	{ id = "crazy.demolition", text = "Demolition! Every street with buildings loses a house.", effect = { kind = "Demolition" } },
	{ id = "crazy.massArrest", text = "Mass arrest! Everyone else goes to Jail.", effect = { kind = "MassArrest" } },
	{ id = "crazy.jailbreak", text = "Jailbreak! Everyone in Jail walks free.", effect = { kind = "Jailbreak" } },
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

-- EIU text for each classic card; same effect, same order, id "eiu.<classic id>". The hangouts are
-- named, never drinking: the game must stay outside Roblox's Restricted rating.
local EIU_TEXT: { [string]: string } = {
	["chance.dividend"] = "Won the cornhole tournament at the tailgate. Collect $50.",
	["chance.loan"] = "Your refund check finally hits. Collect $150.",
	["chance.speeding"] = "Parking Services got you again. Pay $15.",
	["chance.boardwalk"] = "Graduation day! Advance to Old Main.",
	["chance.go"] = "Back to Move-In Day. Collect $200.",
	["chance.illinois"] = "The Panther Parade heads uptown. Advance to The Square. If you pass Move-In Day, collect $200.",
	["chance.stCharles"] = "You actually went to class. Advance to Coleman Hall. If you pass Move-In Day, collect $200.",
	["chance.reading"] = "The boys are at Marty's. Head over. If you pass Move-In Day, collect $200.",
	["chance.railroad1"] = "The group chat says the party moved. Advance to the nearest hangout. If it is owned, pay the owner double.",
	["chance.railroad2"] = "The group chat says the party moved. Advance to the nearest hangout. If it is owned, pay the owner double.",
	["chance.utility"] = "Late-night munchies. Advance to the nearest delivery spot. If it is owned, roll and pay the owner ten times the roll.",
	["chance.jailFree"] = "Your frat brother's dad is a lawyer. Get out of Coles County Jail free. Keep this card until needed.",
	["chance.back3"] = "Forgot your Panther Card. Go back 3 spaces.",
	["chance.jail"] = "Caught climbing the Old Main tower. Go to Coles County Jail. Do not pass Move-In Day, do not collect $200.",
	["chance.repairs"] = "The party got out of hand. Pay $25 per house and $100 per hotel.",
	["chance.chairman"] = "Elected chapter president. Pay each player $50 for the formal.",
	["chest.taxRefund"] = "Textbook buyback at the Union. Collect $20.",
	["chest.bankError"] = "Financial aid office error in your favor. Collect $200.",
	["chest.doctor"] = "Health Services copay. Pay $50.",
	["chest.stock"] = "Sold your old futon. Collect $50.",
	["chest.go"] = "Back to Move-In Day. Collect $200.",
	["chest.jailFree"] = "Mom's on speed dial. Get out of Coles County Jail free. Keep this card until needed.",
	["chest.jail"] = "Pulled the fire alarm in Carman Hall at 3 a.m. Go to Coles County Jail. Do not pass Move-In Day, do not collect $200.",
	["chest.holiday"] = "Summer job at Lake Charleston pays off. Collect $100.",
	["chest.birthday"] = "It's your birthday. Collect $10 from every player.",
	["chest.lifeInsurance"] = "Grandma's card had a $100 bill in it. Collect $100.",
	["chest.hospital"] = "Slept through your final in Lumpkin. Pay $100 to retake it.",
	["chest.school"] = "Lab fees due. Pay $50.",
	["chest.consultancy"] = "Tutored a freshman in Booth Library. Collect $25.",
	["chest.streetRepairs"] = "Greek Court housing fines: pay $40 per house and $115 per hotel.",
	["chest.beautyContest"] = "Second place in the Homecoming lawn display contest. Collect $10.",
	["chest.inherit"] = "Care package from home with $100 hidden in the cookies. Collect $100.",
}

-- The EIU Crazy Chance deck ("Crazy Night"), drawn instead of CRAZY on the EIU map.
local EIU_CRAZY: { Entry } = {
	{ id = "eiu.crazy.wrongHouse", text = "Woke up in the wrong house after the party. Swap places with the richest player.", effect = { kind = "SwapWithLeader" } },
	{ id = "eiu.crazy.ghost", text = "Mary Hawkins was seen on Pemberton's 4th floor. Everyone runs to a random square.", effect = { kind = "Scatter" } },
	{ id = "eiu.crazy.oneWay", text = "Someone flipped the one-way signs on 4th Street. Play goes the other way round.", effect = { kind = "Reverse" } },
	{ id = "eiu.crazy.allNighter", text = "All-nighter in Booth and you're still going. Take another turn.", effect = { kind = "ExtraTurn" } },
	{ id = "eiu.crazy.philanthropy", text = "Philanthropy week: the richest player pays the poorest $200.", effect = { kind = "RobinHood", amount = 200 } },
	{ id = "eiu.crazy.raffle", text = "Chapter raffle! Everyone puts in $50 and one lucky player takes the pot.", effect = { kind = "Lottery", amount = 50 } },
	{ id = "eiu.crazy.alumni", text = "A rich Sigma Pi alum is feeling generous. Collect $500.", effect = { kind = "Collect", amount = 500 } },
	{ id = "eiu.crazy.houseFund", text = "House meeting: everyone's cash goes in the house fund and is split evenly.", effect = { kind = "SplitCash" } },
	{
		id = "eiu.crazy.composite",
		text = "Your pledge class stole the rival house's composite. Take a random unbuilt property from the richest player.",
		effect = { kind = "Heist" },
	},
	{ id = "eiu.crazy.roomSwap", text = "Room swap! Trade one of your unbuilt properties for a random one of someone else's.", effect = { kind = "SwapDeed" } },
	{
		id = "eiu.crazy.alumniWeekend",
		text = "Alumni weekend: they build you a free house on one of your sets. No set? Collect $100.",
		effect = { kind = "FreeHouse", amount = 100 },
	},
	{ id = "eiu.crazy.inspection", text = "Surprise housing inspection! Every street with buildings loses a house.", effect = { kind = "Demolition" } },
	{ id = "eiu.crazy.noiseComplaint", text = "Noise complaint sweep. Charleston PD takes everyone else to Coles County Jail.", effect = { kind = "MassArrest" } },
	{ id = "eiu.crazy.brothersPitchIn", text = "The brothers pool their cash. Everyone in Coles County Jail walks free.", effect = { kind = "Jailbreak" } },
}

-- A map's own text for each classic card: same effect, same order, id "<prefix>.<classic id>".
local function mapEntries(prefix: string, texts: { [string]: string }, entries: { Entry }): { Entry }
	local out = {}
	for _, entry in entries do
		local text = texts[entry.id]
		assert(text, `no {prefix} text for {entry.id}`)
		table.insert(out, { id = `{prefix}.{entry.id}`, text = text, effect = table.clone(entry.effect) })
	end
	return out
end

local Cards = {}

-- The classic decks, every game. The crazy deck is apart: only Crazy Chance games draw from it.
Cards.DECKS = table.freeze({ "Chance", "CommunityChest" } :: { DeckName })
Cards.CRAZY = "Crazy" :: DeckName
Cards.CRAZY_TITLE = "Crazy Chance"

type MapCards = { list: { Card }, idsByDeck: { [string]: { string } }, titles: { [string]: string } }

local byId: { [string]: Card } = {}
local titleById: { [string]: string } = {} -- each card's deck title on its own map

local function buildMap(chance: { Entry }, chest: { Entry }, crazy: { Entry }, titles: { [string]: string }): MapCards
	local list: { Card } = {}
	local idsByDeck: { [string]: { string } } = {}
	local function addDeck(deck: DeckName, entries: { Entry }, title: string, listed: boolean)
		local ids = {}
		for _, entry in entries do
			local card: Card = { id = entry.id, deck = deck, text = entry.text, effect = table.freeze(table.clone(entry.effect)) }
			table.freeze(card)
			if listed then
				table.insert(list, card)
			end
			byId[card.id] = card
			titleById[card.id] = title
			table.insert(ids, card.id)
		end
		idsByDeck[deck] = table.freeze(ids)
	end
	addDeck("Chance", chance, titles.Chance, true)
	addDeck("CommunityChest", chest, titles.CommunityChest, true)
	addDeck(Cards.CRAZY, crazy, titles.Crazy, false)
	return { list = table.freeze(list), idsByDeck = idsByDeck, titles = table.freeze(titles) }
end

local MAPS: { [string]: MapCards } = {
	Classic = buildMap(CHANCE, COMMUNITY_CHEST, CRAZY, { Chance = "Chance", CommunityChest = "Community Chest", Crazy = Cards.CRAZY_TITLE }),
	College = buildMap(
		mapEntries("college", COLLEGE_TEXT, CHANCE),
		mapEntries("college", COLLEGE_TEXT, COMMUNITY_CHEST),
		CRAZY,
		{ Chance = "Pop Quiz", CommunityChest = "Student Union", Crazy = Cards.CRAZY_TITLE }
	),
	EIU = buildMap(
		mapEntries("eiu", EIU_TEXT, CHANCE),
		mapEntries("eiu", EIU_TEXT, COMMUNITY_CHEST),
		EIU_CRAZY,
		{ Chance = "Saturday Night", CommunityChest = "Care Package", Crazy = "Crazy Night" }
	),
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
