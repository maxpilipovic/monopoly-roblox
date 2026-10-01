--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local MapTestHelper = require(script.Parent.MapTestHelper)
local Expect = require(script.Parent.Expect)

local tests = {}

local function sameList(a: { number }?, b: { number }?, label: string)
	Expect.equal(a == nil, b == nil, `{label} presence`)
	if a and b then
		Expect.equal(table.concat(a, ","), table.concat(b, ","), label)
	end
end

tests["College tiles mirror Classic in everything but names"] = function()
	local classic = Tiles.list
	MapTestHelper.onCollege(function()
		local college = Tiles.list
		Expect.equal(#college, #classic, "count")
		for i, tile in college do
			local twin = classic[i]
			local label = `position {twin.position}`
			Expect.equal(tile.position, twin.position, label)
			Expect.equal(tile.kind, twin.kind, `{label} kind`)
			Expect.equal(tile.price, twin.price, `{label} price`)
			Expect.equal(tile.group, twin.group, `{label} group`)
			Expect.equal(tile.amount, twin.amount, `{label} amount`)
			sameList(tile.rent, twin.rent, `{label} rent`)
			assert(tile.name ~= twin.name, `{label} keeps the classic name {twin.name}`)
			Expect.equal(Tiles.at(tile.position), tile, `{label} at()`)
		end
		Expect.equal(Tiles.at(0).name, "Orientation", "Go")
		Expect.equal(Tiles.at(39).name, "Football Stadium", "Boardwalk")
		Expect.equal(Tiles.at(10).name, "Dean's Office", "Jail")
	end)
	Expect.equal(Tiles.at(39).name, "Boardwalk", "Classic is back")
end

tests["every Classic card has a College twin with the same effect, in the same order"] = function()
	local classic = {}
	for _, deck in Cards.DECKS do
		classic[deck] = Cards.idsFor(deck)
	end
	MapTestHelper.onCollege(function()
		for _, deck in Cards.DECKS do
			local ids = Cards.idsFor(deck)
			Expect.equal(#ids, #classic[deck], `{deck} size`)
			for i, id in ids do
				local twinId = classic[deck][i]
				Expect.equal(id, `college.{twinId}`, `{deck} #{i} id`)
				local card, twin = Cards.byId[id], Cards.byId[twinId]
				Expect.equal(card.deck, twin.deck, `{id} deck`)
				assert(card.text ~= twin.text, `{id} reuses the classic text`)
				for key, value in twin.effect do
					Expect.equal((card.effect :: any)[key], value, `{id} effect.{key}`)
				end
				for key in card.effect do
					assert((twin.effect :: any)[key] ~= nil, `{id} has an extra effect field {key}`)
				end
			end
		end
		Expect.equal(Cards.DECK_TITLES.Chance, "Pop Quiz")
		Expect.equal(Cards.DECK_TITLES.CommunityChest, "Student Union")
		Expect.equal(#Cards.list, 32, "active list is the college decks")
	end)
	Expect.equal(Cards.DECK_TITLES.Chance, "Chance", "Classic titles are back")
end

tests["every card id resolves whatever map is active"] = function()
	Expect.equal(Cards.byId["college.chance.go"].text, "Back to Orientation. Collect $200.", "college card on Classic")
	MapTestHelper.onCollege(function()
		Expect.equal(Cards.byId["chance.go"].text, "Advance to Go. Collect $200.", "classic card on College")
	end)
end

tests["Maps switches tiles and cards together and rejects unknown maps"] = function()
	Expect.equal(Maps.current(), "Classic")
	MapTestHelper.onCollege(function()
		Expect.equal(Maps.current(), "College")
		Expect.equal(Tiles.at(5).name, "North Campus Shuttle")
		Expect.equal(Cards.idsFor("Chance")[1], "college.chance.dividend")
	end)
	assert(not pcall(Maps.use, "Moon"), "unknown map accepted")
	Expect.equal(Maps.current(), "Classic", "a rejected map changes nothing")
end

return tests
