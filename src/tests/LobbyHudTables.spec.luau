--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.Client.Hud.LobbyHud)
local Ui = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Ui)
local Expect = require(script.Parent.Expect)

local tests = {}

local function withLobby(body: (hud: any, sent: { any }) -> ())
	local holder = Instance.new("Folder")
	local sent = {}
	local hud = LobbyHud.new(holder, {
		onLobby = function(request)
			table.insert(sent, request)
		end,
		onStore = function() end,
		onProgress = function() end,
	})
	local ok, err = pcall(body, hud, sent)
	holder:Destroy()
	if not ok then
		error(err, 0)
	end
end

local function room(tableId: number): any
	return {
		id = 7,
		name = "Ana's game",
		hostName = "Ana",
		players = 2,
		maxPlayers = 4,
		status = "Waiting",
		settings = RoomSettings.validate(nil),
		members = { { id = "1", name = "Ana" }, { id = "2", name = "Bo" } },
		ranked = false,
		tableId = tableId,
	}
end

local function findButton(root: Instance, text: string): TextButton?
	for _, child in root:GetDescendants() do
		if child:IsA("TextButton") and child.Text == text then
			return child
		end
	end
	return nil
end

local function anyText(root: Instance, needle: string): boolean
	for _, child in root:GetDescendants() do
		if child:IsA("TextLabel") and child.Text:find(needle, 1, true) then
			return true
		end
	end
	return false
end

tests["the Play panel has a Quick Play button that asks for a seat"] = function()
	withLobby(function(hud, sent)
		hud:setRooms({ rooms = {}, mine = nil })
		hud:openPanel("Games")
		local button = findButton(hud.root, "Quick Play")
		assert(button, "no Quick Play button")
		Ui.press(button :: TextButton)
		Expect.equal(sent[#sent].type, "QuickPlay")
	end)
end

tests["open games say which table they're at"] = function()
	withLobby(function(hud)
		hud.playTab = "Casual"
		hud:setRooms({ rooms = { room(3) }, mine = nil })
		hud:openPanel("Games")
		assert(anyText(hud.root, "Table 3"), "the room card doesn't name its table")
	end)
end

tests["your game's panel names its table, and there's no Quick Play while you're in one"] = function()
	withLobby(function(hud)
		hud:setRooms({ rooms = { room(2) }, mine = 7 })
		assert(anyText(hud.root, "Table 2"), "the room panel doesn't name its table")
		Expect.equal(findButton(hud.root, "Quick Play"), nil, "Quick Play while seated")
	end)
end

return tests
