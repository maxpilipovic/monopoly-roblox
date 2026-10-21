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

tests["dice roll; doubles make no extra sound"] = function()
	Expect.equal(names(GameSounds.forEvent({ type = "Rolled", player = "me", dice = { 2, 5 } }, "me")), "Dice")
	Expect.equal(names(GameSounds.forEvent({ type = "Rolled", player = "me", dice = { 4, 4 } }, "me")), "Dice")
	Expect.equal(names(GameSounds.forEvent({ type = "Rolled", player = "me", dice = { 4, 4 }, forCard = true }, "me")), "", "a card's roll is silent")
end

tests["every money change and every trade rings the register, unless a rent effect takes over"] = function()
	local rent = { type = "Paid", from = "you", to = "me", amount = 50, reason = "Rent" }
	Expect.equal(names(GameSounds.forEvent(rent, "me")), "Register", "rent, no effect")
	Expect.equal(names(GameSounds.forEvent(rent, "me", { me = "Lightning" })), "", "the owner's rent effect takes over")
	Expect.equal(names(GameSounds.forEvent(rent, "me", { you = "Lightning" })), "Register", "only the owner's effect counts")
	Expect.equal(names(GameSounds.forEvent({ type = "TradeAccepted", from = "me", to = "you" }, "me")), "Register", "a trade")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = nil, to = "me", amount = 30, reason = "Mortgage" }, "me")), "Register", "mortgaging")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = nil, to = "me", amount = 300, reason = "FreeParking" }, "me")), "Register", "the pot")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = "me", to = nil, amount = 100, reason = "Tax" }, "me")), "Register", "income tax")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = "me", to = nil, amount = 50, reason = "JailFine" }, "me")), "Register", "a fine")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = nil, to = "me", amount = 50, reason = "Card" }, "me")), "Register", "money in")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = nil, to = "me", amount = 200, reason = "Go" }, "me")), "Register", "passing GO")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = "a", to = "b", amount = 50, reason = "Rent" }, "me", { b = "Fireworks" })), "")
	local others = GameSounds.forEvent({ type = "Paid", from = "a", to = nil, amount = 100, reason = "Tax" }, "me")
	Expect.equal(names(others), "Register")
	Expect.equal((others[1].volume or 1) < 1, true, "other players' money rings quieter")
end

tests["the big moments each have a sound"] = function()
	Expect.equal(names(GameSounds.forEvent({ type = "GameOver", winner = "me" }, "me")), "Win")
	Expect.equal(names(GameSounds.forEvent({ type = "GameOver", winner = "you" }, "me")), "Lose")
	Expect.equal(names(GameSounds.forEvent({ type = "SentToJail", player = "you" }, "me")), "Jail")
	Expect.equal(names(GameSounds.forEvent({ type = "TurnStarted", player = "me" }, "me")), "", "no chime for your turn")
	Expect.equal(names(GameSounds.forEvent({ type = "AuctionEnded", winner = "you", amount = 10 }, "me")), "Sold")
	Expect.equal(names(GameSounds.forEvent({ type = "AuctionEnded", winner = nil, amount = 0 }, "me")), "")
	Expect.equal(names(GameSounds.forEvent({ type = "Built", player = "me", hotel = true }, "me")), "Hotel")
	Expect.equal(names(GameSounds.forEvent({ type = "AuctionStarted", position = 1, bidders = {} }, "me")), "Gavel")
	Expect.equal(names(GameSounds.forEvent({ type = "Paid", from = "me", to = nil, amount = 60, reason = "Purchase" }, "me")), "Register", "buying is a cha-ching (from its payment)")
	Expect.equal(names(GameSounds.forEvent({ type = "Bought", player = "me", position = 1, price = 60 }, "me")), "", "and only once: the Bought event itself is quiet")
	Expect.equal(names(GameSounds.forEvent({ type = "LeftJail", player = "me", reason = "Doubles" }, "me")), "Unlock")
	Expect.equal(names(GameSounds.forEvent({ type = "DebtOwed", debtor = "me", amount = 50 }, "me")), "Alert", "you owe more than you have")
	Expect.equal(names(GameSounds.forEvent({ type = "OfferedPurchase", player = "me", position = 1 }, "me")), "Notify")
end

tests["every sound the game asks for exists in the sheet or the library"] = function()
	local wanted = { "Dice", "Coins", "Pay", "PassGo", "Coin", "Buy", "Gavel", "Sold", "Build", "Hotel", "Mortgage", "Card", "Jail",
		"Notify", "TradeDone", "Error", "Bankrupt", "Win", "Lose", "Click", "Hover", "Open", "Close", "Tab", "Equip", "Claim",
		"ChestShake", "ChestOpen", "RevealCommon", "RevealRare", "RevealEpic", "RevealLegendary", "SpinTick", "SpinDing",
		"Unlock", "Alert", "Pop", "Thunder", "Firework", "Warp", "Tick", "Register" }
	for _, name in wanted do
		Expect.equal(SoundSheet[name] ~= nil or Sounds.LIBRARY[name] ~= nil, true, name)
	end
end

tests["one cash register ring per moment, however many payments land together"] = function()
	local scheduled = {}
	local ring = { name = "Register" }
	Expect.equal(GameSounds.keep(ring, 10, scheduled), true, "the first rings")
	Expect.equal(GameSounds.keep(ring, 10.1, scheduled), false, "a second at the same moment doesn't")
	Expect.equal(GameSounds.keep(ring, 11, scheduled), true, "a later one does")
	Expect.equal(GameSounds.keep({ name = "Gavel" }, 10, scheduled), true, "other sounds aren't affected")
end

tests["every engine event either makes a sound or is deliberately quiet"] = function()
	-- Events that are only bookkeeping, or whose sound comes from another event at the same moment.
	local quiet = { Moved = true, DebtPaid = true, TurnOrder = true, TurnStarted = true, BidPassed = true, Paid = true,
		Bought = true, Mortgaged = true, Unmortgaged = true, BuildingSold = true, FreeParkingPaid = true } -- these ring through their payment
	for _, kind in { "Paid", "DebtOwed", "Moved", "SentToJail", "LeftJail", "CardDrawn", "Rolled", "OfferedPurchase", "FreeParkingPaid",
		"Built", "BuildingSold", "Mortgaged", "Unmortgaged", "Bought", "AuctionEnded", "AuctionStarted", "BidPlaced", "BidPassed",
		"GameOver", "TurnStarted", "DebtPaid", "WentBankrupt", "TradeProposed", "TradeAccepted", "TradeDeclined", "PurchaseDeclined",
		"TurnOrder", "PlayerReplaced" } do
		local event = { type = kind, player = "me", from = "me", to = "me", debtor = "me", winner = "me", dice = { 1, 2 }, amount = 1, reason = "Rent" }
		Expect.equal(#GameSounds.forEvent(event, "me") > 0 or quiet[kind] == true, true, `{kind} makes no sound`)
	end
	for effect, sound in Sounds.RENT_EFFECTS do
		Expect.equal(SoundSheet[sound] ~= nil, true, `rent effect {effect}`)
	end
end

return tests
