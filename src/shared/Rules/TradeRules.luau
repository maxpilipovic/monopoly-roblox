--!strict
-- Whether a trade offer is legal. Pure: works on any view of the properties plus a table of the
-- parties, so the server (GameState) and the trade window (snapshot) agree on what may be sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)

export type Side = {
	properties: { number }, -- board positions
	cash: number,
	jailCards: number,
}

export type Offer = {
	to: string,
	give: Side, -- from the proposer
	get: Side, -- from the receiver
}

export type Party = {
	id: string,
	name: string,
	money: number,
	jailCards: number,
	bankrupt: boolean,
	inDebt: boolean,
}

local TradeRules = {}

local PURCHASABLE = { Property = true, Railroad = true, Utility = true }
local JAIL_CARD_VALUE = 50

-- Whole, finite and not negative. NaN fails `x == x`; infinity fails `x % 1 == 0` (inf % 1 is NaN).
local function isCount(value: any): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 0
end

local function isDeedList(value: any): boolean
	if typeof(value) ~= "table" or #value > Tiles.COUNT then
		return false
	end
	local count = 0
	for key, position in value do
		count += 1
		if typeof(key) ~= "number" or not isCount(position) or position >= Tiles.COUNT then
			return false
		end
		if not PURCHASABLE[Tiles.at(position).kind] then
			return false
		end
	end
	return count == #value -- a proper list, no holes or extra keys
end

local function isSide(value: any): boolean
	return typeof(value) == "table" and isDeedList(value.properties) and isCount(value.cash) and isCount(value.jailCards)
end

function TradeRules.tradable(view: PropertyRules.View, position: number): (boolean, string?)
	local tile = Tiles.at(position)
	if tile.kind == "Property" then
		for _, other in PropertyRules.groupPositions(tile.group :: string) do
			local ownership = view.properties[other]
			if ownership and ownership.houses > 0 then
				return false, "sell the buildings in this set first"
			end
		end
	end
	return true
end

function TradeRules.validate(
	view: PropertyRules.View,
	parties: { [string]: Party },
	fromId: string,
	offer: any
): (boolean, string?)
	if typeof(offer) ~= "table" or not isSide(offer.give) or not isSide(offer.get) then
		return false, "invalid offer"
	end
	local to = if typeof(offer.to) == "string" then parties[offer.to] else nil
	local from = parties[fromId]
	if not to or not from or to.id == fromId then
		return false, "pick another player"
	elseif to.bankrupt then
		return false, "that player is out of the game"
	end

	local give: Side, get: Side = offer.give, offer.get
	local seen = {}
	for _, list in { give.properties, get.properties } do
		for _, position in list do
			if seen[position] then
				return false, "invalid offer"
			end
			seen[position] = true
		end
	end
	if #give.properties + #get.properties + give.cash + get.cash + give.jailCards + get.jailCards == 0 then
		return false, "the offer is empty"
	end

	for _, position in give.properties do
		local ownership = view.properties[position]
		if not ownership or ownership.owner ~= fromId then
			return false, `you don't own {Tiles.at(position).name}`
		end
	end
	for _, position in get.properties do
		local ownership = view.properties[position]
		if not ownership or ownership.owner ~= to.id then
			return false, `{to.name} doesn't own {Tiles.at(position).name}`
		end
	end
	for position in seen do
		local ok, err = TradeRules.tradable(view, position)
		if not ok then
			return false, err
		end
	end

	if give.cash > from.money then
		return false, "you don't have that much cash"
	elseif get.cash > to.money then
		return false, `{to.name} doesn't have that much cash`
	elseif give.jailCards > from.jailCards then
		return false, "you don't have that many jail cards"
	elseif get.jailCards > to.jailCards then
		return false, `{to.name} doesn't have that many jail cards`
	end

	-- Someone in debt can't hand their assets to another player on the way out.
	local giveValue, getValue = TradeRules.value(give), TradeRules.value(get)
	if from.inDebt and getValue < giveValue then
		return false, `while in debt you must get at least ${giveValue} in value`
	elseif to.inDebt and giveValue < getValue then
		return false, `{to.name} is in debt and must get at least ${getValue} in value`
	end
	return true
end

-- What a side is worth for the debt check: cash at face value, each deed at its mortgage value
-- (what the bank would give for it, mortgaged or not), each jail card $50.
function TradeRules.value(side: Side): number
	local total = side.cash + side.jailCards * JAIL_CARD_VALUE
	for _, position in side.properties do
		total += PropertyRules.mortgageValue(position)
	end
	return total
end

local function copySide(side: Side): Side
	return { properties = table.clone(side.properties), cash = side.cash, jailCards = side.jailCards }
end

function TradeRules.copy(offer: Offer): Offer
	return { to = offer.to, give = copySide(offer.give), get = copySide(offer.get) }
end

return TradeRules
