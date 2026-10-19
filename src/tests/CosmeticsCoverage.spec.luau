--!strict
-- Every effect the catalogue promises exists in code, and every piece has a finish.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local PieceLook = require(ReplicatedStorage.Shared.Cosmetics.PieceLook)
local PieceEffects = require(StarterPlayer.StarterPlayerScripts.Client.PieceEffects)
local RentEffects = require(StarterPlayer.StarterPlayerScripts.Client.RentEffects)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["every piece's effect and every rent effect is built in code"] = function()
	for _, item in Catalog.ITEMS do
		if item.kind == "Piece" and item.effect then
			Expect.equal(table.find(PieceEffects.IDS, item.effect) ~= nil, true, `{item.id}: no {item.effect} effect`)
		elseif item.kind == "RentEffect" then
			Expect.equal(table.find(RentEffects.IDS, item.id) ~= nil, true, `no rent effect {item.id}`)
		end
	end
end

tests["every piece has a finish for its body"] = function()
	for _, item in Catalog.ITEMS do
		if item.kind == "Piece" then
			local finish = PieceLook.FINISHES[item.id]
			Expect.equal(finish ~= nil and finish.Body ~= nil, true, `{item.id} finish`)
		end
	end
end

tests["every piece and the cash bundle have an uploaded model"] = function()
	local AssetIds = require(ReplicatedStorage.Shared.Cosmetics.AssetIds)
	for _, item in Catalog.ITEMS do
		if item.kind == "Piece" then
			Expect.equal(AssetIds.Pieces ~= nil and AssetIds.Pieces[item.id] ~= nil, true, `{item.id} model`)
		end
	end
	Expect.equal(AssetIds.Props ~= nil and AssetIds.Props.CashStack ~= nil, true, "cash bundle")
end

return tests
