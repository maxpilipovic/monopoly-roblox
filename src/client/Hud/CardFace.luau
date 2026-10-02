--!strict
-- What a drawn card shows: its deck, who drew it, its text, and a badge that says at a glance what
-- it does and whether that's good news.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Tone = "good" | "bad" | "neutral"

export type Face = {
	id: string,
	deck: string,
	title: string,
	drawer: string,
	caption: string, -- the small line over the text: "Ana drew", or just the name for a jail card
	mark: string, -- the big character on the card's back
	text: string,
	badge: { text: string, tone: Tone },
}

local CardFace = {}

local JAIL_POSITION = 10
local COLLEGE_PREFIX = "college."
-- What each map calls the tiles a "nearest" card sends you to.
local KIND_NOUNS = {
	Railroad = { classic = "railroad", college = "shuttle" },
	Utility = { classic = "utility", college = "utility" },
}

local function badge(card: Cards.Card): { text: string, tone: Tone }
	local effect = card.effect
	local kind = effect.kind
	if kind == "Collect" then
		return { text = `+${effect.amount}`, tone = "good" }
	elseif kind == "Pay" then
		return { text = `−${effect.amount}`, tone = "bad" }
	elseif kind == "PayEachPlayer" then
		return { text = `−${effect.amount} each`, tone = "bad" }
	elseif kind == "CollectFromEachPlayer" then
		return { text = `+${effect.amount} each`, tone = "good" }
	elseif kind == "AdvanceTo" then
		return { text = `→ {Tiles.at(effect.position :: number).name}`, tone = "neutral" }
	elseif kind == "AdvanceToNearest" then
		local nouns = KIND_NOUNS[effect.tileKind :: string]
		local college = card.id:sub(1, #COLLEGE_PREFIX) == COLLEGE_PREFIX
		local noun = if nouns then (if college then nouns.college else nouns.classic) else "stop"
		return { text = `→ Nearest {noun}`, tone = "neutral" }
	elseif kind == "GoBack" then
		return { text = `← {effect.spaces} spaces`, tone = "neutral" }
	elseif kind == "GoToJail" then
		return { text = `Go to {Tiles.at(JAIL_POSITION).name}`, tone = "bad" }
	elseif kind == "JailFree" then
		return { text = "Keep this card", tone = "good" }
	elseif kind == "Repairs" then
		return { text = `−${effect.perHouse} per house · −${effect.perHotel} per hotel`, tone = "bad" }
	end
	return { text = "", tone = "neutral" }
end

function CardFace.of(cardId: string, drawer: string): Face?
	local card = Cards.byId[cardId]
	if not card then
		return nil
	end
	return {
		id = card.id,
		deck = card.deck,
		title = Cards.titleFor(card.id) or card.deck,
		drawer = drawer,
		caption = `{drawer} drew`,
		mark = "?",
		text = card.text,
		badge = badge(card),
	}
end

local GO_POSITION = 0
local GO_TO_JAIL_POSITION = 30

-- The card everyone is shown when a player is sent to jail (other than by a drawn card, which has
-- already said so): who, and why.
function CardFace.jail(player: string, reason: string): Face
	local jail = Tiles.at(JAIL_POSITION).name
	local text
	if reason == "Doubles" then
		text = "Rolled doubles three times in a row."
	elseif reason == "GoToJail" then
		text = `Landed on {Tiles.at(GO_TO_JAIL_POSITION).name}.`
	elseif reason == "Card" then
		text = "Sent there by a card."
	else
		text = `Do not pass {Tiles.at(GO_POSITION).name}, do not collect $200.`
	end
	return {
		id = "jail",
		deck = "Jail",
		title = `Go to {jail}`,
		drawer = player,
		caption = player,
		mark = "!",
		text = text,
		badge = { text = `Sent to {jail}`, tone = "bad" },
	}
end

return CardFace
