--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local CardArt = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardArt)
local CardFace = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardFace)
local CardStyle = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardStyle)
local EventText = require(StarterPlayer.StarterPlayerScripts.Client.Hud.EventText)
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.Client.Hud.LobbyHud)
local Expect = require(script.Parent.Expect)
local MapTestHelper = require(script.Parent.MapTestHelper)

local tests = {}

local NAMES = { p1 = "Ana", p2 = "Bot 1" }

tests["the log tells the crazy cards' story"] = function()
	local cases = {
		{ { type = "CardDrawn", player = "p1", deck = "Crazy", card = "crazy.reverse" }, "Ana drew Crazy Chance: Reverse! Play now goes the other way round the table." },
		{ { type = "DeedMoved", from = "p2", to = "p1", position = 3 }, "Bot 1's Baltic Avenue now belongs to Ana" },
		{ { type = "TurnOrderReversed", player = "p1" }, "Play now goes the other way round the table" },
		{ { type = "Demolished", player = "p1", count = 3 }, "Demolition: 3 buildings came down" },
		{ { type = "Demolished", player = "p1", count = 0 }, "Demolition: nothing was built" },
		{ { type = "Built", player = "p1", position = 3, amount = 0, hotel = false, free = true }, "Ana got a free house on Baltic Avenue" },
		{ { type = "Paid", from = nil, to = "p1", amount = 150, reason = "Lottery" }, "Ana won the $150 lottery" },
		{ { type = "Paid", from = "p2", to = "p1", amount = 200, reason = "RobinHood" }, "Robin Hood: Bot 1 paid Ana $200" },
	}
	for _, case in cases do
		Expect.equal(EventText.describe(case[1], NAMES), case[2], case[1].type)
	end
	Expect.equal(EventText.describe({ type = "Paid", from = "p1", to = nil, amount = 50, reason = "Lottery" }, NAMES), nil, "each stake isn't logged")
end

tests["crazy cards are titled Crazy Chance and badged with what they do"] = function()
	local face = CardFace.of("crazy.heist", "Ana") :: CardFace.Face
	Expect.equal(face.title, "Crazy Chance")
	Expect.equal(face.deck, "Crazy")
	Expect.equal(face.badge.text, "Steal a property")
	Expect.equal((CardFace.of("crazy.reverse", "Ana") :: CardFace.Face).badge.text, "Turn order reversed")
	Expect.equal((CardFace.of("crazy.jackpot", "Ana") :: CardFace.Face).badge.text, "+$500")
	for _, id in { "crazy.swapLeader", "crazy.scatter", "crazy.extraTurn", "crazy.robinHood", "crazy.lottery", "crazy.splitCash", "crazy.swapDeed", "crazy.freeHouse", "crazy.demolition", "crazy.massArrest", "crazy.jailbreak" } do
		assert((CardFace.of(id, "Ana") :: CardFace.Face).badge.text ~= "", `{id} has no badge`)
	end
end

tests["crazy cards are purple and have their own back"] = function()
	local crazy = CardStyle.deck("Crazy")
	assert(crazy.face ~= CardStyle.deck("Chance").face and crazy.face ~= CardStyle.deck("CommunityChest").face, "looks like another deck")
	Expect.equal(crazy.face, CardStyle.CRAZY_PURPLE)
	assert(CardArt.back("Crazy"), "no back picture")
end

tests["Crazy Chance is a room setting, off by default, in the rules and on the room's chips"] = function()
	Expect.equal(RoomSettings.validate(nil).crazyChance, false)
	local on = RoomSettings.validate({ crazyChance = true })
	Expect.equal(on.crazyChance, true)
	Expect.equal(RoomSettings.rules(on).crazyChance, true)
	assert(table.find(RoomSettings.chips(on), "Crazy Chance"), "no chip")
	Expect.equal(RoomSettings.forRanked(on).crazyChance, true, "ranked hosts may turn it on")
end

tests["the room panel has a Crazy Chance switch, ranked too"] = function()
	local holder = Instance.new("Folder")
	local hud = LobbyHud.new(holder, { onLobby = function() end, onStore = function() end, onProgress = function() end })
	local function hasRow(): boolean
		for _, child in hud.root:GetDescendants() do
			if child:IsA("TextLabel") and child.Text == "Crazy Chance" then
				return true
			end
		end
		return false
	end
	local room = { id = 7, name = "Ana's game", hostName = "Ana", players = 1, maxPlayers = 4, status = "Waiting", settings = RoomSettings.validate(nil), members = { { id = "1", name = "Ana" } }, ranked = false, tableId = 1 }
	hud:setRooms({ rooms = { room }, mine = 7, hostOf = 7 })
	local casual = hasRow()
	room.ranked = true
	hud:setRooms({ rooms = { room }, mine = 7, hostOf = 7 })
	local ranked = hasRow()
	holder:Destroy()
	Expect.equal(casual, true, "casual")
	Expect.equal(ranked, true, "ranked")
end

tests["the EIU crazy cards are badged and logged"] = function()
	Expect.equal((CardFace.of("eiu.crazy.bailBuddy", "Ana") :: CardFace.Face).badge.text, "Bail out the jail — $100 each")
	Expect.equal((CardFace.of("eiu.crazy.blockParty", "Ana") :: CardFace.Face).badge.text, "Everyone on a hangout to Jail")
	Expect.equal((CardFace.of("eiu.crazy.ghost", "Ana") :: CardFace.Face).title, "Crazy Night")
	Expect.equal(EventText.describe({ type = "RaidFoundNobody", player = "p1" }, NAMES), "Ana's raid found nobody")
end

tests["EIU Care Package cards carry the care package; bail-outs are logged as bail"] = function()
	MapTestHelper.onMap("EIU", function()
		Expect.equal(CardStyle.deck("CommunityChest").emblem, "CarePackage")
	end)
	Expect.equal(CardStyle.deck("CommunityChest").emblem, "Chest", "Classic keeps the chest")
	Expect.equal(EventText.describe({ type = "LeftJail", player = "p2", reason = "Bail" }, NAMES), "Bot 1 was bailed out")
	Expect.equal(EventText.describe({ type = "Paid", from = "p1", to = nil, amount = 100, reason = "Bail" }, NAMES), "Ana paid $100 bail")
end

return tests
