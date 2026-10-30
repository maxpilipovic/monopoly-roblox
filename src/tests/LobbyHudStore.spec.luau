--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.Client.Hud.LobbyHud)
local Ui = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Ui)
local CoinPacks = require(ReplicatedStorage.Shared.Store.CoinPacks)
local Expect = require(script.Parent.Expect)

local tests = {}

local function withLobby(body: (hud: any, sent: { any }) -> ())
	local holder = Instance.new("Folder")
	local sent = {}
	local hud = LobbyHud.new(holder, {
		onLobby = function() end,
		onStore = function(request)
			table.insert(sent, request)
		end,
		onProgress = function() end,
	})
	local ok, err = pcall(body, hud, sent)
	holder:Destroy()
	if not ok then
		error(err, 0)
	end
end

local function texts(root: Instance): { string }
	local out = {}
	for _, child in root:GetDescendants() do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(out, child.Text)
		end
	end
	return out
end

local function has(list: { string }, needle: string): boolean
	for _, text in list do
		if text:find(needle, 1, true) then
			return true
		end
	end
	return false
end

tests["chests have no Robux button: coins or keys open them"] = function()
	withLobby(function(hud)
		hud:openPanel("Chests")
		local shown = texts(hud.panels.Chests)
		Expect.equal(has(shown, "R$"), false, "no Robux price on a chest")
		Expect.equal(has(shown, "Test open"), false, "no Studio test open")
		Expect.equal(has(shown, "Get coins"), true, "a way to the coin shop")
	end)
end

tests["the coin shop lists every pack, and its button buys it (a test buy while the product id is unset)"] = function()
	withLobby(function(hud, sent)
		hud:openPanel("Coins")
		local shown = texts(hud.panels.Coins)
		for _, amount in { "1,000", "3,500", "10,000", "30,000" } do
			Expect.equal(has(shown, amount), true, `{amount} coins pack`)
		end
		Expect.equal(has(shown, "challenges"), true, "says coins are also earned")
		local button: TextButton? = nil
		for _, child in hud.panels.Coins:GetDescendants() do
			if child:IsA("TextButton") and child.Parent and child.Parent.Name == "Pouch" and child.Name == "Buy" then
				button = child
			end
		end
		assert(button, "no Buy button on the Pouch")
		Ui.press(button :: TextButton)
		local live = CoinPacks.byId.Pouch.productId ~= 0
		Expect.equal(sent[1] and sent[1].type, if live then "BuyCoins" else "TestBuyCoins", "buy request")
		Expect.equal(sent[1] and sent[1].pack, "Pouch")
	end)
end

return tests
