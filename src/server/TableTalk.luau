--!strict
-- Enforces TalkScope for text chat and voice: at a game table you talk only with that table, in the
-- lobby only with the lobby, and you never get chat or voice from anyone you've muted. Chat uses Roblox's general channel with a delivery check, so the chat window needs no
-- tabs. Voice is gated at the source: each player's microphone may be heard only by the user ids
-- on its access list, kept up to date as players move between lobby and tables and mute each other.
-- Mutes last for the session on this server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TalkScope = require(ReplicatedStorage.Shared.Net.TalkScope)
local Throttle = require(script.Parent.Game.Throttle)

local TableTalk = {}

local CHANNEL_WAIT_SECONDS = 30

local mutes: TalkScope.Mutes = {}
local requests = Throttle.new(0.2)

local function talker(player: Player): TalkScope.Talker
	return { id = player.UserId, table = TalkScope.tableOf(player) }
end

local function everyone(): { TalkScope.Talker }
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, talker(player))
	end
	return list
end

-- Who may hear this player's microphone, from where everyone is and who muted whom.
local function gateMicrophone(player: Player)
	local microphone = player:FindFirstChildOfClass("AudioDeviceInput")
	if not microphone then
		return
	end
	microphone.AccessType = Enum.AccessModifierType.Allow
	microphone:SetUserIdAccessList(TalkScope.listeners(mutes, talker(player), everyone()))
end

local function gateAll()
	for _, player in Players:GetPlayers() do
		gateMicrophone(player)
	end
end

local function startChat()
	local channels = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT_SECONDS)
	local general = channels and channels:WaitForChild("RBXGeneral", CHANNEL_WAIT_SECONDS)
	if not (general and general:IsA("TextChannel")) then
		warn("TableTalk: no general text channel; chat is not split by table")
		return
	end
	general.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource): boolean
		local source = message.TextSource
		if not source then
			return true -- system messages reach everyone
		end
		local sender = Players:GetPlayerByUserId(source.UserId)
		local reader = Players:GetPlayerByUserId(target.UserId)
		if not (sender and reader) then
			return false
		end
		if sender == reader then
			return true -- your own message always shows
		end
		return TalkScope.hears(mutes, talker(reader), talker(sender))
	end
end

local function mutedList(player: Player): { number }
	local list = {}
	for id in mutes[player.UserId] or {} do
		table.insert(list, id)
	end
	return list
end

function TableTalk.start()
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local muteRemote = Instance.new("RemoteEvent")
	muteRemote.Name = Protocol.MUTE
	muteRemote.Parent = remotes

	muteRemote.OnServerEvent:Connect(function(player: Player, request: any)
		local valid = typeof(request) == "table"
			and typeof(request.userId) == "number"
			and request.userId ~= player.UserId
			and typeof(request.muted) == "boolean"
		if valid and Throttle.allow(requests, tostring(player.UserId), os.clock()) then
			local mine = mutes[player.UserId] or {}
			mine[request.userId] = if request.muted then true else nil
			mutes[player.UserId] = if next(mine) then mine else nil
			gateAll()
		end
		-- Always answer with the truth, so a dropped request doesn't leave the button wrong.
		muteRemote:FireClient(player, mutedList(player))
	end)

	local function watch(player: Player)
		player:GetAttributeChangedSignal(TalkScope.ATTRIBUTE):Connect(gateAll)
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				gateMicrophone(player)
			end
		end)
		gateAll()
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		mutes[player.UserId] = nil
		for _, muted in mutes do
			muted[player.UserId] = nil
		end
		Throttle.forget(requests, tostring(player.UserId))
		task.defer(gateAll)
	end)

	task.spawn(startChat)
end

return TableTalk
