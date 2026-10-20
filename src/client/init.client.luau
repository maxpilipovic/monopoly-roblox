--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraDirector = require(script.CameraDirector)
local GameClient = require(script.GameClient)
local LobbyFx = require(script.LobbyFx)
local LobbyHud = require(script.Hud.LobbyHud)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)

local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
local lobbyRemote = remotes:WaitForChild(Protocol.LOBBY) :: RemoteEvent
local storeRemote = remotes:WaitForChild(Protocol.STORE) :: RemoteEvent
local roomsRemote = remotes:WaitForChild(Protocol.ROOMS) :: RemoteEvent
local profileRemote = remotes:WaitForChild(Protocol.PROFILE) :: RemoteEvent
local chestRemote = remotes:WaitForChild(Protocol.CHEST) :: RemoteEvent
local progressRemote = remotes:WaitForChild(Protocol.PROGRESS) :: RemoteEvent
local rewardRemote = remotes:WaitForChild(Protocol.REWARD) :: RemoteEvent

local lobby = LobbyHud.new(Players.LocalPlayer:WaitForChild("PlayerGui"), {
	onLobby = function(request)
		lobbyRemote:FireServer(request)
	end,
	onStore = function(request)
		storeRemote:FireServer(request)
	end,
	onProgress = function(request)
		progressRemote:FireServer(request)
	end,
})
roomsRemote.OnClientEvent:Connect(function(update)
	lobby:setRooms(update)
end)
profileRemote.OnClientEvent:Connect(function(profile)
	lobby:setProfile(profile)
end)
chestRemote.OnClientEvent:Connect(function(result)
	lobby:showChest(result)
end)
rewardRemote.OnClientEvent:Connect(function(view)
	lobby:showReward(view)
end)
profileRemote:FireServer() -- in case the first push came before we were listening

LobbyFx.start(function()
	lobby:openPanel("Games")
end)

GameClient.start(CameraDirector.start(), function(inGame)
	lobby:setInGame(inGame)
end)
