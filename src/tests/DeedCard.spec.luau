--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local DeedCard = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Views.DeedCard)
local DeedModel = require(StarterPlayer.StarterPlayerScripts.Client.Hud.DeedModel)
local Expect = require(script.Parent.Expect)

local tests = {}

-- The emblem's turning loop holds views weakly, so the card itself must keep its emblem.
tests["a railroad deed keeps hold of its emblem; a property deed has none"] = function()
	local holder = Instance.new("Folder")
	local card = DeedCard.new(holder, function() end)
	card:render(DeedModel.of(5, nil), nil, false)
	Expect.equal(card.emblem ~= nil, true, "railroad emblem kept")
	Expect.equal((card.emblem :: any).frame.Parent, card.frame, "shown on the card")
	card:render(DeedModel.of(1, nil), nil, false)
	Expect.equal(card.emblem, nil, "property: none")
	holder:Destroy()
end

return tests
