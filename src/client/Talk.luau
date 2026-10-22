--!strict
-- Voice, mutes and the chat window. In the lobby Roblox's own voice works as usual (each avatar
-- speaks from where it stands). At a game table there are no avatars, so this hears the other
-- players at the same table directly, as if round a real table: their microphones are wired
-- straight to our speakers. The server decides who may be heard at all (TableTalk: your table only,
-- or the lobby only, minus anyone you've muted); unplugging a muted player here as well makes the
-- mute instant. The chat window moves to the bottom left, clear of the player list and game log.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TalkScope = require(ReplicatedStorage.Shared.Net.TalkScope)

local Talk = {}

local muted: { [number]: boolean } = {}
local listeners: { (muted: { [number]: boolean }) -> () } = {}
local muteRemote: RemoteEvent? = nil
local refreshPlayer: ((Player) -> ())? = nil

local function changed()
	for _, listener in listeners do
		task.spawn(listener, table.clone(muted))
	end
	local refresh = refreshPlayer
	if refresh then
		for _, player in Players:GetPlayers() do
			refresh(player)
		end
	end
end

-- Calls `listener` with the set of muted user ids now and whenever it changes.
function Talk.onMutesChanged(listener: (muted: { [number]: boolean }) -> ())
	table.insert(listeners, listener)
	task.spawn(listener, table.clone(muted))
end

function Talk.isMuted(userId: number): boolean
	return muted[userId] == true
end

-- Mutes or unmutes someone for us: their voice and their chat.
function Talk.setMuted(userId: number, mute: boolean)
	muted[userId] = if mute then true else nil
	changed()
	if muteRemote then
		muteRemote:FireServer({ userId = userId, muted = mute })
	end
end

local function placeChatWindow()
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window then
		window.HorizontalAlignment = Enum.HorizontalAlignment.Left
		window.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
end

local function startTableVoice()
	local me = Players.LocalPlayer
	local output = Instance.new("AudioDeviceOutput")
	output.Name = "TableVoice"
	output.Parent = SoundService
	local wires: { [Player]: Wire } = {}

	-- Wires this player's microphone to our speakers while we share a table, and unplugs it after.
	local function refresh(player: Player)
		local mine = TalkScope.tableOf(me)
		local atTable = player ~= me
			and mine ~= nil
			and TalkScope.together(mine, TalkScope.tableOf(player))
			and not muted[player.UserId]
		local microphone = if atTable then player:FindFirstChildOfClass("AudioDeviceInput") else nil
		local wire = wires[player]
		if microphone then
			if not wire then
				wire = Instance.new("Wire")
				wire.Name = player.Name
				wire.TargetInstance = output
				wire.Parent = output
				wires[player] = wire
			end
			wire.SourceInstance = microphone
		elseif wire then
			wire:Destroy()
			wires[player] = nil
		end
	end
	refreshPlayer = refresh

	local function refreshAll()
		for _, player in Players:GetPlayers() do
			refresh(player)
		end
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal(TalkScope.ATTRIBUTE):Connect(function()
			if player == me then
				refreshAll()
			else
				refresh(player)
			end
		end)
		-- Roblox gives each voice user a microphone input once their voice connects.
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				refresh(player)
			end
		end)
		refresh(player)
	end

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local wire = wires[player]
		if wire then
			wire:Destroy()
			wires[player] = nil
		end
		if muted[player.UserId] then
			muted[player.UserId] = nil
			changed()
		end
	end)
end

function Talk.start()
	placeChatWindow()
	startTableVoice()
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local remote = remotes:WaitForChild(Protocol.MUTE) :: RemoteEvent
	muteRemote = remote
	-- The server's word on who we've muted.
	remote.OnClientEvent:Connect(function(ids: { number })
		table.clear(muted)
		for _, id in ids do
			muted[id] = true
		end
		changed()
	end)
end

return Talk
