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

tests["ranked wins build a streak; a loss ends it; the best streak and peak stay"] = function()
	local profile = Profile.new()
	Profile.recordGame(profile, true, 16, true)
	Profile.recordGame(profile, true, 12, true)
	Profile.recordGame(profile, true, 10, true)
	Expect.equal(profile.stats.streak, 3)
	Expect.equal(profile.stats.bestStreak, 3)
	Profile.recordGame(profile, false, -8, true)
	Expect.equal(profile.stats.streak, 0)
	Expect.equal(profile.stats.bestStreak, 3)
	Expect.equal(profile.stats.rankedWins, 3)
	Expect.equal(profile.stats.rankedGames, 4)
	Expect.equal(profile.stats.wins, 3, "all wins")
	Expect.equal(profile.stats.games, 4)
	Expect.equal(profile.stats.elo, 1000 + 16 + 12 + 10 - 8)
	Expect.equal(profile.stats.peakElo, 1038)
end

tests["casual games count as games and wins but never touch rating or the ranked streak"] = function()
	local profile = Profile.new()
	Profile.recordGame(profile, true, 16, true)
	Profile.recordGame(profile, true, 0, false)
	Profile.recordGame(profile, false, 0, false)
	Expect.equal(profile.stats.elo, 1016)
	Expect.equal(profile.stats.streak, 1, "a casual loss doesn't end a ranked streak")
	Expect.equal(profile.stats.rankedGames, 1)
	Expect.equal(profile.stats.games, 3)
	Expect.equal(profile.stats.wins, 2)
end

tests["Elo never drops below its floor"] = function()
	local profile = Profile.new()
	profile.stats.elo = 110
	Profile.recordGame(profile, false, -50, true)
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

tests["items the catalogue no longer knows are kept, not wiped"] = function()
	local profile = Profile.reconcile({ inventory = { Crown = 1, RetiredThing = 2 } })
	Expect.equal(profile.inventory.Crown, 1)
	Expect.equal(profile.inventory.RetiredThing, nil, "not offered as owned")
	Expect.equal(profile.retired.RetiredThing, 2, "but kept for the save")
	Expect.equal(Profile.reconcile(profile).retired.RetiredThing, 2, "and kept again on the next load")
end

return tests
