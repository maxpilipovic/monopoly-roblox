--!strict
-- Receives game updates and drives the tokens and HUD; sends the local player's requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Buildings = require(script.Parent.Buildings)
local EventText = require(script.Parent.Hud.EventText)
local HudModel = require(script.Parent.Hud.HudModel)
local HudView = require(script.Parent.Hud.HudView)
local Tokens = require(script.Parent.Tokens)

local GameClient = {}

function GameClient.start()
	local localPlayer = Players.LocalPlayer
	local localId = tostring(localPlayer.UserId)
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local actionRemote = remotes:WaitForChild(Protocol.ACTION) :: RemoteEvent
	local lobbyRemote = remotes:WaitForChild(Protocol.LOBBY) :: RemoteEvent
	local updateRemote = remotes:WaitForChild(Protocol.UPDATE) :: RemoteEvent
	local readyRemote = remotes:WaitForChild(Protocol.READY) :: RemoteEvent

	local tokens = Tokens.new(workspace)
	local buildings = Buildings.new(workspace)
	local hud = HudView.new(localPlayer:WaitForChild("PlayerGui"), {
		onAction = function(action)
			actionRemote:FireServer(action)
		end,
		onStart = function(seats)
			lobbyRemote:FireServer({ type = "Start", seats = seats })
		end,
		onReturnToLobby = function()
			lobbyRemote:FireServer({ type = "ReturnToLobby" })
		end,
	})

	updateRemote.OnClientEvent:Connect(function(update: Protocol.Update)
		tokens:apply(update)
		buildings:apply(update.snapshot)
		if update.snapshot then
			local names = HudModel.names(update.snapshot)
			local lines = {}
			local now = os.clock()
			local travel = {} -- per player: seconds of token movement so far in this update
			for _, event in update.events do
				local line = EventText.describe(event, names)
				if line then
					table.insert(lines, line)
				end
				if event.type == "Moved" then
					travel[event.player] = (travel[event.player] or 0) + Tokens.moveSeconds(event)
				elseif event.type == "CardDrawn" and Cards.byId[event.card] then
					-- Show the card once the token has reached the card tile.
					hud:showCard(event.deck, Cards.byId[event.card].text, now + (travel[event.player] or 0))
				end
			end
			hud:log(lines)
		end
		hud:render(update.snapshot, localId)
	end)

	hud:render(nil, localId)
	readyRemote:FireServer()
end

return GameClient
