--!strict
-- The picture on each Chance and Community Chest card, like the drawings on the real cards: a money
-- bag for a payout, the bank, a signpost for "advance to", a cake for your birthday... Renders from
-- tools/blender/card_art.py (assets/cards); the officer, the question mark and the chest are the
-- board's own (TileArt). Other maps' cards share their classic card's picture.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TileArt = require(ReplicatedStorage.Shared.Board.TileArt)
local Icons = require(script.Parent.Icons)
local MapLook = require(ReplicatedStorage.Shared.Board.MapLook)

local CardArt = {}

CardArt.IMAGES = table.freeze({
	MoneyBag = "rbxassetid://119140194691256",
	Bank = "rbxassetid://131521240641341",
	Signpost = "rbxassetid://131351062872560",
	Locomotive = "rbxassetid://98231097503814",
	Utilities = "rbxassetid://102452342633330",
	Key = "rbxassetid://133898038040007",
	UTurn = "rbxassetid://100651535035429",
	Tools = "rbxassetid://81218189308084",
	TopHat = "rbxassetid://122422895874992",
	Cash = "rbxassetid://139263702417666",
	DoctorBag = "rbxassetid://95058342650921",
	Chart = "rbxassetid://115712049621272",
	Gift = "rbxassetid://135597231681027",
	Cake = "rbxassetid://126678883630873",
	GradCap = "rbxassetid://125423462192684",
	Briefcase = "rbxassetid://75459761582596",
	Trophy = "rbxassetid://121060801437842",
	Go = "rbxassetid://135849455482326",
	Car = TileArt.IMAGES.Car,
	Officer = TileArt.IMAGES.Officer,
	Question = TileArt.IMAGES.Question,
	Chest = TileArt.IMAGES.Chest,
	-- The EIU map's own pictures.
	Handcuffs = "rbxassetid://109416490896292",
	Ghost = "rbxassetid://129675069575441",
	OldMain = "rbxassetid://98538257170628",
	PizzaBox = "rbxassetid://86896291630742",
	CarePackage = "rbxassetid://87963715586346",
	PawPrint = "rbxassetid://74452312839289",
	NeonSign = "rbxassetid://106183779954169",
	-- Crazy Chance pictures: the game's own rendered icons.
	Podium = Icons.uri("Podium"),
	Storm = Icons.uri("Storm"),
	Swap = Icons.uri("Swap"),
	Doubles = Icons.uri("Doubles"),
	CashFlow = Icons.uri("CashFlow"),
	Clover = Icons.uri("Clover"),
	MoneyRain = Icons.uri("MoneyRain"),
	Coins = Icons.uri("Coins"),
	Swords = Icons.uri("Swords"),
	Trade = Icons.uri("Trade"),
	House = Icons.uri("House"),
	Fireworks = Icons.uri("Fireworks"),
	Jail = Icons.uri("Jail"),
	LockOpen = Icons.uri("LockOpen"),
	Lightning = Icons.uri("Lightning"),
})

-- Card id -> picture: classic ids, and other maps' ids where their own picture fits better.
CardArt.BY_CARD = table.freeze({
	["chance.dividend"] = "MoneyBag",
	["chance.loan"] = "Bank",
	["chance.speeding"] = "Car",
	["chance.boardwalk"] = "Signpost",
	["chance.go"] = "Go",
	["chance.illinois"] = "Signpost",
	["chance.stCharles"] = "Signpost",
	["chance.reading"] = "Locomotive",
	["chance.railroad1"] = "Locomotive",
	["chance.railroad2"] = "Locomotive",
	["chance.utility"] = "Utilities",
	["chance.jailFree"] = "Key",
	["chance.back3"] = "UTurn",
	["chance.jail"] = "Officer",
	["chance.repairs"] = "Tools",
	["chance.chairman"] = "TopHat",
	["chest.taxRefund"] = "Cash",
	["chest.bankError"] = "Bank",
	["chest.doctor"] = "DoctorBag",
	["chest.stock"] = "Chart",
	["chest.go"] = "Go",
	["chest.jailFree"] = "Key",
	["chest.jail"] = "Officer",
	["chest.holiday"] = "Gift",
	["chest.birthday"] = "Cake",
	["chest.lifeInsurance"] = "MoneyBag",
	["chest.hospital"] = "DoctorBag",
	["chest.school"] = "GradCap",
	["chest.consultancy"] = "Briefcase",
	["chest.streetRepairs"] = "Tools",
	["chest.beautyContest"] = "Trophy",
	["chest.inherit"] = "Cash",
	jail = "Officer", -- the card everyone sees when someone is sent to jail
	["crazy.swapLeader"] = "Podium",
	["crazy.scatter"] = "Storm",
	["crazy.reverse"] = "Swap",
	["crazy.extraTurn"] = "Doubles",
	["crazy.robinHood"] = "CashFlow",
	["crazy.lottery"] = "Clover",
	["crazy.jackpot"] = "MoneyRain",
	["crazy.splitCash"] = "Coins",
	["crazy.heist"] = "Swords",
	["crazy.swapDeed"] = "Trade",
	["crazy.freeHouse"] = "House",
	["crazy.demolition"] = "Fireworks",
	["crazy.massArrest"] = "Jail",
	["crazy.jailbreak"] = "LockOpen",
	-- The EIU Crazy Night deck.
	["eiu.crazy.wrongHouse"] = "Podium",
	["eiu.crazy.ghost"] = "Ghost",
	["eiu.crazy.oneWay"] = "Swap",
	["eiu.crazy.allNighter"] = "Doubles",
	["eiu.crazy.philanthropy"] = "CashFlow",
	["eiu.crazy.raffle"] = "Clover",
	["eiu.crazy.alumni"] = "PawPrint",
	["eiu.crazy.houseFund"] = "Coins",
	["eiu.crazy.composite"] = "Swords",
	["eiu.crazy.roomSwap"] = "Trade",
	["eiu.crazy.alumniWeekend"] = "House",
	["eiu.crazy.inspection"] = "Tools",
	["eiu.crazy.noiseComplaint"] = "Jail",
	["eiu.crazy.brothersPitchIn"] = "LockOpen",
	["eiu.crazy.bailBuddy"] = "Handcuffs",
	["eiu.crazy.blockParty"] = "Officer",
	-- EIU cards whose classic picture doesn't fit.
	["eiu.chance.jail"] = "Handcuffs",
	["eiu.chest.jail"] = "Handcuffs",
	["eiu.chance.boardwalk"] = "OldMain",
	["eiu.chance.illinois"] = "PawPrint",
	["eiu.chance.reading"] = "NeonSign",
	["eiu.chance.railroad1"] = "NeonSign",
	["eiu.chance.railroad2"] = "NeonSign",
	["eiu.chance.utility"] = "PizzaBox",
	["eiu.chest.inherit"] = "CarePackage",
})

-- The big picture on each deck's back, as on the real decks.
CardArt.BACKS = table.freeze({
	Chance = "Question",
	CommunityChest = "Chest",
	Jail = "Officer",
	Crazy = "Lightning",
})

function CardArt.forCard(cardId: string): string?
	local _, classic = MapLook.forCard(cardId)
	local name = CardArt.BY_CARD[cardId] or CardArt.BY_CARD[classic]
	return name and CardArt.IMAGES[name]
end

function CardArt.back(deck: string): string?
	local name = CardArt.BACKS[deck]
	return name and CardArt.IMAGES[name]
end

return CardArt
