--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CardStyle = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardStyle)
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Expect = require(script.Parent.Expect)

local tests = {}

local function distance(a: Color3, b: Color3): number
	return math.sqrt(((a.R - b.R) * 255) ^ 2 + ((a.G - b.G) * 255) ^ 2 + ((a.B - b.B) * 255) ^ 2)
end

local function colorsOf(style: CardStyle.Style): { [string]: Color3 }
	return { back = style.back, face = style.face, ink = style.ink, foil = style.foil, band = style.band, bandText = style.bandText }
end

-- Colour is the properties' language: nothing else may look like a colour group.
local function assertClearOfGroups(style: CardStyle.Style, label: string)
	for field, color in colorsOf(style) do
		for group, info in ColorGroups do
			Expect.equal(distance(color, info.color) > CardStyle.MIN_GROUP_DISTANCE, true, `{label}.{field} too close to {group}`)
		end
	end
end

tests["the jail card keeps clear of every colour group"] = function()
	assertClearOfGroups(CardStyle.deck("Jail"), "Jail")
end

tests["chance is printed on orange and community chest on yellow, like the real decks"] = function()
	local chance, chest = CardStyle.deck("Chance"), CardStyle.deck("CommunityChest")
	Expect.equal(chance.face, CardStyle.CHANCE_ORANGE)
	Expect.equal(chest.face, CardStyle.CHEST_YELLOW)
	Expect.equal(chance.ink, CardStyle.INK, "black ink")
	Expect.equal(chest.ink, CardStyle.INK, "black ink")
end

tests["railroad and utility deeds keep clear of every colour group"] = function()
	assertClearOfGroups(CardStyle.deed("Railroad", nil, 5), "Railroad")
	assertClearOfGroups(CardStyle.deed("Utility", nil, 12), "Electric")
	assertClearOfGroups(CardStyle.deed("Utility", nil, 28), "Water")
end

tests["a property deed's band is its colour group"] = function()
	local style = CardStyle.deed("Property", ColorGroups.Orange.color, 16)
	Expect.equal(style.band, ColorGroups.Orange.color)
	Expect.equal(style.emblem, nil, "properties carry their colour, not an emblem")
end

tests["each card names its emblem"] = function()
	Expect.equal(CardStyle.deck("Chance").emblem, "Question")
	Expect.equal(CardStyle.deck("CommunityChest").emblem, "Chest")
	Expect.equal(CardStyle.deck("Jail").emblem, nil)
	Expect.equal(CardStyle.deed("Railroad", nil, 15).emblem, "Locomotive")
	Expect.equal(CardStyle.deed("Utility", nil, 12).emblem, "Bulb")
	Expect.equal(CardStyle.deed("Utility", nil, 28).emblem, "Tap")
end

tests["chance and community chest look different"] = function()
	local chance, chest = CardStyle.deck("Chance"), CardStyle.deck("CommunityChest")
	Expect.equal(distance(chance.back, chest.back) > 10, true, "backs differ")
	Expect.equal(chance.emblem ~= chest.emblem, true, "emblems differ")
end

tests["an unknown deck falls back to a plain style"] = function()
	local style = CardStyle.deck("Mystery")
	assertClearOfGroups(style, "Mystery")
end

return tests
