--!strict
-- How each kind of card looks. Chance and Community Chest cards are printed like the real decks
-- (orange and yellow stock, black ink). Among the deeds colour is the properties' language, so only
-- a property deed is coloured (by its group); railroads and utilities are midnight or charcoal on
-- parchment, told apart by their emblem and lit by a thin gold foil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Style = {
	back: Color3, -- the face-down side
	face: Color3, -- the paper
	ink: Color3, -- text on the paper
	foil: Color3, -- thin accent lines and the deck name
	band: Color3, -- the header band
	bandText: Color3,
	emblem: string?, -- a shape under ReplicatedStorage.Assets.Emblems
}

local CardStyle = {}

-- How far (RGB, 0-255) a non-property colour must stay from every colour group's.
CardStyle.MIN_GROUP_DISTANCE = 60

CardStyle.MIDNIGHT = Color3.fromRGB(18, 22, 38)
CardStyle.CHARCOAL = Color3.fromRGB(34, 34, 38)
CardStyle.STEEL = Color3.fromRGB(70, 76, 86)
CardStyle.PARCHMENT = Color3.fromRGB(251, 246, 233)
CardStyle.INK = Color3.fromRGB(27, 31, 42)
CardStyle.GOLD = Color3.fromRGB(222, 190, 110)

local function plain(band: Color3, emblem: string?): Style
	return {
		back = band,
		face = CardStyle.PARCHMENT,
		ink = CardStyle.INK,
		foil = CardStyle.GOLD,
		band = band,
		bandText = CardStyle.GOLD,
		emblem = emblem,
	}
end

-- Chance and Community Chest look like the real decks: orange and yellow card stock printed in ink.
CardStyle.CHANCE_ORANGE = Color3.fromRGB(245, 140, 44)
CardStyle.CHEST_YELLOW = Color3.fromRGB(252, 222, 112)
CardStyle.JAIL_GREY = Color3.fromRGB(200, 200, 196) -- warm, to stay off the light blue group
CardStyle.CRAZY_PURPLE = Color3.fromRGB(200, 168, 255) -- Crazy Chance: lavender stock
CardStyle.CRAZY_BACK = Color3.fromRGB(96, 40, 170) -- and a deep purple back

local function printed(stock: Color3, back: Color3, emblem: string?): Style
	return {
		back = back,
		face = stock,
		ink = CardStyle.INK,
		foil = CardStyle.INK,
		band = stock,
		bandText = CardStyle.INK,
		emblem = emblem,
	}
end

local DECKS: { [string]: Style } = {
	Chance = printed(CardStyle.CHANCE_ORANGE, CardStyle.CHANCE_ORANGE, "Question"),
	CommunityChest = printed(CardStyle.CHEST_YELLOW, CardStyle.CHEST_YELLOW, "Chest"),
	Crazy = printed(CardStyle.CRAZY_PURPLE, CardStyle.CRAZY_BACK, nil),
	-- Steel on the back keeps the jail pill (PlayerList) off the property reds.
	Jail = printed(CardStyle.JAIL_GREY, CardStyle.STEEL, nil),
}

-- The EIU map's Care Package cards carry a cardboard box instead of the chest.
local EIU_CHEST = printed(CardStyle.CHEST_YELLOW, CardStyle.CHEST_YELLOW, "CarePackage")

function CardStyle.deck(deck: string): Style
	if deck == "CommunityChest" and Maps.current() == "EIU" then
		return EIU_CHEST
	end
	return DECKS[deck] or plain(CardStyle.CHARCOAL, nil)
end

-- Dark text on light bands (yellow, light blue), white on the rest.
local function readableOn(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then CardStyle.INK else Color3.new(1, 1, 1)
end

function CardStyle.deed(kind: string, groupColor: Color3?, position: number): Style
	if kind == "Property" and groupColor then
		local style = plain(groupColor, nil)
		style.bandText = readableOn(groupColor)
		return style
	end
	local band = if kind == "Railroad" then CardStyle.MIDNIGHT else CardStyle.CHARCOAL
	return plain(band, EmblemLook.forTile(Tiles.at(position)))
end

return CardStyle
