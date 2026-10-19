--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["nothing given means the defaults"] = function()
	local settings = RoomSettings.validate(nil)
	Expect.equal(settings.maxPlayers, 4)
	Expect.equal(settings.startingMoney, 1500)
	Expect.equal(settings.auctions, true)
	Expect.equal(settings.freeParking, false)
	Expect.equal(settings.bots, true)
	Expect.equal(settings.timer, "Relaxed")
	Expect.equal(settings.length, "Off")
	Expect.equal(settings.map, "Classic")
end

tests["numbers are clamped and snapped to their steps"] = function()
	Expect.equal(RoomSettings.validate({ maxPlayers = 9 }).maxPlayers, 6)
	Expect.equal(RoomSettings.validate({ maxPlayers = 1 }).maxPlayers, 2)
	Expect.equal(RoomSettings.validate({ maxPlayers = 3.7 }).maxPlayers, 4)
	Expect.equal(RoomSettings.validate({ startingMoney = 100 }).startingMoney, 500)
	Expect.equal(RoomSettings.validate({ startingMoney = 99999 }).startingMoney, 5000)
	Expect.equal(RoomSettings.validate({ startingMoney = 1620 }).startingMoney, 1500, "nearest $250")
	Expect.equal(RoomSettings.validate({ startingMoney = "lots" }).startingMoney, 1500, "junk ignored")
end

tests["switches and choices only take valid values"] = function()
	local settings = RoomSettings.validate({ auctions = false, freeParking = true, bots = false, timer = "Fast", map = "College", length = "Rounds15" })
	Expect.equal(settings.auctions, false)
	Expect.equal(settings.freeParking, true)
	Expect.equal(settings.bots, false)
	Expect.equal(settings.timer, "Fast")
	Expect.equal(settings.map, "College")
	Expect.equal(settings.length, "Rounds15")
	local junk = RoomSettings.validate({ auctions = "no", timer = "Turbo", map = "Mars" })
	Expect.equal(junk.auctions, true)
	Expect.equal(junk.timer, "Relaxed")
	Expect.equal(junk.map, "Classic")
end

tests["settings split into the engine's rules and the match options"] = function()
	local settings = RoomSettings.validate({ startingMoney = 2000, auctions = false, freeParking = true, timer = "Fast" })
	local rules = RoomSettings.rules(settings)
	Expect.equal(rules.startingMoney, 2000)
	Expect.equal(rules.auctions, false)
	Expect.equal(rules.freeParking, true)
	local match = RoomSettings.match(settings)
	Expect.equal(match.timer, "Fast")
	Expect.equal(match.map, "Classic")
end

tests["the summary chips say what's special about a room"] = function()
	local chips = table.concat(RoomSettings.chips(RoomSettings.validate({ startingMoney = 2500, auctions = false, freeParking = true })), "|")
	Expect.equal(chips, "$2500|No auctions|Free Parking pot|Relaxed timer")
	local plain = table.concat(RoomSettings.chips(RoomSettings.validate(nil)), "|")
	Expect.equal(plain, "$1500|Relaxed timer")
end

tests["ranked games always use the standard rules, no bots, and a time limit"] = function()
	local duel = RoomSettings.ranked(2)
	Expect.equal(duel.maxPlayers, 2)
	Expect.equal(duel.startingMoney, 1500)
	Expect.equal(duel.auctions, true)
	Expect.equal(duel.freeParking, false)
	Expect.equal(duel.bots, false)
	Expect.equal(duel.length, "Minutes30")
	Expect.equal(RoomSettings.ranked(4).length, "Minutes60")
end

tests["the board scene is one of the three, Boardwalk by default"] = function()
	Expect.equal(RoomSettings.validate(nil).scene, "Boardwalk")
	Expect.equal(RoomSettings.validate({ scene = "Winter" }).scene, "Winter")
	Expect.equal(RoomSettings.validate({ scene = "Mars" }).scene, "Boardwalk", "junk ignored")
	Expect.equal(table.concat(RoomSettings.chips(RoomSettings.validate({ scene = "Tropical" })), "|"), "$1500|Relaxed timer|Tropical Island")
end

return tests
