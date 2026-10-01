--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Expect = require(script.Parent.Expect)

local tests = {}

local KINDS = {
	Collect = true,
	Pay = true,
	PayEachPlayer = true,
	CollectFromEachPlayer = true,
	AdvanceTo = true,
	AdvanceToNearest = true,
	GoBack = true,
	GoToJail = true,
	JailFree = true,
	Repairs = true,
}

tests["each deck has 16 cards with unique ids and one Get Out of Jail Free"] = function()
	for _, deck in Cards.DECKS do
		local ids = Cards.idsFor(deck)
		Expect.equal(#ids, 16, `{deck} size`)
		local jailFree = 0
		for _, id in ids do
			Expect.equal(Cards.byId[id].deck, deck, `{id} deck`)
			if Cards.byId[id].effect.kind == "JailFree" then
				jailFree += 1
			end
		end
		Expect.equal(jailFree, 1, `{deck} jail cards`)
	end
	local seen = {}
	for _, card in Cards.list do
		assert(not seen[card.id], `duplicate id {card.id}`)
		seen[card.id] = true
	end
	Expect.equal(#Cards.list, 32, "total")
end

tests["every effect is well formed"] = function()
	for _, card in Cards.list do
		local effect = card.effect
		assert(KINDS[effect.kind], `{card.id}: unknown kind {effect.kind}`)
		assert(card.text ~= "", `{card.id}: no text`)
		if effect.kind == "AdvanceTo" then
			Tiles.at(effect.position :: number) -- errors on a bad position
		elseif effect.kind == "AdvanceToNearest" then
			assert(effect.tileKind == "Railroad" or effect.tileKind == "Utility", `{card.id}: tileKind`)
		elseif effect.kind == "Repairs" then
			assert(effect.perHouse and effect.perHotel, `{card.id}: repair costs`)
		elseif effect.kind == "GoBack" then
			assert(effect.spaces, `{card.id}: spaces`)
		elseif effect.kind ~= "GoToJail" and effect.kind ~= "JailFree" then
			assert(effect.amount and effect.amount > 0, `{card.id}: amount`)
		end
	end
end

-- Other specs roll onto Chance/Community Chest with unshuffled decks and expect nothing but money to change.
tests["unshuffled decks start with money-only cards"] = function()
	local chance = Cards.idsFor("Chance")
	for i = 1, 3 do
		local kind = Cards.byId[chance[i]].effect.kind
		assert(kind == "Collect" or kind == "Pay", `Chance card {i} is {kind}`)
	end
	Expect.equal(Cards.byId[Cards.idsFor("CommunityChest")[1]].effect.kind, "Collect", "first Community Chest card")
end

tests["idsFor returns a fresh list each time"] = function()
	local ids = Cards.idsFor("Chance")
	ids[1] = "tampered"
	assert(Cards.idsFor("Chance")[1] ~= "tampered", "shared list")
	Expect.equal(Cards.DECK_TITLES.CommunityChest, "Community Chest")
end

tests["a card's deck title comes from its own map"] = function()
	Expect.equal(Cards.titleFor("chance.go"), "Chance")
	Expect.equal(Cards.titleFor("chest.go"), "Community Chest")
	Expect.equal(Cards.titleFor("college.chance.go"), "Pop Quiz")
	Expect.equal(Cards.titleFor("college.chest.go"), "Student Union")
	Expect.equal(Cards.titleFor("nope"), nil)
	Cards.use("College")
	local classicOnCollege = Cards.titleFor("chance.go")
	Cards.use("Classic")
	Expect.equal(classicOnCollege, "Chance", "whatever map is active")
end

return tests
