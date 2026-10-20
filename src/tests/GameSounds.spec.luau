--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local GameSounds = require(StarterPlayer.StarterPlayerScripts.Client.GameSounds)
local SoundSheet = require(StarterPlayer.StarterPlayerScripts.Client.SoundSheet)
local Sounds = require(StarterPlayer.StarterPlayerScripts.Client.Sounds)
local Expect = require(script.Parent.Expect)

local tests = {}

local function names(cues: { GameSounds.Cue }): string
	local list = {}
	for _, cue in cues do
		table.insert(list, cue.name)
	end
	return table.concat(list, ",")
end

tests["dice roll, and doubles ring once the dice settle"] = function()
	Expect.equal(names(GameSounds.forEvent({ type = "Rolled", player = "me", dice = { 2, 5 } }, "me")), "Dice")
	local cues = GameSounds.forEvent({ type = "Rolled", player = "me", dice = { 4, 4 } }, "me")
	Expect.equal(names(cues), "Dice,Doubles")
	Expect.equal((cues[2].delay or 0) > 0, true, "after they land")
	Expect.equal(names(GameSounds.forEvent({ type = "Rolled", player = "me", dice = { 4, 4 }, forCard = true }, "me")), "", "a card's roll is silent")
end

tests["money sounds follow whose money it is"] = function()
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = "you", to = "me", amount = 50, reason = "Rent" }, "me")), "Coins")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = "me", to = "you", amount = 50, reason = "Rent" }, "me")), "Pay")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = nil, to = "me", amount = 200, reason = "Go" }, "me")), "PassGo")
	local others = GameSounds.forEvent({ type = "Paid", from = "a", to = "b", amount = 50, reason = "Rent" }, "me")
	Expect.equal(names(others), "Coin")
	Expect.equal((others[1].volume or 1) < 1, true, "other players' money is quieter")
end

tests["the big moments each have a sound"] = function()
	Expect.equal(names(GameSounds.forEvent({ type = "GameOver", winner = "me" }, "me")), "Win")
	Expect.equal(names(GameSounds.forEvent({ type = "GameOver", winner = "you" }, "me")), "Lose")
	Expect.equal(names(GameSounds.forEvent({ type = "SentToJail", player = "you" }, "me")), "Jail")
	Expect.equal(names(GameSounds.forEvent({ type = "TurnStarted", player = "me" }, "me")), "YourTurn")
	Expect.equal(names(GameSounds.forEvent({ type = "TurnStarted", player = "you" }, "me")), "", "only your own turn chimes")
	Expect.equal(names(GameSounds.forEvent({ type = "AuctionEnded", winner = "you", amount = 10 }, "me")), "Sold")
	Expect.equal(names(GameSounds.forEvent({ type = "AuctionEnded", winner = nil, amount = 0 }, "me")), "")
	Expect.equal(names(GameSounds.forEvent({ type = "Built", player = "me", hotel = true }, "me")), "Hotel")
end

tests["every sound the game asks for exists in the sheet or the library"] = function()
	local wanted = { "Dice", "Doubles", "Coins", "Pay", "PassGo", "Coin", "Buy", "Gavel", "Sold", "Build", "Hotel", "Mortgage", "Card", "Jail",
		"Notify", "TradeDone", "Error", "Bankrupt", "Win", "Lose", "YourTurn", "Hop", "Click", "Hover", "Open", "Close", "Tab", "Equip", "Claim",
		"ChestShake", "ChestOpen", "RevealCommon", "RevealRare", "RevealEpic", "RevealLegendary", "SpinTick", "SpinDing" }
	for _, name in wanted do
		Expect.equal(SoundSheet[name] ~= nil or Sounds.LIBRARY[name] ~= nil, true, name)
	end
end

return tests
