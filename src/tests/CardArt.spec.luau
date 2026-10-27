--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CardArt = require(StarterPlayer.StarterPlayerScripts.Client.Hud.CardArt)
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Expect = require(script.Parent.Expect)

local tests = {}

local function isAsset(image: string?): boolean
	return image ~= nil and image:match("^rbxassetid://%d+$") ~= nil
end

tests["every card on every map has a picture"] = function()
	for id in Cards.byId do
		assert(isAsset(CardArt.forCard(id)), `{id} has no picture`)
	end
	assert(isAsset(CardArt.forCard("jail")), "the jail card has no picture")
end

tests["college cards share their classic card's picture"] = function()
	Expect.equal(CardArt.forCard("college.chest.birthday"), CardArt.forCard("chest.birthday"))
	Expect.equal(CardArt.forCard("chest.birthday"), CardArt.IMAGES.Cake)
end

tests["EIU cards share their classic card's picture"] = function()
	Expect.equal(CardArt.forCard("college.chest.birthday"), CardArt.forCard("chest.birthday"))
end

tests["EIU cards with a picture of their own use it"] = function()
	Expect.equal(CardArt.forCard("college.chance.jail"), CardArt.IMAGES.Handcuffs)
	Expect.equal(CardArt.forCard("college.crazy.ghost"), CardArt.IMAGES.Ghost)
	Expect.equal(CardArt.forCard("college.chance.boardwalk"), CardArt.IMAGES.OldMain)
	Expect.equal(CardArt.forCard("college.chest.inherit"), CardArt.IMAGES.CarePackage)
	Expect.equal(CardArt.forCard("college.chance.reading"), CardArt.IMAGES.NeonSign)
	Expect.equal(CardArt.forCard("chance.jail"), CardArt.IMAGES.Officer, "classic keeps its own")
end

tests["each deck has its picture on the back"] = function()
	Expect.equal(CardArt.back("Chance"), CardArt.IMAGES.Question)
	Expect.equal(CardArt.back("CommunityChest"), CardArt.IMAGES.Chest)
	assert(isAsset(CardArt.back("Jail")), "jail back")
end

tests["an unknown card has no picture"] = function()
	Expect.equal(CardArt.forCard("nope"), nil)
end

return tests
