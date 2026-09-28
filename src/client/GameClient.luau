--!strict
-- Receives game updates and drives the tokens and HUD; sends the local player's requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
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
	local hud = HudView.new(localPlayer:WaitForChild("PlayerGui"), {
		onAction = function(action)
			actionRemote:FireServer(action)
		end,
		onStart = function(seats)
			lobbyRemote:FireServer({ type = "Start", seats = seats })
		end,
	})

	updateRemote.OnClientEvent:Connect(function(update: Protocol.Update)
		tokens:apply(update)
		if update.snapshot then
			local names = HudModel.names(update.snapshot)
			local lines = {}
			for _, event in update.events do
				local line = EventText.describe(event, names)
				if line then
					table.insert(lines, line)
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
