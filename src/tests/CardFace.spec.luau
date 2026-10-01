--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local CardFace = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardFace)
local MapTestHelper = require(script.Parent.MapTestHelper)
local Expect = require(script.Parent.Expect)

local tests = {}

local function badge(cardId: string): string
	local face = CardFace.of(cardId, "Ana")
	assert(face, `no face for {cardId}`)
	return `{face.badge.text} [{face.badge.tone}]`
end

tests["a face carries the card's deck, title, text and who drew it"] = function()
	local face = CardFace.of("chance.dividend", "Ana") :: CardFace.Face
	Expect.equal(face.id, "chance.dividend")
	Expect.equal(face.deck, "Chance")
	Expect.equal(face.title, "Chance")
	Expect.equal(face.drawer, "Ana")
	Expect.equal(face.text, "Bank pays you a dividend of $50.")
	Expect.equal(CardFace.of("chest.go", "Bot 1").title, "Community Chest")
	Expect.equal(CardFace.of("nope", "Ana"), nil, "unknown card")
end

tests["the badge says what the card does, and whether that's good"] = function()
	Expect.equal(badge("chance.dividend"), "+$50 [good]", "collect")
	Expect.equal(badge("chance.speeding"), "−$15 [bad]", "pay")
	Expect.equal(badge("chance.chairman"), "−$50 each [bad]", "pay each player")
	Expect.equal(badge("chest.birthday"), "+$10 each [good]", "collect from each player")
	Expect.equal(badge("chance.boardwalk"), "→ Boardwalk [neutral]", "advance to a tile")
	Expect.equal(badge("chance.go"), "→ Go [neutral]", "advance to Go")
	Expect.equal(badge("chance.railroad1"), "→ Nearest railroad [neutral]", "nearest railroad")
	Expect.equal(badge("chance.utility"), "→ Nearest utility [neutral]", "nearest utility")
	Expect.equal(badge("chance.back3"), "← 3 spaces [neutral]", "go back")
	Expect.equal(badge("chance.jail"), "Go to Jail [bad]", "jail")
	Expect.equal(badge("chest.jailFree"), "Keep this card [good]", "jail free")
	Expect.equal(badge("chance.repairs"), "−$25 per house · −$100 per hotel [bad]", "repairs")
end

tests["college cards use the college board's words"] = function()
	MapTestHelper.onCollege(function()
		Expect.equal(badge("college.chance.jail"), "Go to Dean's Office [bad]")
		Expect.equal(badge("college.chance.railroad1"), "→ Nearest shuttle [neutral]")
		Expect.equal(badge("college.chance.boardwalk"), "→ Football Stadium [neutral]")
		Expect.equal((CardFace.of("college.chance.go", "Ana") :: CardFace.Face).title, "Pop Quiz")
	end)
end

tests["a card keeps its own deck title whatever map is active"] = function()
	Expect.equal((CardFace.of("college.chest.go", "Ana") :: CardFace.Face).title, "Student Union", "college card on Classic")
	MapTestHelper.onCollege(function()
		Expect.equal((CardFace.of("chance.go", "Ana") :: CardFace.Face).title, "Chance", "classic card on College")
	end)
end

return tests
