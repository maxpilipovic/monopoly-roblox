--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Profile = require(ServerScriptService.Server.Data.Profile)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["a new profile starts at 1000 Elo with the top hat on"] = function()
	local profile = Profile.new()
	Expect.equal(profile.stats.elo, 1000)
	Expect.equal(profile.stats.wins, 0)
	Expect.equal(profile.equipped.piece, "TopHat")
	Expect.equal(profile.equipped.rentEffect, nil)
	Expect.equal(Profile.owns(profile, "Battleship"), true, "the defaults are everyone's")
	Expect.equal(Profile.owns(profile, "Crown"), false)
end

tests["an old or partial save is filled out without losing what it had"] = function()
	local profile = Profile.reconcile({ stats = { wins = 7 }, inventory = { Crown = 1 } })
	Expect.equal(profile.stats.wins, 7)
	Expect.equal(profile.stats.elo, 1000)
	Expect.equal(profile.inventory.Crown, 1)
	Expect.equal(profile.equipped.piece, "TopHat")
	Expect.equal(Profile.reconcile("garbage").stats.elo, 1000, "junk becomes a fresh profile")
end

tests["wins build a streak; a loss ends it; the best streak stays"] = function()
	local profile = Profile.new()
	Profile.recordGame(profile, true, 16)
	Profile.recordGame(profile, true, 12)
	Profile.recordGame(profile, true, 10)
	Expect.equal(profile.stats.streak, 3)
	Expect.equal(profile.stats.bestStreak, 3)
	Profile.recordGame(profile, false, -8)
	Expect.equal(profile.stats.streak, 0)
	Expect.equal(profile.stats.bestStreak, 3)
	Expect.equal(profile.stats.wins, 3)
	Expect.equal(profile.stats.games, 4)
	Expect.equal(profile.stats.elo, 1000 + 16 + 12 + 10 - 8)
end

tests["Elo never drops below its floor"] = function()
	local profile = Profile.new()
	profile.stats.elo = 110
	Profile.recordGame(profile, false, -50)
	Expect.equal(profile.stats.elo, Profile.ELO_FLOOR)
end

tests["items are granted with counts and only owned things can be equipped"] = function()
	local profile = Profile.new()
	Expect.equal((Profile.equip(profile, "Crown")), false, "not owned yet")
	Expect.equal(Profile.grant(profile, "Crown"), 1)
	Expect.equal(Profile.grant(profile, "Crown"), 2, "a duplicate counts")
	Expect.equal((Profile.equip(profile, "Crown")), true)
	Expect.equal(profile.equipped.piece, "Crown")
	Profile.grant(profile, "Lightning")
	Expect.equal((Profile.equip(profile, "Lightning")), true)
	Expect.equal(profile.equipped.rentEffect, "Lightning", "a rent effect goes in its own slot")
	Expect.equal(profile.equipped.piece, "Crown")
	Expect.equal((Profile.equip(profile, "Battleship")), true, "defaults always")
	Expect.equal((Profile.equip(profile, "NoSuchThing")), false)
	Profile.unequipRentEffect(profile)
	Expect.equal(profile.equipped.rentEffect, nil)
end

tests["a purchase is remembered so it's never granted twice, keeping the last 50"] = function()
	local profile = Profile.new()
	Expect.equal(Profile.hasReceipt(profile, "p1"), false)
	Profile.addReceipt(profile, "p1")
	Expect.equal(Profile.hasReceipt(profile, "p1"), true)
	for i = 2, 60 do
		Profile.addReceipt(profile, `p{i}`)
	end
	Expect.equal(#profile.receipts, 50)
	Expect.equal(Profile.hasReceipt(profile, "p1"), false, "the oldest drop off")
	Expect.equal(Profile.hasReceipt(profile, "p60"), true)
end

return tests
